const std = @import("std");
const types = @import("types.zig");
const frame = @import("frame.zig");
const event = @import("event.zig");

// Upper bound on bytes read from or written to the transport per callback
const MaxChunkSize: usize = 4096;

// Stack buffer used to stream receive payload chunks
const ChunkBuffer = [MaxChunkSize]u8;

// Keep one event-loop poll from monopolizing the caller
const MaxSendCallbacksPerCall: usize = 64;
const MaxSendBytesPerCall: usize = 256 * 1024;
const MaxUnmaskedChunkSize: usize = 64 * 1024;

// Opaque-handle identity and ABI revision
const ConnMagic: u64 = 0x5a73_6c61_7943_6f6e;
pub const AbiVersion: u32 = 1;

pub const ResultOk: c_int = 0;
pub const ResultProgress: c_int = 1;
pub const ResultProtocolError: c_int = -1;
pub const ResultCallbackError: c_int = -2;
pub const ResultInvalidArgument: c_int = -3;
pub const ResultQueueFull: c_int = -4;
pub const ResultReentrant: c_int = -5;
pub const ResultInvalidUtf8: c_int = -6;

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
const Callbacks = struct {
    user_data: ?*anyopaque,
    recv_fn: ZslayRecvCallback,
    send_fn: ZslaySendCallback,
    on_frame_fn: ZslayOnFrameCallback,
    gen_mask_fn: ?ZslayGenMaskCallback,
};

const CallbackState = enum(u8) {
    none = 0,
    recv = 1,
    send = 2,
    mask = 3,
    on_frame = 4,
};

// Private container combining event.Conn, callbacks, and a masked TX scratch chunk
const ZslayConn = struct {
    magic: u64 = 0,
    abi_version: u32 = 0,
    callback_state: CallbackState = .none,

    conn: event.Conn,
    callbacks: Callbacks,

    tx_chunk: ChunkBuffer = undefined,
    tx_chunk_len: usize = 0,
    tx_chunk_start: usize = 0,
    tx_chunk_sent: usize = 0,

    rx_stage: types.FrameHeaderBuffer = undefined,
    rx_stage_len: usize = 0,
    rx_stage_off: usize = 0,
    rx_chunk_start: usize = 0,
    rx_chunk_len: usize = 0,
};

// Stable empty queue storage for receive-only connections
var empty_tx_nodes: [0]event.FrameNode = .{};

// Tracks any callback invocation so init cannot mutate a live handle
threadlocal var callback_depth: u32 = 0;

fn cast_opaque(comptime T: type, ptr: ?*anyopaque) ?*T {
    const raw = ptr orelse return null;
    if (@intFromPtr(raw) % @alignOf(T) != 0) return null;
    return @ptrCast(@alignCast(raw));
}

fn as_conn(ptr: ?*anyopaque) ?*ZslayConn {
    const zslay_conn = cast_opaque(ZslayConn, ptr) orelse return null;
    if (zslay_conn.magic != ConnMagic or zslay_conn.abi_version != AbiVersion) return null;
    return zslay_conn;
}

fn invalidate(zslay_conn: *ZslayConn) void {
    zslay_conn.magic = 0;
    zslay_conn.abi_version = 0;
}

fn ranges_overlap(a_start: usize, a_len: usize, b_start: usize, b_len: usize) bool {
    if (a_len == 0 or b_len == 0) return false;

    const a_end = std.math.add(usize, a_start, a_len) catch return true;
    const b_end = std.math.add(usize, b_start, b_len) catch return true;
    return a_start < b_end and b_start < a_end;
}

fn frame_entry_allowed(zslay_conn: *const ZslayConn) bool {
    return callback_depth == 0 or zslay_conn.callback_state == .on_frame;
}

fn range_overlaps_conn_or_rx(zslay_conn: *const ZslayConn, start: usize, len: usize) bool {
    if (len == 0) return false;
    if (ranges_overlap(start, len, @intFromPtr(zslay_conn), @sizeOf(ZslayConn))) return true;
    return zslay_conn.rx_chunk_len != 0 and
        ranges_overlap(start, len, zslay_conn.rx_chunk_start, zslay_conn.rx_chunk_len);
}

