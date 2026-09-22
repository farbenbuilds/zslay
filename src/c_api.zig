const types = @import("types.zig");
const frame = @import("frame.zig");
const event = @import("event.zig");

const chunk_size_max: usize = 4096;

pub const ResultOk: c_int = 0;
pub const ResultProgress: c_int = 1;
pub const ResultProtocolError: c_int = -1;
pub const ResultCallbackError: c_int = -2;
pub const ResultInvalidArgument: c_int = -3;
pub const ResultQueueFull: c_int = -4;

// Receives at most len bytes: positive count, zero for would-block, negative on failure
pub const ZslayRecvCallback = *const fn (buf: [*]u8, len: usize, user_data: ?*anyopaque) callconv(.c) isize;

// Sends at most len bytes: positive count, zero for would-block, negative on failure
pub const ZslaySendCallback = *const fn (buf: [*]const u8, len: usize, user_data: ?*anyopaque) callconv(.c) isize;

// Fills exactly len random bytes and returns zero on success
pub const ZslayGenMaskCallback = *const fn (buf: [*]u8, len: usize, user_data: ?*anyopaque) callconv(.c) c_int;

// Delivers a transient payload chunk with explicit frame-boundary metadata
pub const ZslayOnFrameCallback = *const fn (
    opcode: u8,
    fin: u8,
    payload: ?[*]const u8,
    len: usize,
    payload_offset: u64,
    frame_len: u64,
    end_of_frame: u8,
    user_data: ?*anyopaque,
) callconv(.c) void;

// Aggregates C-style callbacks and the target user data pointer
const CContext = struct {
    user_data: ?*anyopaque,
    recv_fn: ZslayRecvCallback,
    send_fn: ZslaySendCallback,
    on_frame_fn: ZslayOnFrameCallback,
    gen_mask_fn: ?ZslayGenMaskCallback,
};

// Private container combining event.Conn and CContext
const ZslayConnImpl = struct {
    conn: event.Conn,
    c_ctx: CContext,
};

fn cast_opaque(comptime T: type, ptr: ?*anyopaque) ?*T {
    const raw = ptr orelse return null;
    if (@intFromPtr(raw) % @alignOf(T) != 0) return null;
    return @ptrCast(@alignCast(raw));
}

fn parse_opcode(raw: u8) ?types.Opcode {
    return switch (raw) {
        0x0 => .continuation,
        0x1 => .text,
        0x2 => .binary,
        0x8 => .close,
        0x9 => .ping,
        0xa => .pong,
        else => null,
    };
}

fn parse_role(raw: u8) ?types.EndpointRole {
    return switch (raw) {
        0 => .client,
        1 => .server,
        else => null,
    };
}

// Returns the size and alignment required for caller-owned connection storage
pub export fn zslay_conn_get_size() usize {
    return @sizeOf(ZslayConnImpl);
}

pub export fn zslay_conn_get_align() usize {
    return @alignOf(ZslayConnImpl);
}

// Returns the size and alignment required for one outgoing frame node
pub export fn zslay_frame_node_get_size() usize {
    return @sizeOf(event.Conn.FrameNode);
}

pub export fn zslay_frame_node_get_align() usize {
    return @alignOf(event.Conn.FrameNode);
}

// Initializes caller-owned connection state with mandatory role and limits
pub export fn zslay_conn_init(
    mem: ?*anyopaque,
    user_data: ?*anyopaque,
    recv_fn: ?ZslayRecvCallback,
    send_fn: ?ZslaySendCallback,
    on_frame_fn: ?ZslayOnFrameCallback,
    gen_mask_fn: ?ZslayGenMaskCallback,
    tx_buffer: ?*anyopaque,
    tx_node_count: usize,
    role: u8,
    max_frame_len: u64,
    max_message_len: u64,
) ?*anyopaque {
    const conn_impl = cast_opaque(ZslayConnImpl, mem) orelse return null;
    const tx_mem = tx_buffer orelse return null;
    if (@intFromPtr(tx_mem) % @alignOf(event.Conn.FrameNode) != 0) return null;

    const recv = recv_fn orelse return null;
    const send = send_fn orelse return null;
    const on_frame = on_frame_fn orelse return null;
    const endpoint_role = parse_role(role) orelse return null;

    const tx_nodes: [*]event.Conn.FrameNode = @ptrCast(@alignCast(tx_mem));
    const conn = event.Conn.init(tx_nodes[0..tx_node_count], .{
        .role = endpoint_role,
        .max_frame_len = max_frame_len,
        .max_message_len = max_message_len,
    }) catch return null;

    conn_impl.* = .{
        .conn = conn,
        .c_ctx = .{
            .user_data = user_data,
            .recv_fn = recv,
            .send_fn = send,
            .on_frame_fn = on_frame,
            .gen_mask_fn = gen_mask_fn,
        },
    };
    return conn_impl;
}

