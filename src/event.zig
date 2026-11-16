const std = @import("std");
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
    header_bytes_needed: usize = types.BaseHeaderLen,

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

    // Debug-only checks for receive-side counters and fragment arithmetic
    fn assert_rx_invariants(self: *const Conn) void {
        std.debug.assert(self.header_bytes_read <= types.MaxFrameHeaderLen);
        std.debug.assert(self.header_bytes_needed <= types.MaxFrameHeaderLen);
        std.debug.assert(self.payload_bytes_processed <= types.MaxPayloadLen);
        std.debug.assert(self.rx_fragment.message_len <= self.max_message_len);

        if (self.rx_fragment.opcode == null) {
            std.debug.assert(self.rx_fragment.message_len == 0);
        }

        switch (self.rx_state) {
            .read_base_header, .read_extended_header => {
                std.debug.assert(self.decoded_header == null);
            },
            .read_payload => {
                std.debug.assert(self.decoded_header != null);
                const decoded = self.decoded_header.?;
                std.debug.assert(self.payload_bytes_processed <= decoded.payload_len);
                std.debug.assert(decoded.payload_len <= types.MaxPayloadLen);
            },
        }
    }

    // Debug-only checks for the head node and transmit fragment arithmetic
    fn assert_tx_invariants(self: *const Conn) void {
        std.debug.assert(self.tx_queue.len <= self.tx_queue.buffer.len);
        std.debug.assert(self.tx_fragment.message_len <= self.max_message_len);

        if (self.tx_fragment.opcode == null) {
            std.debug.assert(self.tx_fragment.message_len == 0);
        }

        if (self.tx_queue.len == 0) return;

        const node = self.tx_queue.front_const().?;
        std.debug.assert(node.header_len <= node.header_buf.len);
        std.debug.assert(node.header_sent <= node.header_len);
        std.debug.assert(node.payload_sent <= node.payload.len);
    }

    fn validate_incoming_header(self: *const Conn, decoded: frame.DecodedHeader) types.Error!void {
        if (decoded.payload_len > self.max_frame_len) return error.PayloadTooLarge;

        switch (self.role) {
            .server => {
                if (!decoded.header.mask) return error.PayloadNotMasked;
            },
            .client => {
                if (decoded.header.mask) return error.PayloadMasked;
            },
        }

        const op: types.Opcode = @fromBackingInt(decoded.header.opcode);
        if (op.is_control()) return;

        switch (op) {
            .continuation => {
                if (self.rx_fragment.opcode == null) return error.ProtocolError;
                if (self.rx_fragment.message_len > self.max_message_len) return error.PayloadTooLarge;

                std.debug.assert(self.rx_fragment.message_len <= self.max_message_len);
                const remaining = self.max_message_len - self.rx_fragment.message_len;
                if (decoded.payload_len > remaining) return error.PayloadTooLarge;
            },
            .text, .binary => {
                if (self.rx_fragment.opcode != null) return error.ProtocolError;
                if (decoded.payload_len > self.max_message_len) return error.PayloadTooLarge;

                std.debug.assert(decoded.payload_len <= self.max_message_len);
            },
            else => return error.InvalidOpcode,
        }
    }

    fn accept_header(self: *Conn) types.Error!void {
        std.debug.assert(self.header_bytes_needed <= types.MaxFrameHeaderLen);

        const decoded = try frame.decode_header(self.header_buf[0..self.header_bytes_needed]);
        try self.validate_incoming_header(decoded);

        std.debug.assert(decoded.header_len == self.header_bytes_needed);
        self.decoded_header = decoded;
        self.rx_state = .read_payload;
    }

    // Drives the RX state machine iteratively and returns the next required action
    pub fn advance_rx(self: *Conn) types.Error!RxAction {
        self.assert_rx_invariants();

        while (true) {
            self.assert_rx_invariants();
            switch (self.rx_state) {
                .read_base_header => {
                    if (self.header_bytes_read < self.header_bytes_needed) return RxAction.need_header;

                    self.header_bytes_needed = frame.header_bytes_needed(self.header_buf[1]);
                    std.debug.assert(self.header_bytes_needed <= types.MaxFrameHeaderLen);

                    if (self.header_bytes_needed > types.BaseHeaderLen) {
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

                    std.debug.assert(self.payload_bytes_processed <= decoded.payload_len);
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
                    std.debug.assert(decoded.payload_len <= self.max_message_len);
                    self.rx_fragment = .{ .opcode = op, .message_len = decoded.payload_len };
                }
            },
            .continuation => {
                if (decoded.header.fin) {
                    self.rx_fragment = .{};
                } else {
                    std.debug.assert(self.rx_fragment.message_len <= self.max_message_len);
                    const remaining = self.max_message_len - self.rx_fragment.message_len;
                    std.debug.assert(decoded.payload_len <= remaining);
                    self.rx_fragment.message_len += decoded.payload_len;
                    std.debug.assert(self.rx_fragment.message_len <= self.max_message_len);
                }
            },
            else => {},
        }
    }

    fn reset_frame_state(self: *Conn) void {
        self.rx_state = .read_base_header;
        self.header_bytes_read = 0;
        self.header_bytes_needed = types.BaseHeaderLen;
        self.decoded_header = null;
        self.payload_bytes_processed = 0;
    }

    // Returns true when no receive state is buffered or partially consumed
    pub fn is_at_frame_boundary(self: *const Conn) bool {
        if (self.rx_state != .read_base_header) return false;
        if (self.header_bytes_read != 0) return false;
        if (self.decoded_header != null) return false;
        return self.payload_bytes_processed == 0;
    }

    // Completes the current frame while preserving cross-frame message state
    pub fn complete_frame(self: *Conn) types.Error!void {
        const decoded = self.decoded_header orelse return error.ProtocolError;
        if (self.payload_bytes_processed != decoded.payload_len) return error.ProtocolError;

        std.debug.assert(self.payload_bytes_processed == decoded.payload_len);
        self.commit_fragment_state(decoded);
        self.reset_frame_state();
    }

    // Abandons all receive state, including an active fragmented message
    pub fn reset_rx(self: *Conn) void {
        self.reset_frame_state();
        self.rx_fragment = .{};
        self.assert_rx_invariants();
    }

    pub fn get_header_buffer(self: *Conn) []u8 {
        std.debug.assert(self.header_bytes_read <= self.header_bytes_needed);
        std.debug.assert(self.header_bytes_needed <= types.MaxFrameHeaderLen);
        return self.header_buf[self.header_bytes_read..self.header_bytes_needed];
    }

    pub fn advance_header_read(self: *Conn, bytes: usize) types.Error!void {
        std.debug.assert(self.header_bytes_needed <= types.MaxFrameHeaderLen);
        if (self.header_bytes_read > self.header_bytes_needed) return error.InvalidLength;

        const remaining = self.header_bytes_needed - self.header_bytes_read;
        if (bytes == 0) return error.InvalidLength;
        if (bytes > remaining) return error.InvalidLength;
        self.header_bytes_read += bytes;
        std.debug.assert(self.header_bytes_read <= self.header_bytes_needed);
    }

    pub fn advance_payload_read(self: *Conn, bytes: u64) types.Error!void {
        const decoded = self.decoded_header orelse return error.ProtocolError;
        if (self.payload_bytes_processed > decoded.payload_len) return error.InvalidLength;

        std.debug.assert(decoded.payload_len <= types.MaxPayloadLen);
        const remaining = decoded.payload_len - self.payload_bytes_processed;
        if (bytes == 0) return error.InvalidLength;
        if (bytes > remaining) return error.InvalidLength;
        self.payload_bytes_processed += bytes;
        std.debug.assert(self.payload_bytes_processed <= decoded.payload_len);
    }

    // Transmits headers and masked payload slices
    pub fn advance_tx(self: *Conn) ?TxAction {
        self.assert_tx_invariants();

        const queue_len = self.tx_queue.len;
        var discarded: usize = 0;
        while (discarded < queue_len) : (discarded += 1) {
            const node = self.tx_queue.front() orelse return null;

            std.debug.assert(node.header_len <= node.header_buf.len);
            std.debug.assert(node.header_sent <= node.header_len);
            std.debug.assert(node.payload_sent <= node.payload.len);

            if (node.header_sent < node.header_len) return TxAction.write_header;
            if (node.payload_sent < node.payload.len) return TxAction.write_payload;

            self.tx_queue.discard_front();
        }

        std.debug.assert(self.tx_queue.len == 0);
        return null;
    }

    pub fn get_tx_header_buffer(self: *Conn) []const u8 {
        const node = self.tx_queue.front() orelse return &.{};

        std.debug.assert(node.header_sent <= node.header_len);
        std.debug.assert(node.header_len <= node.header_buf.len);
        return node.header_buf[node.header_sent..node.header_len];
    }

    pub fn advance_tx_header(self: *Conn, bytes: usize) types.Error!void {
        const node = self.tx_queue.front() orelse return error.InvalidLength;
        if (node.header_sent > node.header_len) return error.InvalidLength;

        std.debug.assert(node.header_len <= node.header_buf.len);
        const remaining = node.header_len - node.header_sent;
        if (bytes == 0) return error.InvalidLength;
        if (bytes > remaining) return error.InvalidLength;
        node.header_sent += bytes;
        std.debug.assert(node.header_sent <= node.header_len);
    }

    // Returns the unsent plaintext payload of the head node
    pub fn get_tx_payload(self: *Conn) types.Error![]const u8 {
        const node = self.tx_queue.front() orelse return error.InvalidLength;
        if (node.payload_sent > node.payload.len) return error.InvalidLength;

        std.debug.assert(node.payload_sent <= node.payload.len);
        return node.payload[node.payload_sent..];
    }

    // Returns the absolute payload offset of the head node
    pub fn get_tx_payload_offset(self: *Conn) types.Error!usize {
        const node = self.tx_queue.front() orelse return error.InvalidLength;
        if (node.payload_sent > node.payload.len) return error.InvalidLength;

        std.debug.assert(node.payload_sent <= node.payload.len);
        return node.payload_sent;
    }

    // Returns the masking key of the head node, or null for an unmasked frame
    pub fn get_tx_masking_key(self: *Conn) types.Error!?types.MaskingKey {
        const node = self.tx_queue.front() orelse return error.InvalidLength;
        if (node.header_len < types.BaseHeaderLen) return error.InvalidLength;
        if ((node.header_buf[1] & 0x80) == 0) return null;

        const masking_header_len = types.BaseHeaderLen + types.MaskingKeyLen;
        if (node.header_len < masking_header_len) return error.InvalidLength;

        std.debug.assert(node.header_len <= node.header_buf.len);
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
        if (bytes == 0) return error.InvalidLength;
        if (bytes > remaining) return error.InvalidLength;
        node.payload_sent += bytes;
        std.debug.assert(node.payload_sent <= node.payload.len);
    }

    pub fn tx_pending(self: *const Conn) usize {
        std.debug.assert(self.tx_queue.len <= self.tx_queue.buffer.len);
        return self.tx_queue.len;
    }

    // Drops queued frames and any open transmit fragment
    pub fn reset_tx(self: *Conn) void {
        self.tx_queue.clear();
        self.tx_fragment = .{};
        self.assert_tx_invariants();
    }

    fn validate_outgoing_node(self: *const Conn, node: FrameNode) types.Error!FragmentState {
        if (node.header_len < types.BaseHeaderLen) return error.InvalidLength;
        if (node.header_len > node.header_buf.len) return error.InvalidLength;
        if (node.header_sent != 0) return error.ProtocolError;
        if (node.payload_sent != 0) return error.ProtocolError;
        if (node.payload.len != 0) {
            if (@intFromPtr(node.payload.ptr) == 0) return error.InvalidLength;
        }

        const decoded = try frame.decode_header(node.header_buf[0..node.header_len]);
        if (decoded.header_len != node.header_len) return error.InvalidLength;

        const payload_len: u64 = @intCast(node.payload.len);
        if (decoded.payload_len != payload_len) return error.InvalidLength;
        if (payload_len > self.max_frame_len) return error.PayloadTooLarge;

        switch (self.role) {
            .client => {
                if (!decoded.header.mask) return error.PayloadNotMasked;
            },
            .server => {
                if (decoded.header.mask) return error.PayloadMasked;
            },
        }

        const op: types.Opcode = @fromBackingInt(decoded.header.opcode);
        if (op.is_control()) return self.tx_fragment;

        switch (op) {
            .continuation => {
                if (self.tx_fragment.opcode == null) return error.ProtocolError;
                if (self.tx_fragment.message_len > self.max_message_len) return error.PayloadTooLarge;

                std.debug.assert(self.tx_fragment.message_len <= self.max_message_len);
                const remaining = self.max_message_len - self.tx_fragment.message_len;
                if (payload_len > remaining) return error.PayloadTooLarge;
                if (decoded.header.fin) return .{};

                std.debug.assert(payload_len <= remaining);
                return .{
                    .opcode = self.tx_fragment.opcode,
                    .message_len = self.tx_fragment.message_len + payload_len,
                };
            },
            .text, .binary => {
                if (self.tx_fragment.opcode != null) return error.ProtocolError;
                if (payload_len > self.max_message_len) return error.PayloadTooLarge;

                std.debug.assert(payload_len <= self.max_message_len);
                if (decoded.header.fin) return .{};
                return .{ .opcode = op, .message_len = payload_len };
            },
            else => return error.InvalidOpcode,
        }
    }

    fn control_can_preempt(self: *const Conn) bool {
        const head = self.tx_queue.front_const() orelse return true;
        if (head.header_sent != 0) return false;
        return head.payload_sent == 0;
    }

    // Validates wire order and appends; ping/pong preempt an unsent head
    pub fn queue_frame(self: *Conn, node: FrameNode) (types.Error || error{QueueFull})!void {
        const next_fragment = try self.validate_outgoing_node(node);

        const op: types.Opcode = @fromBackingInt(@intCast(node.header_buf[0] & 0x0f));
        if (op == .ping or op == .pong) {
            if (self.control_can_preempt()) {
                try self.tx_queue.push_front(node);
            } else {
                try self.tx_queue.push_back(node);
            }
        } else {
            try self.tx_queue.push_back(node);
        }

        self.tx_fragment = next_fragment;
        self.assert_tx_invariants();
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

        if (opcode.is_control()) {
            if (!fin) return error.ProtocolError;
            if (payload_len > types.ControlPayloadMax) return error.ProtocolError;
        } else {
            if (payload_len > self.max_message_len) return error.PayloadTooLarge;
        }

        switch (self.role) {
            .client => {
                if (!is_masked) return error.PayloadNotMasked;
            },
            .server => {
                if (is_masked) return error.PayloadMasked;
            },
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

        if (is_masked) {
            if (masking_key_opt == null) return error.MaskingKeyRequired;
        } else {
            if (masking_key_opt != null) return error.ProtocolError;
        }
        const key = masking_key_opt;

        if (opcode == .close) try frame.validate_close_payload(payload);

        var node = FrameNode{
            .payload = payload,
        };

        const marker: u7 = if (payload.len < types.ExtendedLength16Threshold)
            @intCast(payload.len)
        else if (payload.len < types.ExtendedLength64Threshold)
            types.ExtendedLength16Marker
        else
            types.ExtendedLength64Marker;

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