fn range_overlaps_tx_ring(zslay_conn: *const ZslayConn, start: usize, len: usize) bool {
    if (len == 0) return false;
    const tx_buffer = zslay_conn.conn.tx_queue.buffer;
    if (tx_buffer.len == 0) return false;

    const tx_len = std.math.mul(usize, tx_buffer.len, @sizeOf(event.FrameNode)) catch return true;
    return ranges_overlap(start, len, @intFromPtr(tx_buffer.ptr), tx_len);
}

fn tx_node_is_queued(zslay_conn: *const ZslayConn, start: usize, len: usize) bool {
    const tx = &zslay_conn.conn.tx_queue;
    if (tx.len == 0) return false;

    var index = tx.head;
    for (0..tx.len) |_| {
        const slot_start = @intFromPtr(&tx.buffer[index]);
        if (ranges_overlap(start, len, slot_start, @sizeOf(event.FrameNode))) return true;
        index += 1;
        if (index == tx.buffer.len) index = 0;
    }
    return false;
}

fn clear_tx_chunk(zslay_conn: *ZslayConn) void {
    if (zslay_conn.tx_chunk_len != 0) @memset(zslay_conn.tx_chunk[0..zslay_conn.tx_chunk_len], 0);
    zslay_conn.tx_chunk_len = 0;
    zslay_conn.tx_chunk_start = 0;
    zslay_conn.tx_chunk_sent = 0;
}

fn clear_rx_stage(zslay_conn: *ZslayConn) void {
    zslay_conn.rx_stage_len = 0;
    zslay_conn.rx_stage_off = 0;
    zslay_conn.rx_chunk_start = 0;
    zslay_conn.rx_chunk_len = 0;
}

fn call_recv(zslay_conn: *ZslayConn, buf: [*]u8, len: usize) isize {
    callback_depth += 1;
    defer callback_depth -= 1;
    zslay_conn.callback_state = .recv;
    defer zslay_conn.callback_state = .none;
    return zslay_conn.callbacks.recv_fn(buf, len, zslay_conn.callbacks.user_data);
}

fn call_send(zslay_conn: *ZslayConn, buf: [*]const u8, len: usize) isize {
    callback_depth += 1;
    defer callback_depth -= 1;
    zslay_conn.callback_state = .send;
    defer zslay_conn.callback_state = .none;
    return zslay_conn.callbacks.send_fn(buf, len, zslay_conn.callbacks.user_data);
}

fn call_gen_mask(zslay_conn: *ZslayConn, buf: [*]u8, len: usize) c_int {
    const gen_mask_fn = zslay_conn.callbacks.gen_mask_fn orelse return -1;
    callback_depth += 1;
    defer callback_depth -= 1;
    const previous = zslay_conn.callback_state;
    zslay_conn.callback_state = .mask;
    defer zslay_conn.callback_state = previous;
    return gen_mask_fn(buf, len, zslay_conn.callbacks.user_data);
}

