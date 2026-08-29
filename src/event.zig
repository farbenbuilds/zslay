const types = @import("types.zig");
const frame = @import("frame.zig");
const queue = @import("queue.zig");

// Explicitly backing the action enums with u8 to keep state small
// This replaces vtable/callbacks with DOD static dispatch.
pub const RxAction = enum(u8) {
    need_header = 0,
    need_payload = 1,
    emit_frame = 2,
    _,
};

pub const TxAction = enum(u8) {
    write_header = 0,
    write_payload = 1,
    _,
};

pub const RxState = enum(u8) {
    read_base_header = 0,
    read_extended_header = 1,
    read_payload = 2,
};

// Zero-allocation, I/O-agnostic WebSocket connection context
// Coordinates frame streaming, XOR masking, and intrusive TX queueing.
pub const Conn = struct {
    pub const Config = struct {
        role: types.EndpointRole,
        max_frame_len: u64,
        max_message_len: u64,
    };

    payload_bytes_processed: u64 = 0,

    tx_queue: queue.Queue(FrameNode),

    header_bytes_read: usize = 0,
    header_bytes_needed: usize = 2,

    decoded_header: ?frame.DecodedHeader = null,

    header_buf: [14]u8 = undefined,
    rx_state: RxState = .read_base_header,

    role: types.EndpointRole,
    max_frame_len: u64,
    max_message_len: u64,

    fragmented_opcode: ?types.Opcode = null,
    fragmented_message_len: u64 = 0,

    tx_fragmented_opcode: ?types.Opcode = null,
    tx_fragmented_message_len: u64 = 0,

    const FragmentState = struct {
        opcode: ?types.Opcode,
        message_len: u64,
    };

    // Ring buffer element representing an outgoing frame
    pub const FrameNode = struct {
        payload: []const u8 = &.{},

        header_size: usize = 0,
        sent_header: usize = 0,
        sent_payload: usize = 0,

        // Maximum possible WebSocket frame header size is 14 bytes
        header_buf: [14]u8 = undefined,
    };

    // Initializes a Conn context with user-provided storage and protocol limits
    pub fn init(tx_buffer: []FrameNode, config: Config) types.Error!Conn {
        if (config.max_frame_len > types.MaxPayloadLen) return error.InvalidLength;
        if (config.max_message_len > types.MaxPayloadLen) return error.InvalidLength;

        return .{
            .tx_queue = queue.Queue(FrameNode).init(tx_buffer),
            .role = config.role,
            .max_frame_len = config.max_frame_len,
            .max_message_len = config.max_message_len,
        };
    }

    fn validate_incoming_header(self: *const Conn, decoded: frame.DecodedHeader) types.Error!void {
        if (decoded.extended_len > self.max_frame_len) return error.PayloadTooLarge;

        switch (self.role) {
            .server => if (!decoded.header.mask) return error.PayloadNotMasked,
            .client => if (decoded.header.mask) return error.PayloadMasked,
        }

        const op: types.Opcode = @enumFromInt(decoded.header.opcode);
        if (op.is_control()) return;

        switch (op) {
            .continuation => {
                if (self.fragmented_opcode == null) return error.ProtocolError;
                if (self.fragmented_message_len > self.max_message_len) return error.PayloadTooLarge;

                const remaining = self.max_message_len - self.fragmented_message_len;
                if (decoded.extended_len > remaining) return error.PayloadTooLarge;
            },
            .text, .binary => {
                if (self.fragmented_opcode != null) return error.ProtocolError;
                if (decoded.extended_len > self.max_message_len) return error.PayloadTooLarge;
            },
            else => return error.InvalidOpcode,
        }
    }

    fn accept_header(self: *Conn) types.Error!void {
        const decoded = try frame.decode_header(self.header_buf[0..self.header_bytes_needed]);
        try self.validate_incoming_header(decoded);

        self.decoded_header = decoded;
        self.rx_state = .read_payload;
    }

    // Drives the RX state machine and returns the next required action
    pub fn advance_rx(self: *Conn) types.Error!RxAction {
        switch (self.rx_state) {
            .read_base_header => {
                if (self.header_bytes_read < self.header_bytes_needed) return RxAction.need_header;

                const b1 = self.header_buf[1];
                const base_len = b1 & 0x7f;
                const mask_flag = (b1 & 0x80) != 0;

                var needed: usize = 2;
                if (base_len == 126) {
                    needed += 2;
                } else if (base_len == 127) needed += 8;

                if (mask_flag) needed += 4;
                self.header_bytes_needed = needed;

                if (needed > 2) {
                    self.rx_state = .read_extended_header;
                    return RxAction.need_header;
                }

                try self.accept_header();
                return self.advance_rx();
            },
            .read_extended_header => {
                if (self.header_bytes_read < self.header_bytes_needed) return RxAction.need_header;

                try self.accept_header();
                return self.advance_rx();
            },
            .read_payload => {
                const decoded = self.decoded_header orelse return error.ProtocolError;
                if (self.payload_bytes_processed > decoded.extended_len) return error.InvalidLength;

                const remaining = decoded.extended_len - self.payload_bytes_processed;
                if (remaining == 0) return RxAction.emit_frame;
                return RxAction.need_payload;
            },
        }
    }

    fn commit_fragment_state(self: *Conn, decoded: frame.DecodedHeader) void {
        const op: types.Opcode = @enumFromInt(decoded.header.opcode);
        if (op.is_control()) return;

        switch (op) {
            .text, .binary => {
                if (!decoded.header.fin) {
                    self.fragmented_opcode = op;
                    self.fragmented_message_len = decoded.extended_len;
                }
            },
            .continuation => {
                if (decoded.header.fin) {
                    self.fragmented_opcode = null;
                    self.fragmented_message_len = 0;
                } else {
                    self.fragmented_message_len += decoded.extended_len;
                }
            },
            else => {},
        }
    }

    // Completes the current frame while preserving cross-frame message state
    pub fn complete_frame(self: *Conn) void {
        if (self.decoded_header) |decoded| {
            if (self.payload_bytes_processed == decoded.extended_len) {
                self.commit_fragment_state(decoded);
            }
        }

        self.rx_state = .read_base_header;
        self.header_bytes_read = 0;
        self.header_bytes_needed = 2;
        self.decoded_header = null;
        self.payload_bytes_processed = 0;
    }

    // Abandons all receive state, including an active fragmented message
    pub fn reset_rx(self: *Conn) void {
        self.complete_frame();
        self.fragmented_opcode = null;
        self.fragmented_message_len = 0;
    }

    pub fn get_header_buffer(self: *Conn) []u8 {
        return self.header_buf[self.header_bytes_read..self.header_bytes_needed];
    }

    pub fn advance_header_read(self: *Conn, bytes: usize) types.Error!void {
        const remaining = self.header_bytes_needed - self.header_bytes_read;
        if (bytes > remaining) return error.InvalidLength;
        self.header_bytes_read += bytes;
    }

    pub fn advance_payload_read(self: *Conn, bytes: u64) types.Error!void {
        const decoded = self.decoded_header orelse return error.ProtocolError;
        if (self.payload_bytes_processed > decoded.extended_len) return error.InvalidLength;

        const remaining = decoded.extended_len - self.payload_bytes_processed;
        if (bytes > remaining) return error.InvalidLength;
        self.payload_bytes_processed += bytes;
    }

    // Transmits headers and masked payload slices
    pub fn advance_tx(self: *Conn) ?TxAction {
        while (self.tx_queue.len != 0) {
            const node = &self.tx_queue.buffer[self.tx_queue.head];

            if (node.sent_header < node.header_size) return TxAction.write_header;
            if (node.sent_payload < node.payload.len) return TxAction.write_payload;

            _ = self.tx_queue.pop_front();
        }

        return null;
    }

    pub fn get_tx_header_buffer(self: *Conn) []const u8 {
        const node = self.tx_queue.buffer[self.tx_queue.head];
        return node.header_buf[node.sent_header..node.header_size];
    }

    pub fn advance_tx_header(self: *Conn, bytes: usize) types.Error!void {
        const node = &self.tx_queue.buffer[self.tx_queue.head];
        const remaining = node.header_size - node.sent_header;
        if (bytes > remaining) return error.InvalidLength;
        node.sent_header += bytes;
    }

    fn validate_outgoing_node(self: *const Conn, node: FrameNode) types.Error!FragmentState {
        if (node.header_size < 2 or node.header_size > node.header_buf.len) return error.InvalidLength;
        if (node.sent_header != 0 or node.sent_payload != 0) return error.ProtocolError;

        const decoded = try frame.decode_header(node.header_buf[0..node.header_size]);
        if (decoded.header_size != node.header_size) return error.InvalidLength;

        const payload_len: u64 = @intCast(node.payload.len);
        if (decoded.extended_len != payload_len) return error.InvalidLength;
        if (payload_len > self.max_frame_len) return error.PayloadTooLarge;

        switch (self.role) {
            .client => if (!decoded.header.mask) return error.PayloadNotMasked,
            .server => if (decoded.header.mask) return error.PayloadMasked,
        }

        const op: types.Opcode = @enumFromInt(decoded.header.opcode);
        if (op.is_control()) {
            return .{
                .opcode = self.tx_fragmented_opcode,
                .message_len = self.tx_fragmented_message_len,
            };
        }

        switch (op) {
            .continuation => {
                if (self.tx_fragmented_opcode == null) return error.ProtocolError;
                if (self.tx_fragmented_message_len > self.max_message_len) return error.PayloadTooLarge;

                const remaining = self.max_message_len - self.tx_fragmented_message_len;
                if (payload_len > remaining) return error.PayloadTooLarge;
                if (decoded.header.fin) return .{ .opcode = null, .message_len = 0 };

                return .{
                    .opcode = self.tx_fragmented_opcode,
                    .message_len = self.tx_fragmented_message_len + payload_len,
                };
            },
            .text, .binary => {
                if (self.tx_fragmented_opcode != null) return error.ProtocolError;
                if (payload_len > self.max_message_len) return error.PayloadTooLarge;
                if (decoded.header.fin) return .{ .opcode = null, .message_len = 0 };
                return .{ .opcode = op, .message_len = payload_len };
            },
            else => return error.InvalidOpcode,
        }
    }

    // Validates wire order before appending an outgoing frame
    pub fn queue_frame(self: *Conn, node: FrameNode) !void {
        const next_fragment = try self.validate_outgoing_node(node);
        try self.tx_queue.push_back(node);
        self.tx_fragmented_opcode = next_fragment.opcode;
        self.tx_fragmented_message_len = next_fragment.message_len;
    }

    // Builds a validated frame header over caller-owned payload storage
    pub fn prepare_frame(
        self: *const Conn,
        fin: bool,
        opcode: types.Opcode,
        payload: []const u8,
        is_masked: bool,
        masking_key_opt: ?types.MaskingKey,
    ) types.Error!FrameNode {
        switch (opcode) {
            .continuation, .text, .binary, .close, .ping, .pong => {},
            _ => return error.InvalidOpcode,
        }

        const payload_len: u64 = @intCast(payload.len);
        if (payload_len > self.max_frame_len) return error.PayloadTooLarge;
        if (!opcode.is_control() and payload_len > self.max_message_len) return error.PayloadTooLarge;
        if (opcode.is_control() and (!fin or payload_len > 125)) return error.ProtocolError;

        switch (self.role) {
            .client => if (!is_masked) return error.PayloadNotMasked,
            .server => if (is_masked) return error.PayloadMasked,
        }

        if (is_masked and masking_key_opt == null) return error.MaskingKeyRequired;
        const key = if (is_masked) masking_key_opt else null;

        var node = FrameNode{
            .payload = payload,
        };

        const base_len: u7 = if (payload.len < 126) @intCast(payload.len) else if (payload.len <= 65535) 126 else 127;
        const header_struct = types.FrameHeader{
            .payload_len = base_len,
            .mask = is_masked,
            .opcode = @intCast(@intFromEnum(opcode)),

            .rsv3 = false,
            .rsv2 = false,
            .rsv1 = false,
            .fin = fin,
        };

        node.header_size = try frame.encode_header(
            &node.header_buf,
            header_struct,
            payload_len,
            key,
        );
        return node;
    }
};