// Performs at most one transport read and one frame callback per invocation
pub export fn zslay_conn_recv(conn_ptr: ?*anyopaque) c_int {
    const conn_impl = cast_opaque(ZslayConnImpl, conn_ptr) orelse return ResultInvalidArgument;
    const conn = &conn_impl.conn;
    const action = conn.advance_rx() catch return ResultProtocolError;

    switch (action) {
        .need_header => {
            const buf = conn.get_header_buffer();
            const read = conn_impl.c_ctx.recv_fn(buf.ptr, buf.len, conn_impl.c_ctx.user_data);
            if (read < 0) return ResultCallbackError;
            if (read == 0) return ResultOk;

            const read_len: usize = @intCast(read);
            if (read_len > buf.len) return ResultCallbackError;
            conn.advance_header_read(read_len) catch return ResultCallbackError;
            return ResultProgress;
        },
        .need_payload => {
            const decoded = conn.decoded_header orelse return ResultProtocolError;
            const remaining: u64 = decoded.extended_len - conn.payload_bytes_processed;

            var chunk_buf: [chunk_size_max]u8 = undefined;
            const chunk_size: usize = @intCast(@min(chunk_buf.len, remaining));
            const read = conn_impl.c_ctx.recv_fn(&chunk_buf, chunk_size, conn_impl.c_ctx.user_data);
            if (read < 0) return ResultCallbackError;
            if (read == 0) return ResultOk;

            const read_len: usize = @intCast(read);
            if (read_len > chunk_size) return ResultCallbackError;

            const payload_offset = conn.payload_bytes_processed;
            const read_len_u64: u64 = @intCast(read_len);
            const end_of_frame = read_len_u64 == remaining;

            if (decoded.header.mask) {
                const key = decoded.masking_key orelse return ResultProtocolError;
                frame.mask(chunk_buf[0..read_len], key, payload_offset);
            }

            conn_impl.c_ctx.on_frame_fn(
                @intCast(decoded.header.opcode),
                if (decoded.header.fin) 1 else 0,
                chunk_buf[0..read_len].ptr,
                read_len,
                payload_offset,
                decoded.extended_len,
                if (end_of_frame) 1 else 0,
                conn_impl.c_ctx.user_data,
            );

            conn.advance_payload_read(read_len_u64) catch return ResultProtocolError;
            if (end_of_frame) conn.complete_frame();
            return ResultProgress;
        },
        .emit_frame => {
            const decoded = conn.decoded_header orelse return ResultProtocolError;
            conn_impl.c_ctx.on_frame_fn(
                @intCast(decoded.header.opcode),
                if (decoded.header.fin) 1 else 0,
                null,
                0,
                0,
                0,
                1,
                conn_impl.c_ctx.user_data,
            );
            conn.complete_frame();
            return ResultProgress;
        },
        _ => return ResultProtocolError,
    }
}

