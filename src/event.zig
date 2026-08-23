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

// zero-allocation, I/O-agnostic WebSocket connection context
// coordinates frame streaming, XOR masking, and instrusive TX queueing
pub const Conn = struct {
    payload_bytes_processed: u64 = 0,

    tx_queue: queue.Queue(FrameNode),

    header_bytes_read: usize = 0,
    header_bytes_needed: usize = 2,

    decoded_header: ?frame.DecodedHeader = null,

    header_buf: [14]u8 = undefined,
    rx_state: RxState = .read_base_header,

    // ring buffer element representing an outgoing frame
    pub const FrameNode = struct {
        payload: []const u8 = &.{},

        header_size: usize = 0,
        sent_header: usize = 0,
        sent_payload: usize = 0,

        // maximum possible WebSocket frame header size is 14 bytes
        header_buf: [14]u8 = undefined,
    };

    // initializes a Conn context with the user-provided TX buffer
    pub fn init(tx_buffer: []FrameNode) Conn {
        return .{
            .tx_queue = queue.Queue(FrameNode).init(tx_buffer),
        };
    }

    // drives the RX state machine
    // returns the next required action to the caller
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
                } else {
                    self.decoded_header = try frame.decode_header(self.header_buf[0..self.header_bytes_needed]);
                    self.rx_state = .read_payload;
                    return self.advance_rx();
                }
            },
            .read_extended_header => {
                if (self.header_bytes_read < self.header_bytes_needed) return RxAction.need_header;

                self.decoded_header = try frame.decode_header(self.header_buf[0..self.header_bytes_needed]);
                self.rx_state = .read_payload;
                return self.advance_rx();
            },
            .read_payload => {
                const dh = self.decoded_header orelse return error.ProtocolError;
                const remaining = dh.extended_len - self.payload_bytes_processed;

                if (remaining == 0) return RxAction.emit_frame;
                return RxAction.need_payload;
            },
        }
    }

    pub fn complete_frame(self: *Conn) void {
        self.rx_state = .read_base_header;
        self.header_bytes_read = 0;
        self.header_bytes_needed = 2;
        self.decoded_header = null;
        self.payload_bytes_processed = 0;
    }

    pub fn get_header_buffer(self: *Conn) []u8 {
        return self.header_buf[self.header_bytes_read..self.header_bytes_needed];
    }

    pub fn advance_header_read(self: *Conn, bytes: usize) void {
        self.header_bytes_read += bytes;
    }

    // transmits headers and masked payload slices
    pub fn advance_tx(self: *Conn) ?TxAction {
        const node = self.tx_queue.buffer[self.tx_queue.head]; // peek
        if (self.tx_queue.len == 0) return null;

        if (node.sent_header < node.header_size) return TxAction.write_header;
        if (node.sent_payload < node.payload.len) return TxAction.write_payload;

        _ = self.tx_queue.pop_front();
        return self.advance_tx();
    }

    pub fn get_tx_header_buffer(self: *Conn) []const u8 {
        const node = self.tx_queue.buffer[self.tx_queue.head];
        return node.header_buf[node.sent_header..node.header_size];
    }

    pub fn advance_tx_header(self: *Conn, bytes: usize) void {
        self.tx_queue.buffer[self.tx_queue.head].sent_header += bytes;
    }

    // pushes an outgoing FrameNode into transmission queue
    pub fn queue_frame(self: *Conn, node: FrameNode) !void {
        try self.tx_queue.push_back(node);
    }

    // pure function that builds a frame header and returns a new FrameNode
    pub fn prepare_frame(
        fin: bool,
        opcode: types.Opcode,
        payload: []const u8,
        is_masked: bool,
        masking_key_opt: ?types.MaskingKey,
    ) !FrameNode {
        var node = FrameNode{
            .payload = payload,
        };

        const key = if (is_masked) (masking_key_opt orelse [_]u8{ 0, 0, 0, 0 }) else null;

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

        const header_size = try frame.encode_header(
            &node.header_buf,
            header_struct,
            payload.len,
            key,
        );

        node.header_size = header_size;
        return node;
    }
};