fn call_on_frame(
    zslay_conn: *ZslayConn,
    opcode: u8,
    fin: u8,
    payload: ?[*]const u8,
    len: usize,
    payload_offset: u64,
    frame_len: u64,
    end_of_frame: u8,
) void {
    callback_depth += 1;
    defer callback_depth -= 1;
    zslay_conn.rx_chunk_start = if (payload) |ptr| @intFromPtr(ptr) else 0;
    zslay_conn.rx_chunk_len = len;
    defer {
        zslay_conn.rx_chunk_start = 0;
        zslay_conn.rx_chunk_len = 0;
    }

    zslay_conn.callback_state = .on_frame;
    defer zslay_conn.callback_state = .none;
    zslay_conn.callbacks.on_frame_fn(
        opcode,
        fin,
        payload,
        len,
        payload_offset,
        frame_len,
        end_of_frame,
        zslay_conn.callbacks.user_data,
    );
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

fn map_frame_error(err: anyerror) c_int {
    return switch (err) {
        error.PayloadTooLarge,
        error.InvalidLength,
        error.InvalidOpcode,
        error.MaskingKeyRequired,
        error.PayloadMasked,
        error.PayloadNotMasked,
        error.BufferTooShort,
        => ResultInvalidArgument,
        error.InvalidUtf8 => ResultInvalidUtf8,
        else => ResultProtocolError,
    };
}

// Returns the size and alignment required for caller-owned connection storage
pub export fn zslay_conn_get_size() usize {
    return @sizeOf(ZslayConn);
}

pub export fn zslay_conn_get_align() usize {
    return @alignOf(ZslayConn);
}

// Returns the size and alignment required for one outgoing frame node
pub export fn zslay_frame_node_get_size() usize {
    return @sizeOf(event.FrameNode);
}

pub export fn zslay_frame_node_get_align() usize {
    return @alignOf(event.FrameNode);
}

pub export fn zslay_abi_version() u32 {
    return AbiVersion;
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
    if (callback_depth != 0) return null;
    const zslay_conn = cast_opaque(ZslayConn, mem) orelse return null;

    const recv = recv_fn orelse return null;
    const send = send_fn orelse return null;
    const on_frame = on_frame_fn orelse return null;
    const endpoint_role = parse_role(role) orelse return null;
    if (endpoint_role == .client and gen_mask_fn == null) return null;

    const conn_addr = @intFromPtr(zslay_conn);
    const tx_bytes = std.math.mul(usize, tx_node_count, @sizeOf(event.FrameNode)) catch return null;

    var tx_nodes: []event.FrameNode = &empty_tx_nodes;
    if (tx_node_count != 0) {
        const tx_mem = tx_buffer orelse return null;
        const tx_addr = @intFromPtr(tx_mem);
        if (tx_addr % @alignOf(event.FrameNode) != 0) return null;
        if (ranges_overlap(conn_addr, @sizeOf(ZslayConn), tx_addr, tx_bytes)) return null;

        const tx_nodes_ptr: [*]event.FrameNode = @ptrCast(@alignCast(tx_mem));
        tx_nodes = tx_nodes_ptr[0..tx_node_count];
    }

    const conn = event.Conn.init(tx_nodes, .{
        .role = endpoint_role,
        .max_frame_len = max_frame_len,
        .max_message_len = max_message_len,
    }) catch return null;

    zslay_conn.* = .{
        .magic = ConnMagic,
        .abi_version = AbiVersion,
        .conn = conn,
        .callbacks = .{
            .user_data = user_data,
            .recv_fn = recv,
            .send_fn = send,
            .on_frame_fn = on_frame,
            .gen_mask_fn = gen_mask_fn,
        },
    };
    return zslay_conn;
}

// Invalidates a handle and releases no caller-owned storage
pub export fn zslay_conn_deinit(conn_ptr: ?*anyopaque) c_int {
    const zslay_conn = as_conn(conn_ptr) orelse return ResultInvalidArgument;
    if (callback_depth != 0 or zslay_conn.callback_state != .none) return ResultReentrant;

    zslay_conn.conn.reset_rx();
    zslay_conn.conn.reset_tx();
    clear_tx_chunk(zslay_conn);
    clear_rx_stage(zslay_conn);
    invalidate(zslay_conn);
    return ResultOk;
}

// Performs at most one transport read and one frame callback per invocation
pub export fn zslay_conn_recv(conn_ptr: ?*anyopaque) c_int {
    const zslay_conn = as_conn(conn_ptr) orelse return ResultInvalidArgument;
    if (callback_depth != 0 or zslay_conn.callback_state != .none) return ResultReentrant;

    const conn = &zslay_conn.conn;
    var action = conn.advance_rx() catch return ResultProtocolError;
    var progressed = false;

    while (true) {
        switch (action) {
            .need_header => {
                const buf = conn.get_header_buffer();
                if (buf.len == 0) return ResultProtocolError;

                if (zslay_conn.rx_stage_off == zslay_conn.rx_stage_len) {
                    const read = call_recv(zslay_conn, &zslay_conn.rx_stage, zslay_conn.rx_stage.len);
                    if (read < 0) return ResultCallbackError;
                    if (read == 0) return if (progressed) ResultProgress else ResultOk;

                    const read_len: usize = @intCast(read);
                    if (read_len > zslay_conn.rx_stage.len) return ResultCallbackError;
                    zslay_conn.rx_stage_len = read_len;
                    zslay_conn.rx_stage_off = 0;
                }

                const staged = zslay_conn.rx_stage[zslay_conn.rx_stage_off..zslay_conn.rx_stage_len];
                const copy_len = @min(buf.len, staged.len);
                @memcpy(buf[0..copy_len], staged[0..copy_len]);
                zslay_conn.rx_stage_off += copy_len;
                conn.advance_header_read(copy_len) catch return ResultProtocolError;
                progressed = true;
                action = conn.advance_rx() catch return ResultProtocolError;
            },
            .need_payload => {
                const decoded = conn.decoded_header orelse return ResultProtocolError;
                if (conn.payload_bytes_processed > decoded.payload_len) return ResultProtocolError;
                const remaining: u64 = decoded.payload_len - conn.payload_bytes_processed;

                var chunk_buf: ChunkBuffer = undefined;
                const chunk_size: usize = @intCast(@min(chunk_buf.len, remaining));
                var chunk_len: usize = 0;

                if (zslay_conn.rx_stage_off < zslay_conn.rx_stage_len) {
                    const staged = zslay_conn.rx_stage[zslay_conn.rx_stage_off..zslay_conn.rx_stage_len];
                    chunk_len = @min(chunk_size, staged.len);
                    @memcpy(chunk_buf[0..chunk_len], staged[0..chunk_len]);
                    zslay_conn.rx_stage_off += chunk_len;
                }

                if (chunk_len < chunk_size) {
                    const read = call_recv(zslay_conn, chunk_buf[chunk_len..].ptr, chunk_size - chunk_len);
                    if (read < 0) return ResultCallbackError;
                    if (read == 0) {
                        if (chunk_len == 0) return if (progressed) ResultProgress else ResultOk;
                    } else {
                        const read_len: usize = @intCast(read);
                        if (read_len > chunk_size - chunk_len) return ResultCallbackError;
                        chunk_len += read_len;
                    }
                }

                if (chunk_len == 0) return if (progressed) ResultProgress else ResultOk;

                const payload_offset = conn.payload_bytes_processed;
                const read_len_u64: u64 = @intCast(chunk_len);
                const end_of_frame = read_len_u64 == remaining;

                if (decoded.header.mask) {
                    const key = decoded.masking_key orelse return ResultProtocolError;
                    frame.mask(chunk_buf[0..chunk_len], key, payload_offset);
                }

                call_on_frame(
                    zslay_conn,
                    @intCast(decoded.header.opcode),
                    if (decoded.header.fin) 1 else 0,
                    chunk_buf[0..chunk_len].ptr,
                    chunk_len,
                    payload_offset,
                    decoded.payload_len,
                    if (end_of_frame) 1 else 0,
                );

                conn.advance_payload_read(read_len_u64) catch return ResultProtocolError;
                if (end_of_frame) conn.complete_frame() catch return ResultProtocolError;
                return ResultProgress;
            },
            .emit_frame => {
                const decoded = conn.decoded_header orelse return ResultProtocolError;
                call_on_frame(
                    zslay_conn,
                    @intCast(decoded.header.opcode),
                    if (decoded.header.fin) 1 else 0,
                    null,
                    0,
                    0,
                    0,
                    1,
                );

                conn.complete_frame() catch return ResultProtocolError;
                return ResultProgress;
            },
            _ => return ResultProtocolError,
        }
    }
}

// Flushes queued frames with bounded work and resumable masked chunks
pub export fn zslay_conn_send(conn_ptr: ?*anyopaque) c_int {
    const zslay_conn = as_conn(conn_ptr) orelse return ResultInvalidArgument;
    if (callback_depth != 0 or zslay_conn.callback_state != .none) return ResultReentrant;

    const conn = &zslay_conn.conn;
    var callbacks: usize = 0;
    var bytes_sent: usize = 0;

    while (true) {
        const action = conn.advance_tx() orelse return ResultOk;
        if (callbacks >= MaxSendCallbacksPerCall or bytes_sent >= MaxSendBytesPerCall) {
            return if (conn.tx_pending() != 0) ResultProgress else ResultOk;
        }

        switch (action) {
            .write_header => {
                const buf = conn.get_tx_header_buffer();
                if (buf.len == 0) return ResultProtocolError;

                const sent = call_send(zslay_conn, buf.ptr, buf.len);
                if (sent < 0) return ResultCallbackError;
                if (sent == 0) return ResultOk;

                const sent_len: usize = @intCast(sent);
                if (sent_len > buf.len) return ResultCallbackError;
                conn.advance_tx_header(sent_len) catch return ResultProtocolError;
                bytes_sent += sent_len;
                callbacks += 1;
            },
            .write_payload => {
                const key = conn.get_tx_masking_key() catch return ResultProtocolError;

                if (key) |masking_key| {
                    const offset = conn.get_tx_payload_offset() catch return ResultProtocolError;
                    const chunk_matches = zslay_conn.tx_chunk_len != 0 and
                        offset >= zslay_conn.tx_chunk_start and
                        offset - zslay_conn.tx_chunk_start == zslay_conn.tx_chunk_sent;

                    if (!chunk_matches) {
                        const remaining = conn.get_tx_payload() catch return ResultProtocolError;
                        const chunk_len = @min(zslay_conn.tx_chunk.len, remaining.len);
                        if (chunk_len == 0) return ResultProtocolError;

                        @memcpy(zslay_conn.tx_chunk[0..chunk_len], remaining[0..chunk_len]);
                        frame.mask(zslay_conn.tx_chunk[0..chunk_len], masking_key, @intCast(offset));
                        zslay_conn.tx_chunk_start = offset;
                        zslay_conn.tx_chunk_len = chunk_len;
                        zslay_conn.tx_chunk_sent = 0;
                    }

                    const chunk = zslay_conn.tx_chunk[zslay_conn.tx_chunk_sent..zslay_conn.tx_chunk_len];
                    const sent = call_send(zslay_conn, chunk.ptr, chunk.len);
                    if (sent < 0) return ResultCallbackError;
                    if (sent == 0) return ResultOk;

                    const sent_len: usize = @intCast(sent);
                    if (sent_len > chunk.len) return ResultCallbackError;

                    zslay_conn.tx_chunk_sent += sent_len;
                    conn.advance_tx_payload(sent_len) catch return ResultProtocolError;
                    bytes_sent += sent_len;

                    if (zslay_conn.tx_chunk_sent == zslay_conn.tx_chunk_len) {
                        zslay_conn.tx_chunk_len = 0;
                        zslay_conn.tx_chunk_start = 0;
                        zslay_conn.tx_chunk_sent = 0;
                    }
                } else {
                    const remaining = conn.get_tx_payload() catch return ResultProtocolError;
                    const budget = MaxSendBytesPerCall - bytes_sent;
                    const chunk_len = @min(remaining.len, @min(MaxUnmaskedChunkSize, budget));
                    if (chunk_len == 0) return ResultProtocolError;

                    const sent = call_send(zslay_conn, remaining.ptr, chunk_len);
                    if (sent < 0) return ResultCallbackError;
                    if (sent == 0) return ResultOk;

                    const sent_len: usize = @intCast(sent);
                    if (sent_len > chunk_len) return ResultCallbackError;
                    conn.advance_tx_payload(sent_len) catch return ResultProtocolError;
                    bytes_sent += sent_len;
                }

                callbacks += 1;
            },
            _ => return ResultProtocolError,
        }
    }
}

// Abandons receive state, including any active fragmented message
pub export fn zslay_conn_reset(conn_ptr: ?*anyopaque) c_int {
    const zslay_conn = as_conn(conn_ptr) orelse return ResultInvalidArgument;
    if (callback_depth != 0 or zslay_conn.callback_state != .none) return ResultReentrant;

    zslay_conn.conn.reset_rx();
    clear_rx_stage(zslay_conn);
    return ResultOk;
}

// Drops queued transmit frames and any open transmit fragment
pub export fn zslay_conn_reset_tx(conn_ptr: ?*anyopaque) c_int {
    const zslay_conn = as_conn(conn_ptr) orelse return ResultInvalidArgument;
    if (callback_depth != 0 or zslay_conn.callback_state != .none) return ResultReentrant;

    zslay_conn.conn.reset_tx();
    clear_tx_chunk(zslay_conn);
    return ResultOk;
}

// Reports the number of frames whose borrowed payloads remain live
pub export fn zslay_conn_tx_pending(conn_ptr: ?*anyopaque, pending: ?*usize) c_int {
    const zslay_conn = as_conn(conn_ptr) orelse return ResultInvalidArgument;
    const out = pending orelse return ResultInvalidArgument;

    out.* = zslay_conn.conn.tx_pending();
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
    const zslay_conn = as_conn(conn_ptr) orelse return ResultInvalidArgument;
    if (!frame_entry_allowed(zslay_conn)) return ResultReentrant;

    const node = cast_opaque(event.FrameNode, node_ptr) orelse return ResultInvalidArgument;
    const node_start = @intFromPtr(node);
    const node_len = @sizeOf(event.FrameNode);
    if (range_overlaps_conn_or_rx(zslay_conn, node_start, node_len) or
        tx_node_is_queued(zslay_conn, node_start, node_len))
        return ResultInvalidArgument;

    if (fin > 1 or is_masked > 1) return ResultInvalidArgument;

    const op = parse_opcode(opcode) orelse return ResultInvalidArgument;
    const payload_slice: []const u8 = if (payload_len == 0)
        &.{}
    else blk: {
        const payload_ptr = payload orelse return ResultInvalidArgument;
        break :blk payload_ptr[0..payload_len];
    };

    if (payload_slice.len != 0) {
        const payload_start = @intFromPtr(payload_slice.ptr);
        if (range_overlaps_conn_or_rx(zslay_conn, payload_start, payload_slice.len) or
            range_overlaps_tx_ring(zslay_conn, payload_start, payload_slice.len) or
            ranges_overlap(payload_start, payload_slice.len, node_start, node_len))
            return ResultInvalidArgument;
    }

    const masked = is_masked == 1;
    zslay_conn.conn.validate_outgoing_frame(fin == 1, op, @intCast(payload_slice.len), masked) catch |err| {
        return map_frame_error(err);
    };

    if (op == .close) {
        frame.validate_close_payload(payload_slice) catch |err| return map_frame_error(err);
    }

    var masking_key: ?types.MaskingKey = null;
    if (masked) {
        var key: types.MaskingKey = @splat(0);
        if (call_gen_mask(zslay_conn, &key, key.len) != 0) return ResultCallbackError;
        masking_key = key;
    }

    const prepared = zslay_conn.conn.prepare_frame(
        fin == 1,
        op,
        payload_slice,
        masked,
        masking_key,
    ) catch |err| return map_frame_error(err);

    node.* = prepared;
    return ResultOk;
}

// Validates and appends a pre-serialized frame node to the TX queue
pub export fn zslay_conn_queue_frame(
    conn_ptr: ?*anyopaque,
    node_ptr: ?*anyopaque,
) c_int {
    const zslay_conn = as_conn(conn_ptr) orelse return ResultInvalidArgument;
    if (!frame_entry_allowed(zslay_conn)) return ResultReentrant;

    const node = cast_opaque(event.FrameNode, node_ptr) orelse return ResultInvalidArgument;
    const node_start = @intFromPtr(node);
    const node_len = @sizeOf(event.FrameNode);
    if (range_overlaps_conn_or_rx(zslay_conn, node_start, node_len) or
        tx_node_is_queued(zslay_conn, node_start, node_len))
        return ResultInvalidArgument;

    if (node.payload.len != 0) {
        const payload_start = @intFromPtr(node.payload.ptr);
        if (payload_start == 0) return ResultInvalidArgument;
        if (range_overlaps_conn_or_rx(zslay_conn, payload_start, node.payload.len) or
            range_overlaps_tx_ring(zslay_conn, payload_start, node.payload.len) or
            ranges_overlap(payload_start, node.payload.len, node_start, node_len))
            return ResultInvalidArgument;
    }

    zslay_conn.conn.queue_frame(node.*) catch |err| return switch (err) {
        error.QueueFull => ResultQueueFull,
        else => map_frame_error(err),
    };
    return ResultOk;
}

// Validates a close frame payload code and UTF-8 reason
pub export fn zslay_validate_close_payload(payload: ?[*]const u8, payload_len: usize) c_int {
    if (payload_len == 0) return ResultOk;

    const payload_ptr = payload orelse return ResultInvalidArgument;
    frame.validate_close_payload(payload_ptr[0..payload_len]) catch |err| return switch (err) {
        error.InvalidUtf8 => ResultInvalidUtf8,
        else => ResultProtocolError,
    };
    return ResultOk;
}
