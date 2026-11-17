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

// Decoded opcode and the fragment state after accepting an outgoing frame
const ValidatedOutgoingFrame = struct {
    opcode: types.Opcode,
    fragment: FragmentState,
};

// Concrete bounded queue of outgoing frame nodes
const FrameQueue = queue.Queue(FrameNode);

pub fn ranges_overlap(a_start: usize, a_len: usize, b_start: usize, b_len: usize) bool {
    if (a_len == 0 or b_len == 0) return false;

    const a_end = std.math.add(usize, a_start, a_len) catch return true;
    const b_end = std.math.add(usize, b_start, b_len) catch return true;
    return a_start < b_end and b_start < a_end;
}

fn validate_incoming_masking(role: types.EndpointRole, is_masked: bool) types.Error!void {
    switch (role) {
        .client => if (is_masked) return error.PayloadMasked,
        .server => if (!is_masked) return error.PayloadNotMasked,
    }
}

fn validate_outgoing_masking(role: types.EndpointRole, is_masked: bool) types.Error!void {
    switch (role) {
        .client => if (!is_masked) return error.PayloadNotMasked,
        .server => if (is_masked) return error.PayloadMasked,
    }
}

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

        try validate_incoming_masking(self.role, decoded.header.mask);

        const op = types.Opcode.fromWire(decoded.header.opcode) orelse return error.InvalidOpcode;
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

    fn commit_fragment_state(self: *Conn, decoded: frame.DecodedHeader) types.Error!void {
        const op = types.Opcode.fromWire(decoded.header.opcode) orelse return error.InvalidOpcode;
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
                    std.debug.assert(decoded.payload_len <= self.max_message_len - self.rx_fragment.message_len);
                    self.rx_fragment.message_len += decoded.payload_len;
                    std.debug.assert(self.rx_fragment.message_len <= self.max_message_len);
                }
            },
            else => return error.InvalidOpcode,
        }
    }

    fn reset_frame_state(self: *Conn) void {
        self.rx_state = .read_base_header;
        self.header_bytes_read = 0;
        self.header_bytes_needed = types.BaseHeaderLen;
        self.decoded_header = null;
        self.payload_bytes_processed = 0;
    }

    pub fn is_at_frame_boundary(self: *const Conn) bool {
        if (self.rx_state != .read_base_header) return false;
        if (self.header_bytes_read != 0) return false;
        if (self.decoded_header != null) return false;
        return self.payload_bytes_processed == 0;
    }

    pub fn complete_frame(self: *Conn) types.Error!void {
        const decoded = self.decoded_header orelse return error.ProtocolError;
        if (self.payload_bytes_processed != decoded.payload_len) return error.ProtocolError;

        std.debug.assert(self.payload_bytes_processed == decoded.payload_len);
        try self.commit_fragment_state(decoded);
        self.reset_frame_state();
    }

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

    pub fn get_tx_payload(self: *Conn) types.Error![]const u8 {
        const node = self.tx_queue.front() orelse return error.InvalidLength;
        if (node.payload_sent > node.payload.len) return error.InvalidLength;

        std.debug.assert(node.payload_sent <= node.payload.len);
        return node.payload[node.payload_sent..];
    }

    pub fn get_tx_payload_offset(self: *Conn) types.Error!usize {
        const node = self.tx_queue.front() orelse return error.InvalidLength;
        if (node.payload_sent > node.payload.len) return error.InvalidLength;

        std.debug.assert(node.payload_sent <= node.payload.len);
        return node.payload_sent;
    }

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

    pub fn current_frame(self: *const Conn) types.Error!frame.DecodedHeader {
        return self.decoded_header orelse error.ProtocolError;
    }

    pub fn rx_remaining(self: *const Conn) types.Error!u64 {
        const decoded = try self.current_frame();
        if (self.payload_bytes_processed > decoded.payload_len) return error.InvalidLength;
        return decoded.payload_len - self.payload_bytes_processed;
    }

    pub fn tx_pending_overlaps(self: *const Conn, start: usize, len: usize) bool {
        std.debug.assert(self.tx_queue.len <= self.tx_queue.buffer.len);
        if (len == 0) return false;

        const tx = &self.tx_queue;
        if (tx.len == 0) return false;

        var index = tx.head;
        for (0..tx.len) |_| {
            const slot_start = @intFromPtr(&tx.buffer[index]);
            if (ranges_overlap(start, len, slot_start, @sizeOf(FrameNode))) return true;
            index += 1;
            if (index == tx.buffer.len) index = 0;
        }
        return false;
    }

    pub fn tx_storage_overlaps(self: *const Conn, start: usize, len: usize) bool {
        if (len == 0) return false;

        const buffer = self.tx_queue.buffer;
        if (buffer.len == 0) return false;

        const storage_len = std.math.mul(usize, buffer.len, @sizeOf(FrameNode)) catch return true;
        return ranges_overlap(start, len, @intFromPtr(buffer.ptr), storage_len);
    }

    pub fn reset_tx(self: *Conn) void {
        self.tx_queue.clear();
        self.tx_fragment = .{};
        self.assert_tx_invariants();
    }

    fn validate_outgoing_node(self: *const Conn, node: FrameNode) types.Error!ValidatedOutgoingFrame {
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

        const op = types.Opcode.fromWire(decoded.header.opcode) orelse return error.InvalidOpcode;
        try self.validate_outgoing_frame(decoded.header.fin, op, node.payload, decoded.header.mask);
        if (op.is_control()) return .{ .opcode = op, .fragment = self.tx_fragment };

        switch (op) {
            .continuation => {
                if (self.tx_fragment.opcode == null) return error.ProtocolError;
                if (self.tx_fragment.message_len > self.max_message_len) return error.PayloadTooLarge;

                std.debug.assert(self.tx_fragment.message_len <= self.max_message_len);
                const remaining = self.max_message_len - self.tx_fragment.message_len;
                if (payload_len > remaining) return error.PayloadTooLarge;
                if (decoded.header.fin) return .{ .opcode = op, .fragment = .{} };

                std.debug.assert(payload_len <= remaining);
                return .{
                    .opcode = op,
                    .fragment = .{
                        .opcode = self.tx_fragment.opcode,
                        .message_len = self.tx_fragment.message_len + payload_len,
                    },
                };
            },
            .text, .binary => {
                if (self.tx_fragment.opcode != null) return error.ProtocolError;
                if (payload_len > self.max_message_len) return error.PayloadTooLarge;

                std.debug.assert(payload_len <= self.max_message_len);
                if (decoded.header.fin) return .{ .opcode = op, .fragment = .{} };
                return .{ .opcode = op, .fragment = .{ .opcode = op, .message_len = payload_len } };
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
        const validated = try self.validate_outgoing_node(node);

        if (validated.opcode == .ping or validated.opcode == .pong) {
            if (self.control_can_preempt()) {
                try self.tx_queue.push_front(node);
            } else {
                try self.tx_queue.push_back(node);
            }
        } else {
            try self.tx_queue.push_back(node);
        }

        self.tx_fragment = validated.fragment;
        self.assert_tx_invariants();
    }

    // Validates frame properties common to prepare and queue paths
    pub fn validate_outgoing_frame(
        self: *const Conn,
        fin: bool,
        opcode: types.Opcode,
        payload: []const u8,
        is_masked: bool,
    ) types.Error!void {
        if (!opcode.is_known()) return error.InvalidOpcode;

        const payload_len: u64 = @intCast(payload.len);
        if (payload_len > self.max_frame_len) return error.PayloadTooLarge;

        if (opcode.is_control()) {
            if (!fin) return error.ProtocolError;
            if (payload_len > types.ControlPayloadMax) return error.ProtocolError;
        } else {
            if (payload_len > self.max_message_len) return error.PayloadTooLarge;
        }

        try validate_outgoing_masking(self.role, is_masked);

        if (opcode == .close) try frame.validate_close_payload(payload);
    }

    pub fn prepare_frame(
        self: *const Conn,
        fin: bool,
        opcode: types.Opcode,
        payload: []const u8,
        is_masked: bool,
        masking_key_opt: ?types.MaskingKey,
    ) types.Error!FrameNode {
        try self.validate_outgoing_frame(fin, opcode, payload, is_masked);

        if (is_masked) {
            if (masking_key_opt == null) return error.MaskingKeyRequired;
        } else {
            if (masking_key_opt != null) return error.ProtocolError;
        }
        const key = masking_key_opt;

        var node = FrameNode{
            .payload = payload,
        };

        const header = types.FrameHeader{
            .payload_len = 0,
            .mask = is_masked,
            .opcode = @backingInt(opcode),

            .rsv3 = false,
            .rsv2 = false,
            .rsv1 = false,
            .fin = fin,
        };
        // encode_header derives the wire marker from the payload length.
        node.header_len = try frame.encode_header(
            &node.header_buf,
            header,
            @intCast(payload.len),
            key,
        );
        return node;
    }
};
