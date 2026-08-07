const std = @import("std");
const types = @import("types.zig");
const frame = @import("frame.zig");
const queue = @import("queue.zig");

// invoked to read raw data from underlying transport
pub const RecvCallback = *const fn (ctx: *anyopaque, buf: []u8) anyerror!usize;

// invoked to write raw serialized data to the transport
pub const SendCallback = *const fn (ctx: *anyopaque, buf: []const u8) anyerror!usize;

// invoked to populate a 4-byte WebSocket masking key
pub const GenMaskCallback = *const fn (ctx: *anyopaque, buf: *types.MaskingKey) anyerror!void;

// invoked when a WebSocket frame is successfully parsed
pub const OnFrameCallback = *const fn (
    ctx: *anyopaque,
    opcode: types.Opcode,
    fin: bool,
    payload: []const u8,
) anyerror!void;

// group of all callbacks provided by the consumer
pub const Callbacks = struct {
    recv_callback: ?RecvCallback = null,
    send_callback: ?SendCallback = null,
    gen_mask_callback: ?GenMaskCallback = null,
    on_frame_callback: ?OnFrameCallback = null,
};

// state of the WebSocket frame receiver machine
// Explicit u8 backing for compact state tracking and DOD caching
pub const RxState = enum(u8) {
    read_base_header = 0,
    read_extended_header = 1,
    read_payload = 2,
};

