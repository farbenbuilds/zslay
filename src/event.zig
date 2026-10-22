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

// Caller-provided connection role and frame/message limits
pub const ConnConfig = struct {
    role: types.EndpointRole,
    max_frame_len: u64,
    max_message_len: u64,
};

// Ring buffer element representing one outgoing frame
pub const FrameNode = struct {
    payload: []const u8 = &.{},

    header_len: usize = 0,
    header_sent: usize = 0,
    payload_sent: usize = 0,

    header_buf: types.FrameHeaderBuffer = @splat(0),
};

// Fragment tracking shared by the receive and transmit paths
const FragmentState = struct {
    opcode: ?types.Opcode = null,
    message_len: u64 = 0,
};

// Concrete bounded queue of outgoing frame nodes
const FrameQueue = queue.Queue(FrameNode);

// Zero-allocation, I/O-agnostic WebSocket connection context
// Coordinates frame streaming, XOR masking, and intrusive TX queueing.
pub const Conn = struct {
    // Compatibility alias; prefer ConnConfig
    pub const Config = ConnConfig;

    payload_bytes_processed: u64 = 0,

    tx_queue: FrameQueue,

    header_bytes_read: usize = 0,
    header_bytes_needed: usize = 2,

    decoded_header: ?frame.DecodedHeader = null,

    header_buf: types.FrameHeaderBuffer = undefined,
    rx_state: RxState = .read_base_header,

    role: types.EndpointRole,
    max_frame_len: u64,
    max_message_len: u64,

    rx_fragment: FragmentState = .{},
    tx_fragment: FragmentState = .{},

    // Initializes a Conn context with user-provided storage and protocol limits
    pub fn init(tx_buffer: []FrameNode, config: ConnConfig) types.Error!Conn {
        if (config.max_frame_len > types.MaxPayloadLen) return error.InvalidLength;
        if (config.max_message_len > types.MaxPayloadLen) return error.InvalidLength;

        return .{
            .tx_queue = FrameQueue.init(tx_buffer),
            .role = config.role,
            .max_frame_len = config.max_frame_len,
            .max_message_len = config.max_message_len,
        };
    }

    fn validate_incoming_header(self: *const Conn, decoded: frame.DecodedHeader) types.Error!void {
        if (decoded.payload_len > self.max_frame_len) return error.PayloadTooLarge;

        switch (self.role) {
            .server => if (!decoded.header.mask) return error.PayloadNotMasked,
            .client => if (decoded.header.mask) return error.PayloadMasked,
        }

        const op: types.Opcode = @fromBackingInt(decoded.header.opcode);
        if (op.is_control()) return;

        switch (op) {
            .continuation => {
                if (self.rx_fragment.opcode == null) return error.ProtocolError;
                if (self.rx_fragment.message_len > self.max_message_len) return error.PayloadTooLarge;

                const remaining = self.max_message_len - self.rx_fragment.message_len;
                if (decoded.payload_len > remaining) return error.PayloadTooLarge;
            },
            .text, .binary => {
                if (self.rx_fragment.opcode != null) return error.ProtocolError;
                if (decoded.payload_len > self.max_message_len) return error.PayloadTooLarge;
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

    // Drives the RX state machine iteratively and returns the next required action
    pub fn advance_rx(self: *Conn) types.Error!RxAction {
        while (true) {
            switch (self.rx_state) {
                .read_base_header => {
                    if (self.header_bytes_read < self.header_bytes_needed) return RxAction.need_header;

                    self.header_bytes_needed = frame.header_bytes_needed(self.header_buf[1]);

                    if (self.header_bytes_needed > 2) {
                        self.rx_state = .read_extended_header;
                        return RxAction.need_header;
                    }

                    try self.accept_header();
                },
                .read_extended_header => {
                    if (self.header_bytes_read < self.header_bytes_needed) return RxAction.need_header;

                    try self.accept_header();
                },
                .read_payload => {
                    const decoded = self.decoded_header orelse return error.ProtocolError;
                    if (self.payload_bytes_processed > decoded.payload_len) return error.InvalidLength;

                    const remaining = decoded.payload_len - self.payload_bytes_processed;
                    if (remaining == 0) return RxAction.emit_frame;
                    return RxAction.need_payload;
                },
            }
        }
    }

    fn commit_fragment_state(self: *Conn, decoded: frame.DecodedHeader) void {
        const op: types.Opcode = @fromBackingInt(decoded.header.opcode);
        if (op.is_control()) return;

        switch (op) {
            .text, .binary => {
                if (!decoded.header.fin) {
                    self.rx_fragment = .{ .opcode = op, .message_len = decoded.payload_len };
                }
            },
            .continuation => {
                if (decoded.header.fin) {
                    self.rx_fragment = .{};
                } else {
                    self.rx_fragment.message_len += decoded.payload_len;
                }
            },
            else => {},
        }
    }

    fn reset_frame_state(self: *Conn) void {
        self.rx_state = .read_base_header;
        self.header_bytes_read = 0;
        self.header_bytes_needed = 2;
        self.decoded_header = null;
        self.payload_bytes_processed = 0;
    }

    // Returns true when no receive state is buffered or partially consumed
    pub fn is_at_frame_boundary(self: *const Conn) bool {
        return self.rx_state == .read_base_header and
            self.header_bytes_read == 0 and
            self.decoded_header == null and
            self.payload_bytes_processed == 0;
    }

    // Completes the current frame while preserving cross-frame message state
    pub fn complete_frame(self: *Conn) types.Error!void {
        const decoded = self.decoded_header orelse return error.ProtocolError;
        if (self.payload_bytes_processed != decoded.payload_len) return error.ProtocolError;

        self.commit_fragment_state(decoded);
        self.reset_frame_state();
    }

    // Abandons all receive state, including an active fragmented message
    pub fn reset_rx(self: *Conn) void {
        self.reset_frame_state();
        self.rx_fragment = .{};
    }

    pub fn get_header_buffer(self: *Conn) []u8 {
        return self.header_buf[self.header_bytes_read..self.header_bytes_needed];
    }

    pub fn advance_header_read(self: *Conn, bytes: usize) types.Error!void {
        if (self.header_bytes_read > self.header_bytes_needed) return error.InvalidLength;

        const remaining = self.header_bytes_needed - self.header_bytes_read;
        if (bytes == 0 or bytes > remaining) return error.InvalidLength;
        self.header_bytes_read += bytes;
    }

    pub fn advance_payload_read(self: *Conn, bytes: u64) types.Error!void {
        const decoded = self.decoded_header orelse return error.ProtocolError;
        if (self.payload_bytes_processed > decoded.payload_len) return error.InvalidLength;

        const remaining = decoded.payload_len - self.payload_bytes_processed;
        if (bytes == 0 or bytes > remaining) return error.InvalidLength;
        self.payload_bytes_processed += bytes;
    }

    // Transmits headers and masked payload slices
    pub fn advance_tx(self: *Conn) ?TxAction {
        while (self.tx_queue.front()) |node| {
            if (node.header_sent < node.header_len) return TxAction.write_header;
            if (node.payload_sent < node.payload.len) return TxAction.write_payload;

            _ = self.tx_queue.pop_front();
        }

        return null;
    }

    pub fn get_tx_header_buffer(self: *Conn) []const u8 {
        const node = self.tx_queue.front() orelse return &.{};
        return node.header_buf[node.header_sent..node.header_len];
    }

    pub fn advance_tx_header(self: *Conn, bytes: usize) types.Error!void {
        const node = self.tx_queue.front() orelse return error.InvalidLength;
        if (node.header_sent > node.header_len) return error.InvalidLength;

        const remaining = node.header_len - node.header_sent;
        if (bytes == 0 or bytes > remaining) return error.InvalidLength;
        node.header_sent += bytes;
    }

    // Returns the unsent plaintext payload of the head node
    pub fn get_tx_payload(self: *Conn) types.Error![]const u8 {
        const node = self.tx_queue.front() orelse return error.InvalidLength;
        if (node.payload_sent > node.payload.len) return error.InvalidLength;
        return node.payload[node.payload_sent..];
    }

    // Returns the absolute payload offset of the head node
    pub fn get_tx_payload_offset(self: *Conn) types.Error!usize {
        const node = self.tx_queue.front() orelse return error.InvalidLength;
        if (node.payload_sent > node.payload.len) return error.InvalidLength;
        return node.payload_sent;
    }

    // Returns the masking key of the head node, or null for an unmasked frame
    pub fn get_tx_masking_key(self: *Conn) types.Error!?types.MaskingKey {
        const node = self.tx_queue.front() orelse return error.InvalidLength;
        if (node.header_len < 2) return error.InvalidLength;
        if ((node.header_buf[1] & 0x80) == 0) return null;
        if (node.header_len < 2 + types.MaskingKeyLen) return error.InvalidLength;

        const key_index = node.header_len - types.MaskingKeyLen;
        var key: types.MaskingKey = undefined;
        @memcpy(&key, node.header_buf[key_index .. key_index + types.MaskingKeyLen]);
        return key;
    }

    // Advances the head node payload by bytes sent to the transport
    pub fn advance_tx_payload(self: *Conn, bytes: usize) types.Error!void {
        const node = self.tx_queue.front() orelse return error.InvalidLength;
        if (node.payload_sent > node.payload.len) return error.InvalidLength;

        const remaining = node.payload.len - node.payload_sent;
        if (bytes == 0 or bytes > remaining) return error.InvalidLength;
        node.payload_sent += bytes;
    }

    pub fn tx_pending(self: *const Conn) usize {
        return self.tx_queue.len;
    }

    // Drops queued frames and any open transmit fragment
    pub fn reset_tx(self: *Conn) void {
        self.tx_queue.clear();
        self.tx_fragment = .{};
    }

    fn validate_outgoing_node(self: *const Conn, node: FrameNode) types.Error!FragmentState {
        if (node.header_len < 2 or node.header_len > node.header_buf.len) return error.InvalidLength;
        if (node.header_sent != 0 or node.payload_sent != 0) return error.ProtocolError;
        if (node.payload.len != 0 and @intFromPtr(node.payload.ptr) == 0) return error.InvalidLength;

        const decoded = try frame.decode_header(node.header_buf[0..node.header_len]);
        if (decoded.header_len != node.header_len) return error.InvalidLength;

        const payload_len: u64 = @intCast(node.payload.len);
        if (decoded.payload_len != payload_len) return error.InvalidLength;
        if (payload_len > self.max_frame_len) return error.PayloadTooLarge;

        switch (self.role) {
            .client => if (!decoded.header.mask) return error.PayloadNotMasked,
            .server => if (decoded.header.mask) return error.PayloadMasked,
        }

        const op: types.Opcode = @fromBackingInt(decoded.header.opcode);
        if (op.is_control()) return self.tx_fragment;

        switch (op) {
            .continuation => {
                if (self.tx_fragment.opcode == null) return error.ProtocolError;
                if (self.tx_fragment.message_len > self.max_message_len) return error.PayloadTooLarge;

                const remaining = self.max_message_len - self.tx_fragment.message_len;
                if (payload_len > remaining) return error.PayloadTooLarge;
                if (decoded.header.fin) return .{};

                return .{
                    .opcode = self.tx_fragment.opcode,
                    .message_len = self.tx_fragment.message_len + payload_len,
                };
            },
            .text, .binary => {
                if (self.tx_fragment.opcode != null) return error.ProtocolError;
                if (payload_len > self.max_message_len) return error.PayloadTooLarge;
                if (decoded.header.fin) return .{};
                return .{ .opcode = op, .message_len = payload_len };
            },
            else => return error.InvalidOpcode,
        }
    }

    // Validates wire order before appending an outgoing frame
    pub fn queue_frame(self: *Conn, node: FrameNode) (types.Error || error{QueueFull})!void {
        const next_fragment = try self.validate_outgoing_node(node);
        try self.tx_queue.push_back(node);
        self.tx_fragment = next_fragment;
    }

    // Validates frame properties common to prepare and queue paths
    pub fn validate_outgoing_frame(
        self: *const Conn,
        fin: bool,
        opcode: types.Opcode,
        payload_len: u64,
        is_masked: bool,
    ) types.Error!void {
        switch (opcode) {
            .continuation, .text, .binary, .close, .ping, .pong => {},
            _ => return error.InvalidOpcode,
        }

        if (payload_len > self.max_frame_len) return error.PayloadTooLarge;
        if (!opcode.is_control() and payload_len > self.max_message_len) return error.PayloadTooLarge;
        if (opcode.is_control() and (!fin or payload_len > 125)) return error.ProtocolError;

        switch (self.role) {
            .client => if (!is_masked) return error.PayloadNotMasked,
            .server => if (is_masked) return error.PayloadMasked,
        }
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
        const payload_len: u64 = @intCast(payload.len);
        try self.validate_outgoing_frame(fin, opcode, payload_len, is_masked);

        if (is_masked and masking_key_opt == null) return error.MaskingKeyRequired;
        if (!is_masked and masking_key_opt != null) return error.ProtocolError;
        const key = masking_key_opt;

        if (opcode == .close) try frame.validate_close_payload(payload);

        var node = FrameNode{
            .payload = payload,
        };

        const marker: u7 = if (payload.len < 126)
            @intCast(payload.len)
        else if (payload.len <= 65535)
            126
        else
            127;

        const header = types.FrameHeader{
            .payload_len = marker,
            .mask = is_masked,
            .opcode = @backingInt(opcode),

            .rsv3 = false,
            .rsv2 = false,
            .rsv1 = false,
            .fin = fin,
        };

        node.header_len = try frame.encode_header(
            &node.header_buf,
            header,
            payload_len,
            key,
        );
        return node;
    }
};
