const types = @import("types.zig");
const frame = @import("frame.zig");
const event = @import("event.zig");

// C-style callback for receiving data
pub const ZslayRecvCallback = *const fn (buf: [*]u8, len: usize, user_data: ?*anyopaque) callconv(.c) isize;

// C-style callback for sending data
pub const ZslaySendCallback = *const fn (buf: [*]const u8, len: usize, user_data: ?*anyopaque) callconv(.c) isize;

// C-style callback for generating random mask keys
pub const ZslayGenMaskCallback = *const fn (buf: [*]u8, user_data: ?*anyopaque) callconv(.c) isize;

// C-style callback invoked when a frame is parsed
pub const ZslayOnFrameCallback = *const fn (opcode: u8, fin: u8, payload: [*]const u8, len: usize, user_data: ?*anyopaque) callconv(.c) void;

// aggregates C-style callbacks and the target user data pointer
const CContext = struct {
    user_data: ?*anyopaque,
    recv_fn: ZslayRecvCallback,
    send_fn: ZslaySendCallback,
    on_frame_fn: ZslayOnFrameCallback,
    gen_mask_fn: ?ZslayGenMaskCallback,
};

// private container combining event.Conn and CContext
const ZslayConnImpl = struct {
    conn: event.Conn,
    c_ctx: CContext,
};

// returns the physical size of the internal context struct
pub export fn zslay_conn_get_size() usize {
    return @sizeOf(ZslayConnImpl);
}

// returns the physical size of an outgoing frame node
pub export fn zslay_frame_node_get_size() usize {
    return @sizeOf(event.Conn.FrameNode);
}

// allocates and initializes the connection state
pub export fn zslay_conn_init(
    mem: *anyopaque,
    user_data: ?*anyopaque,
    recv_fn: ZslayRecvCallback,
    send_fn: ZslaySendCallback,
    on_frame_fn: ZslayOnFrameCallback,
    gen_mask_fn: ?ZslayGenMaskCallback,
    tx_buffer: *anyopaque,
    tx_node_count: usize,
) ?*anyopaque {
    const conn_impl: *ZslayConnImpl = @ptrCast(@alignCast(mem));
    const tx_nodes: [*]event.Conn.FrameNode = @ptrCast(@alignCast(tx_buffer));

    conn_impl.c_ctx = CContext{
        .user_data = user_data,
        .recv_fn = recv_fn,
        .send_fn = send_fn,
        .on_frame_fn = on_frame_fn,
        .gen_mask_fn = gen_mask_fn,
    };

    conn_impl.conn = event.Conn.init(tx_nodes[0..tx_node_count]);
    return conn_impl;
}

// triggers the frame parsing state machine using static dispatch on enums (DOD)
pub export fn zslay_conn_recv(conn_ptr: *anyopaque) c_int {
    const conn_impl: *ZslayConnImpl = @ptrCast(@alignCast(conn_ptr));
    const c = &conn_impl.conn;

    while (true) {
        const action = c.advance_rx() catch return -1;

        switch (action) {
            .need_header => {
                const buf = c.get_header_buffer();
                const read = conn_impl.c_ctx.recv_fn(buf.ptr, buf.len, conn_impl.c_ctx.user_data);
                if (read <= 0) return 0;
                c.advance_header_read(@intCast(read));
            },
            .need_payload => {
                const dh = c.decoded_header orelse return -1;
                const remaining = dh.extended_len - c.payload_bytes_processed;

                var chunk_buf: [4096]u8 = undefined;
                const chunk_size = @as(usize, @intCast(@min(chunk_buf.len, remaining)));

                const read = conn_impl.c_ctx.recv_fn(&chunk_buf, chunk_size, conn_impl.c_ctx.user_data);
                if (read <= 0) return 0;

                const read_u: usize = @intCast(read);
                if (dh.header.mask) {
                    if (dh.masking_key) |key| {
                        frame.mask(chunk_buf[0..read_u], key, @intCast(c.payload_bytes_processed));
                    }
                }

                conn_impl.c_ctx.on_frame_fn(
                    @intCast(dh.header.opcode),
                    if (dh.header.fin) 1 else 0,
                    &chunk_buf,
                    read_u,
                    conn_impl.c_ctx.user_data,
                );

                c.payload_bytes_processed += read_u;
            },
            .emit_frame => {
                const dh = c.decoded_header orelse return -1;

                if (dh.extended_len == 0) {
                    conn_impl.c_ctx.on_frame_fn(
                        @intCast(dh.header.opcode),
                        if (dh.header.fin) 1 else 0,
                        &[_]u8{},
                        0,
                        conn_impl.c_ctx.user_data,
                    );
                }

                c.complete_frame();
            },
            _ => return -1,
        }
    }
}