// zero-allocation, I/O-agnostic WebSocket connection context
// coordinates frame streaming, XOR masking, and instrusive TX queueing
pub const Conn = struct {
    // group of all callbacks provided by the consumer
    callbacks: Callbacks,

    // consumer provided state context
    ctx: *anyopaque,

    // queue to store outgoing frames using a bounded ring buffer
    tx_queue: queue.Queue(FrameNode),

    // decoded frame header of currently processed incoming frame
    decoded_header: ?frame.DecoderHeader = null,

    // bytes of current payload processed so far
    payload_bytes_processed: u64 = 0,

    // total header bytes parsed so far
    header_bytes_read: usize = 0,

    // current expected physical header size (2 to 14 bytes)
    header_bytes_needed: usize = 2,

    // temporary buffer to accumulate and parse incoming frame headers
    // maximum possible WebSocket frame header size is 14 bytes
    header_buf: [14]u8 = undefined,

    // receiver machine parsing state
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

    // initializes a Conn context with the required callbacks and user-provided TX buffer
    pub fn init(
        ctx: *anyopaque,
        callbacks: Callbacks,
        tx_buffer: []FrameNode,
    ) Conn {
        return .{
            .callbacks = callbacks,
            .ctx = ctx,
            .tx_queue = queue.Queue(FrameNode).init(tx_buffer),
        };
    }

    // drives the RX state machine
    // reads the raw socket streams and delivers parsed slices to the user
    pub fn handle_recv(self: *Conn) anyerror!void {
        while (true) {
            switch (self.rx_state) {
                .read_base_header => {
                    const needed = self.header_bytes_needed - self.header_bytes_read;

                    if (needed > 0) {
                        const read = try self.callbacks.recv_callback.?(
                            self.ctx,
                            self.header_buf[self.header_bytes_read..self.header_bytes_needed],
                        );

                        if (read == 0) return;
                        self.header_bytes_read += read;

                        if (self.header_bytes_read < self.header_bytes_needed) {
                            return;
                        }
                    }

                    const b1 = self.header_buf[1];
                    const base_len = b1 & 0x7f;
                    const mask_flag = (b1 & 0x80) != 0;

                    var needed_header_size: usize = 2;

                    if (base_len == 126) {
                        needed_header_size += 2;
                    } else if (base_len == 127) {
                        needed_header_size += 8;
                    }

                    if (mask_flag) {
                        needed_header_size += 4;
                    }

                    self.header_bytes_needed = needed_header_size;

                    if (needed_header_size > 2) {
                        self.rx_state = .read_extended_header;
                    } else {
                        self.decoded_header = try frame.decode_header(self.header_buf[0..self.header_bytes_needed]);
                        self.rx_state = .read_payload;
                    }
                },

                .read_extended_header => {
                    const needed = self.header_bytes_needed - self.header_bytes_read;

                    if (needed > 0) {
                        const read = try self.callbacks.recv_callback.?(
                            self.ctx,
                            self.header_buf[self.header_bytes_read..self.header_bytes_needed],
                        );

                        if (read == 0) return;
                        self.header_bytes_read += read;

                        if (self.header_bytes_read < self.header_bytes_needed) {
                            return;
                        }
                    }

                    self.decoded_header = try frame.decode_header(self.header_buf[0..self.header_bytes_needed]);
                    self.rx_state = .read_payload;
                },

                .read_payload => {
                    const dh = self.decoded_header orelse return error.ProtocolError;
                    const total_len = dh.extended_len;
                    const remaining = total_len - self.payload_bytes_processed;

                    if (remaining == 0) {
                        const op: types.Opcode = @enumFromInt(dh.header.opcode);

                        try self.callbacks.on_frame_callback.?(
                            self.ctx,
                            op,
                            dh.header.fin,
                            &.{},
                        );

                        self.reset_rx();
                        continue;
                    }

                    var chunk_buf: [4096]u8 = undefined;
                    const chunk_size = @as(usize, @intCast(@min(chunk_buf.len, remaining)));

                    const read = try self.callbacks.recv_callback.?(self.ctx, chunk_buf[0..chunk_size]);
                    if (read == 0) return;

                    if (dh.header.mask) {
                        if (dh.masking_key) |key| {
                            frame.mask(chunk_buf[0..read], key, @intCast(self.payload_bytes_processed));
                        }
                    }

                    const op: types.Opcode = @enumFromInt(dh.header.opcode);

                    try self.callbacks.on_frame_callback.?(
                        self.ctx,
                        op,
                        dh.header.fin,
                        chunk_buf[0..read],
                    );

                    self.payload_bytes_processed += read;
                    if (self.payload_bytes_processed == total_len) {
                        self.reset_rx();
                    }
                },
            }
        }
    }

    // transmits headers and masked payload slices in non-blocking chunks
    pub fn handle_send(self: *Conn) anyerror!void {
        while (self.tx_queue.pop_front()) |node| {
            var n = node; // process by value

            if (n.sent_header < n.header_size) {
                const to_send = n.header_buf[n.sent_header..n.header_size];
                const sent = try self.callbacks.send_callback.?(self.ctx, to_send);

                if (sent == 0) {
                    try self.tx_queue.push_front(n);
                    return;
                }

                n.sent_header += sent;

                if (n.sent_header < n.header_size) {
                    try self.tx_queue.push_front(n);
                    return;
                }
            }

            if (n.sent_payload < n.payload.len) {
                const remaining = n.payload.len - n.sent_payload;
                const b1 = n.header_buf[1];
                const is_masked = (b1 & 0x80) != 0;

                var sent: usize = 0;
                if (is_masked) {
                    var chunk_buf: [4096]u8 = undefined;
                    const chunk_size = @as(usize, @intCast(@min(chunk_buf.len, remaining)));
                    @memcpy(chunk_buf[0..chunk_size], n.payload[n.sent_payload .. n.sent_payload + chunk_size]);

                    var key: types.MaskingKey = undefined;
                    const key_index = n.header_size - 4;
                    @memcpy(&key, n.header_buf[key_index .. key_index + 4]);

                    frame.mask(chunk_buf[0..chunk_size], key, n.sent_payload);

                    sent = try self.callbacks.send_callback.?(self.ctx, chunk_buf[0..chunk_size]);
                } else {
                    const to_send = n.payload[n.sent_payload .. n.sent_payload + remaining];
                    sent = try self.callbacks.send_callback.?(self.ctx, to_send);
                }

                if (sent == 0) {
                    try self.tx_queue.push_front(n);
                    return;
                }

                n.sent_payload += sent;

                if (n.sent_payload < n.payload.len) {
                    try self.tx_queue.push_front(n);
                    return;
                }
            }
        }
    }

    // pushes an outgoing FrameNode into transmission queue
    pub fn queue_frame(self: *Conn, node: FrameNode) !void {
        try self.tx_queue.push_back(node);
    }

    // pure function that builds a frame header and returns a new FrameNode
    pub fn prepare_frame(
        self: *Conn,
        fin: bool,
        opcode: types.Opcode,
        payload: []const u8,
        is_masked: bool,
    ) !FrameNode {
        var node = FrameNode{
            .payload = payload,
        };

        var masking_key: ?types.MaskingKey = null;

        if (is_masked) {
            var key: types.MaskingKey = undefined;

            if (self.callbacks.gen_mask_callback) |gen| {
                try gen(self.ctx, &key);
            } else {
                key = [_]u8{ 0, 0, 0, 0 };
            }

            masking_key = key;
        }

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
            masking_key,
        );

        node.header_size = header_size;

        return node;
    }

    // restores the receiver state to parse the next frame
    fn reset_rx(self: *Conn) void {
        self.rx_state = .read_base_header;
        self.header_bytes_read = 0;
        self.header_bytes_needed = 2;

        self.decoded_header = null;
        self.payload_bytes_processed = 0;
    }
};