// Flushes queued frames to the transport layer using static dispatch
pub export fn zslay_conn_send(conn_ptr: ?*anyopaque) c_int {
    const conn_impl = cast_opaque(ZslayConnImpl, conn_ptr) orelse return ResultInvalidArgument;
    const conn = &conn_impl.conn;

    while (conn.advance_tx()) |action| {
        switch (action) {
            .write_header => {
                const buf = conn.get_tx_header_buffer();
                const sent = conn_impl.c_ctx.send_fn(buf.ptr, buf.len, conn_impl.c_ctx.user_data);
                if (sent < 0) return ResultCallbackError;
                if (sent == 0) return ResultOk;

                const sent_len: usize = @intCast(sent);
                if (sent_len > buf.len) return ResultCallbackError;
                conn.advance_tx_header(sent_len) catch return ResultCallbackError;
            },
            .write_payload => {
                const node = &conn.tx_queue.buffer[conn.tx_queue.head];
                const remaining: usize = node.payload.len - node.sent_payload;
                const is_masked = (node.header_buf[1] & 0x80) != 0;

                if (!is_masked) {
                    const to_send = node.payload[node.sent_payload .. node.sent_payload + remaining];
                    const sent = conn_impl.c_ctx.send_fn(to_send.ptr, to_send.len, conn_impl.c_ctx.user_data);
                    if (sent < 0) return ResultCallbackError;
                    if (sent == 0) return ResultOk;

                    const sent_len: usize = @intCast(sent);
                    if (sent_len > to_send.len) return ResultCallbackError;
                    node.sent_payload += sent_len;
                    continue;
                }

                var chunk_buf: [chunk_size_max]u8 = undefined;
                const chunk_size: usize = @min(chunk_buf.len, remaining);
                @memcpy(
                    chunk_buf[0..chunk_size],
                    node.payload[node.sent_payload .. node.sent_payload + chunk_size],
                );

                var key: types.MaskingKey = undefined;
                const key_index = node.header_size - key.len;
                @memcpy(&key, node.header_buf[key_index .. key_index + key.len]);
                frame.mask(chunk_buf[0..chunk_size], key, @intCast(node.sent_payload));

                const sent = conn_impl.c_ctx.send_fn(&chunk_buf, chunk_size, conn_impl.c_ctx.user_data);
                if (sent < 0) return ResultCallbackError;
                if (sent == 0) return ResultOk;

                const sent_len: usize = @intCast(sent);
                if (sent_len > chunk_size) return ResultCallbackError;
                node.sent_payload += sent_len;
            },
            _ => return ResultProtocolError,
        }
    }
    return ResultOk;
}

// Serializes a validated frame into caller-owned node storage
pub export fn zslay_conn_prepare_frame(
    conn_ptr: ?*anyopaque,
    node_ptr: ?*anyopaque,
    fin: u8,
    opcode: u8,
    payload: ?[*]const u8,
    payload_len: usize,
    is_masked: u8,
) c_int {
    const conn_impl = cast_opaque(ZslayConnImpl, conn_ptr) orelse return ResultInvalidArgument;
    const node = cast_opaque(event.Conn.FrameNode, node_ptr) orelse return ResultInvalidArgument;
    if (fin > 1 or is_masked > 1) return ResultInvalidArgument;

    const op = parse_opcode(opcode) orelse return ResultInvalidArgument;
    const payload_slice: []const u8 = if (payload_len == 0)
        &.{}
    else blk: {
        const payload_ptr = payload orelse return ResultInvalidArgument;
        break :blk payload_ptr[0..payload_len];
    };

    const masked = is_masked == 1;
    const should_mask = conn_impl.conn.role == .client;
    if (masked != should_mask) return ResultProtocolError;

    var masking_key: ?types.MaskingKey = null;
    if (masked) {
        const gen = conn_impl.c_ctx.gen_mask_fn orelse return ResultProtocolError;
        var key = [_]u8{0} ** 4;
        if (gen(&key, key.len, conn_impl.c_ctx.user_data) != 0) return ResultCallbackError;
        masking_key = key;
    }

    const prepared = conn_impl.conn.prepare_frame(
        fin == 1,
        op,
        payload_slice,
        masked,
        masking_key,
    ) catch return ResultProtocolError;

    node.* = prepared;
    return ResultOk;
}

// Validates and appends a pre-serialized frame node to the TX queue
pub export fn zslay_conn_queue_frame(
    conn_ptr: ?*anyopaque,
    node_ptr: ?*anyopaque,
) c_int {
    const conn_impl = cast_opaque(ZslayConnImpl, conn_ptr) orelse return ResultInvalidArgument;
    const node = cast_opaque(event.Conn.FrameNode, node_ptr) orelse return ResultInvalidArgument;

    conn_impl.conn.queue_frame(node.*) catch |err| return switch (err) {
        error.QueueFull => ResultQueueFull,
        else => ResultProtocolError,
    };
    return ResultOk;
}