// flushes queued frames to the transport layer using static dispatch
pub export fn zslay_conn_send(conn_ptr: *anyopaque) c_int {
    const conn_impl: *ZslayConnImpl = @ptrCast(@alignCast(conn_ptr));
    const c = &conn_impl.conn;

    while (c.advance_tx()) |action| {
        switch (action) {
            .write_header => {
                const buf = c.get_tx_header_buffer();
                const sent = conn_impl.c_ctx.send_fn(buf.ptr, buf.len, conn_impl.c_ctx.user_data);
                if (sent <= 0) return 0;
                c.advance_tx_header(@intCast(sent));
            },
            .write_payload => {
                var node = &c.tx_queue.buffer[c.tx_queue.head];
                const remaining = node.payload.len - node.sent_payload;
                const b1 = node.header_buf[1];
                const is_masked = (b1 & 0x80) != 0;

                var sent_out: usize = 0;
                if (is_masked) {
                    var chunk_buf: [4096]u8 = undefined;
                    const chunk_size = @as(usize, @intCast(@min(chunk_buf.len, remaining)));
                    @memcpy(chunk_buf[0..chunk_size], node.payload[node.sent_payload .. node.sent_payload + chunk_size]);

                    var key: types.MaskingKey = undefined;
                    const key_index = node.header_size - 4;
                    @memcpy(&key, node.header_buf[key_index .. key_index + 4]);

                    frame.mask(chunk_buf[0..chunk_size], key, node.sent_payload);

                    const sent = conn_impl.c_ctx.send_fn(&chunk_buf, chunk_size, conn_impl.c_ctx.user_data);
                    if (sent <= 0) return 0;
                    sent_out = @intCast(sent);
                } else {
                    const to_send = node.payload[node.sent_payload .. node.sent_payload + remaining];
                    const sent = conn_impl.c_ctx.send_fn(to_send.ptr, to_send.len, conn_impl.c_ctx.user_data);
                    if (sent <= 0) return 0;
                    sent_out = @intCast(sent);
                }

                node.sent_payload += sent_out;
            },
            _ => return -1,
        }
    }
    return 0;
}

// serializes custom payloads into C-allocated frame nodes
pub export fn zslay_conn_prepare_frame(
    conn_ptr: *anyopaque,
    node_ptr: *anyopaque,
    fin: u8,
    opcode: u8,
    payload: ?[*]const u8,
    payload_len: usize,
    is_masked: u8,
) c_int {
    const conn_impl: *ZslayConnImpl = @ptrCast(@alignCast(conn_ptr));
    const node: *event.Conn.FrameNode = @ptrCast(@alignCast(node_ptr));
    const op: types.Opcode = @enumFromInt(opcode);
    const slice = if (payload_len == 0) &[_]u8{} else payload.?[0..payload_len];

    var masking_key_opt: ?types.MaskingKey = null;
    if (is_masked != 0) {
        if (conn_impl.c_ctx.gen_mask_fn) |gen| {
            var key: types.MaskingKey = undefined;
            const res = gen(&key, conn_impl.c_ctx.user_data);
            if (res >= 0) {
                masking_key_opt = key;
            }
        }
    }

    node.* = event.Conn.prepare_frame(
        fin != 0,
        op,
        slice,
        is_masked != 0,
        masking_key_opt,
    ) catch return -1;

    return 0;
}

// appends a pre-serialized frame node to the TX queue
pub export fn zslay_conn_queue_frame(
    conn_ptr: *anyopaque,
    node_ptr: *anyopaque,
) c_int {
    const conn_impl: *ZslayConnImpl = @ptrCast(@alignCast(conn_ptr));
    const node: *event.Conn.FrameNode = @ptrCast(@alignCast(node_ptr));

    conn_impl.conn.queue_frame(node.*) catch return -1;
    return 0;
}
