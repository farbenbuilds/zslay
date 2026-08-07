const std = @import("std");
const types = @import("types.zig");
const frame = @import("frame.zig");
const event = @import("event.zig");

// C-style callback for receiving data
pub const zslay_recv_callback = *const fn (buf: [*]u8, len: usize, user_data: ?*anyopaque) callconv(.C) isize;

// C-style callback for sending data
pub const zslay_send_callback = *const fn (buf: [*]const u8, len: usize, user_data: ?*anyopaque) callconv(.C) isize;

// C-style callback for generating random mask keys
pub const zslay_gen_mask_callback = *const fn (buf: [*]const u8, user_data: ?*anyopaque) callconv(.C) isize;

// C-style callback invoked when a frame is parsed
pub const zslay_on_frame_callback = *const fn (opcode: u8, fin: u8, payload: [*]const u8, len: usize, user_data: ?*anyopaque) callconv(.C) void;

// aggregates C-style callbacks and the target user data pointer
const CContext = struct {
    user_data: ?*anyopaque,
    recv_fn: zslay_recv_callback,
    send_fn: zslay_send_callback,

    on_frame_fn: zslay_on_frame_callback,
    gen_mask_fn: zslay_gen_mask_callback,
};

// private container combining event.Conn and CContext
const ZslayConnImpl = struct {
    conn: event.Conn,
    c_ctx: CContext,
};

// intercepts Zig callback to call C-style receive callback
fn recv_bridge(ctx: *anyopaque, buf: []u8) anyerror!usize {
    const conn_impl: *ZslayConnImpl = @ptrCast(@alignCast(ctx));
    const c_ctx = &conn_impl.c_ctx;
    const res = c_ctx.recv_fn(buf.ptr, buf.len, c_ctx.user_data);

    if (res < 0) {
        return error.ProtocolError;
    }

    return @intCast(res);
}

// intercepts Zig callback to call C-style send callback
fn send_bridge(ctx: *anyopaque, buf: []const u8) anyerror!usize {
    const conn_impl: *ZslayConnImpl = @ptrCast(@alignCast(ctx));
    const c_ctx = &conn_impl.c_ctx;
    const res = c_ctx.send_fn(buf.ptr, buf.len, c_ctx.user_data);

    if (res < 0) {
        return error.ProtocolError;
    }

    return @intCast(res);
}

// intercepts Zig callback to call C-style mask generator
fn gen_mask_bridge(ctx: *anyopaque, buf: *[1]u8) anyerror!void {
    const conn_impl: *ZslayConnImpl = @ptrCast(@alignCast(ctx));
    const c_ctx = &conn_impl.c_ctx;

    if (c_ctx.gen_mask_fn) |gen| {
        gen(buf, c_ctx.user_data);
    }
}

// intercepts Zig callback to call C-style frame dispatcher
fn on_frame_bridge(ctx: *anyopaque, opcode: types.Opcode, fin: bool, payload: []const u8) anyerror!void {
    const conn_impl: *ZslayConnImpl = @ptrCast(@alignCast(ctx));
    const c_ctx = &conn_impl.c_ctx;

    c_ctx.on_frame_fn(
        @intFromEnum(opcode),
        if (fin) 1 else 0,
        payload.ptr,

        payload.len,
        c_ctx.user_data,
    );
}

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
    mem: [*]u8,
    user_data: ?*anyopaque,
    recv_fn: zslay_recv_callback,
    send_fn: zslay_send_callback,
    on_frame_fn: zslay_on_frame_callback,
    gen_mask_fn: ?zslay_gen_mask_callback,
) ?*anyopaque {
    const conn_impl: *ZslayConnImpl = @ptrCast(@alignCast(mem));

    conn_impl.c_ctx = CContext{
        .user_data = user_data,
        .recv_fn = recv_fn,
        .send_fn = send_fn,

        .on_frame_fn = on_frame_fn,
        .gen_mask_fn = gen_mask_fn,
    };

    conn_impl.conn = event.Conn.init(
        conn_impl,
        recv_bridge,
        send_bridge,

        on_frame_bridge,
        if (gen_mask_fn != null) gen_mask_bridge else null,
    );

    return conn_impl;
}

// triggers the frame parsing state machine
pub export fn zslay_conn_recv(conn_ptr: *anyopaque) c_int {
    const conn_impl: *ZslayConnImpl = @ptrCast(@alignCast(conn_ptr));

    conn_impl.conn.handle_recv() catch {
        return -1;
    };

    return 0;
}

// flushes queued frames to the transport layer
pub export fn zslay_conn_send(conn_ptr: *anyopaque) c_int {
    const conn_impl: *ZslayConnImpl = @ptrCast(@alignCast(conn_ptr));

    conn_impl.conn.handle_send() catch {
        return -1;
    };

    return 0;
}

// serializes custom payloads into C-allocated frame nodes
pub export fn zslay_conn_prepare_frame(
    conn_ptr: *anyopaque,
    node_ptr: *anyopaque,
    fin: u8,
    opcode: u8,
    payload: [*]const u8,
    payload_len: usize,
    is_maked: u8,
) c_int {
    const conn_impl: *ZslayConnImpl = @ptrCast(@alignCast(conn_ptr));
    const node: *event.Conn.FrameNode = @ptrCast(@alignCast(node_ptr));
    const op: types.Opcode = @enumFromInt(opcode);

    conn_impl.conn.prepare_frame(
        node,
        fin != 0,
        op,

        payload[0..payload_len],
        is_maked != 0,
    ) catch {
        return -1;
    };

    return 0;
}

// appends a pre-serialized frame node to the TX queue
pub export fn zslay_conn_queue_frame(
    conn_ptr: *anyopaque,
    node_ptr: *anyopaque,
) void {
    const conn_impl: *ZslayConnImpl = @ptrCast(@alignCast(conn_ptr));
    const node: *event.Conn.FrameNode = @ptrCast(@alignCast(node_ptr));

    conn_impl.conn.queue_frame(node);
}
