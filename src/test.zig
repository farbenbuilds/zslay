const std = @import("std");
const testing = std.testing;
const root = @import("root.zig");
const c_api = @import("c_api.zig");

fn init_conn(
    tx_buffer: []root.Conn.FrameNode,
    role: root.EndpointRole,
    max_frame_len: u64,
    max_message_len: u64,
) root.Error!root.Conn {
    return root.Conn.init(tx_buffer, .{
        .role = role,
        .max_frame_len = max_frame_len,
        .max_message_len = max_message_len,
    });
}

fn load_header(conn: *root.Conn, raw: []const u8) root.Error!root.RxAction {
    var offset: usize = 0;

    while (offset < raw.len) {
        const dst = conn.get_header_buffer();
        const read_len = @min(dst.len, raw.len - offset);
        @memcpy(dst[0..read_len], raw[offset .. offset + read_len]);
        try conn.advance_header_read(read_len);
        offset += read_len;

        const action = try conn.advance_rx();
        if (action != .need_header) return action;
    }

    return conn.advance_rx();
}

const CApiHarness = struct {
    input: []const u8 = &.{},
    input_offset: usize = 0,
    over_report: bool = false,
    over_report_send: bool = false,

    chunk_count: usize = 0,
    chunk_lens: [4]usize = [_]usize{0} ** 4,
    chunk_offsets: [4]u64 = [_]u64{0} ** 4,
    chunk_totals: [4]u64 = [_]u64{0} ** 4,
    chunk_ends: [4]u8 = [_]u8{0} ** 4,
    received: [5000]u8 = [_]u8{0} ** 5000,
    received_len: usize = 0,

    mask_result: c_int = 0,
    mask_key: root.MaskingKey = .{ 1, 2, 3, 4 },

    fn from_user_data(user_data: ?*anyopaque) *CApiHarness {
        return @ptrCast(@alignCast(user_data.?));
    }

    fn recv(buf: [*]u8, len: usize, user_data: ?*anyopaque) callconv(.c) isize {
        const self = from_user_data(user_data);
        if (self.over_report) return @intCast(len + 1);

        const available = self.input.len - self.input_offset;
        const read_len = @min(len, available);
        if (read_len == 0) return 0;

        @memcpy(buf[0..read_len], self.input[self.input_offset .. self.input_offset + read_len]);
        self.input_offset += read_len;
        return @intCast(read_len);
    }

    fn send(_: [*]const u8, len: usize, user_data: ?*anyopaque) callconv(.c) isize {
        const self = from_user_data(user_data);
        if (self.over_report_send) return @intCast(len + 1);
        return @intCast(len);
    }

    fn on_frame(
        _: u8,
        _: u8,
        payload: ?[*]const u8,
        len: usize,
        payload_offset: u64,
        frame_len: u64,
        end_of_frame: u8,
        user_data: ?*anyopaque,
    ) callconv(.c) void {
        const self = from_user_data(user_data);
        const index = self.chunk_count;
        self.chunk_lens[index] = len;
        self.chunk_offsets[index] = payload_offset;
        self.chunk_totals[index] = frame_len;
        self.chunk_ends[index] = end_of_frame;
        self.chunk_count += 1;

        if (len != 0) {
            @memcpy(self.received[self.received_len .. self.received_len + len], payload.?[0..len]);
            self.received_len += len;
        }
    }

    fn gen_mask(buf: [*]u8, len: usize, user_data: ?*anyopaque) callconv(.c) c_int {
        const self = from_user_data(user_data);
        if (self.mask_result != 0) return self.mask_result;
        if (len != self.mask_key.len) return -1;

        @memcpy(buf[0..len], &self.mask_key);
        return 0;
    }
};

comptime {
    // Force semantic analysis of all module declarations
    testing.refAllDecls(root);
}

test "DOD: Memory Layouts and Sizes" {
    // DOD rule: flatten data structures, use packed struct for exact layout
    try testing.expectEqual(2, @sizeOf(root.FrameHeader));
    try testing.expectEqual(4, @sizeOf(root.MaskingKey));
    try testing.expectEqual(16, @bitSizeOf(root.FrameHeader));
}

test "Queue: zero-allocation ring buffer" {
    // DOD rule: Zero-Allocation runtime, pre-allocated static contexts
    var backing_buffer: [4]u32 = undefined;
    var q = root.Queue(u32).init(&backing_buffer);

    try testing.expectEqual(0, q.len);

    try q.push_back(10);
    try q.push_back(20);
    try q.push_back(30);
    try q.push_back(40);

    try testing.expectError(error.QueueFull, q.push_back(50));

    try testing.expectEqual(@as(u32, 10), q.pop_front().?);
    try testing.expectEqual(@as(u32, 20), q.pop_front().?);

    try q.push_back(50);
    try q.push_back(60);

    try testing.expectError(error.QueueFull, q.push_back(70));

    try testing.expectEqual(@as(u32, 30), q.pop_front().?);
    try testing.expectEqual(@as(u32, 40), q.pop_front().?);
    try testing.expectEqual(@as(u32, 50), q.pop_front().?);
    try testing.expectEqual(@as(u32, 60), q.pop_front().?);
    try testing.expectEqual(null, q.pop_front());
}

test "Queue: push_front and pop_back" {
    var backing_buffer: [2]u32 = undefined;
    var q = root.Queue(u32).init(&backing_buffer);

    try q.push_front(1);
    try q.push_back(2);
    try testing.expectError(error.QueueFull, q.push_front(3));

    try testing.expectEqual(@as(u32, 2), q.pop_back().?);
    try testing.expectEqual(@as(u32, 1), q.pop_front().?);
    try testing.expectEqual(null, q.pop_back());
}

test "Frame: decode simple unmasked text frame" {
    // 0x81 (FIN + TEXT) 0x05 (length 5) -> "Hello"
    const raw = [_]u8{ 0x81, 0x05 };
    const decoded = try root.decode_header(&raw);

    try testing.expectEqual(5, decoded.extended_len);
    try testing.expectEqual(2, decoded.header_size);
    try testing.expectEqual(null, decoded.masking_key);

    try testing.expect(decoded.header.fin);
    try testing.expectEqual(@intFromEnum(root.Opcode.text), decoded.header.opcode);
    try testing.expect(!decoded.header.mask);
}

test "Frame: encode and decode masked binary frame with extended length" {
    var buf: [16]u8 = undefined;

    const header = root.FrameHeader{
        .opcode = @intFromEnum(root.Opcode.binary),
        .rsv3 = false,
        .rsv2 = false,
        .rsv1 = false,
        .fin = true,
        .payload_len = 126,
        .mask = true,
    };

    const key = root.MaskingKey{ 0x1, 0x2, 0x3, 0x4 };

    const size = try root.encode_header(&buf, header, 200, key);
    try testing.expectEqual(8, size); // 2 base + 2 extended len + 4 mask

    const decoded = try root.decode_header(buf[0..size]);
    try testing.expectEqual(200, decoded.extended_len);
    try testing.expectEqual(8, decoded.header_size);
    try testing.expectEqual(key, decoded.masking_key.?);
    try testing.expect(decoded.header.fin);
    try testing.expect(decoded.header.mask);
    try testing.expectEqual(@intFromEnum(root.Opcode.binary), decoded.header.opcode);
}

test "Frame: XOR masking (vectorized and scalar paths)" {
    var buf = [_]u8{ 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99 };
    const key = root.MaskingKey{ 0xA, 0xB, 0xC, 0xD };

    // Mask
    root.mask(&buf, key, 0);
    // Ensure modified
    try testing.expect(buf[0] != 0x11);

    // Unmask
    root.mask(&buf, key, 0);

    // Ensure identical
    try testing.expectEqualSlices(u8, &[_]u8{ 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99 }, &buf);
}

test "Frame: masking respects key rotation offset" {
    var buf = [_]u8{ 0x00, 0x00, 0x00, 0x00, 0x00 };
    const key = root.MaskingKey{ 0x1, 0x2, 0x3, 0x4 };

    root.mask(&buf, key, 3);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x4, 0x1, 0x2, 0x3, 0x4 }, &buf);
}

test "Frame: serialized size boundaries" {
    try testing.expectEqual(2, root.get_serialized_size(0, false));
    try testing.expectEqual(6, root.get_serialized_size(125, true));
    try testing.expectEqual(4, root.get_serialized_size(126, false));
    try testing.expectEqual(8, root.get_serialized_size(126, true));
    try testing.expectEqual(10, root.get_serialized_size(65536, false));
    try testing.expectEqual(14, root.get_serialized_size(65536, true));
}

test "Connection: stream extended headers before payload" {
    var nodes: [1]root.Conn.FrameNode = undefined;
    var conn = try init_conn(&nodes, .client, 1024, 1024);

    try testing.expectEqual(root.RxAction.need_header, try load_header(&conn, &[_]u8{ 0x81, 0x7e }));
    try testing.expectEqual(root.RxAction.need_payload, try load_header(&conn, &[_]u8{ 0x00, 0x80 }));
}

test "Frame: reject inconsistent extended length markers before writing" {
    const base = root.FrameHeader{
        .opcode = @intFromEnum(root.Opcode.binary),
        .rsv3 = false,
        .rsv2 = false,
        .rsv1 = false,
        .fin = true,
        .payload_len = 126,
        .mask = false,
    };

    var short_buf = [_]u8{0xa5} ** 2;
    try testing.expectError(error.ProtocolError, root.encode_header(&short_buf, base, 125, null));
    try testing.expectEqualSlices(u8, &[_]u8{ 0xa5, 0xa5 }, &short_buf);

    var marker_127 = base;
    marker_127.payload_len = 127;
    try testing.expectError(error.ProtocolError, root.encode_header(&short_buf, marker_127, 65535, null));
    try testing.expectEqualSlices(u8, &[_]u8{ 0xa5, 0xa5 }, &short_buf);
    try testing.expectError(error.InvalidLength, root.encode_header(&short_buf, marker_127, 1 << 63, null));

    var exact_126: [4]u8 = undefined;
    try testing.expectEqual(4, try root.encode_header(&exact_126, base, 126, null));
    try testing.expectEqual(4, try root.encode_header(&exact_126, base, 65535, null));

    var exact_127: [10]u8 = undefined;
    try testing.expectEqual(10, try root.encode_header(&exact_127, marker_127, 65536, null));
    try testing.expectEqual(10, try root.encode_header(&exact_127, marker_127, root.MaxPayloadLen, null));
}

test "Frame: decode canonical payload length boundaries" {
    const short = try root.decode_header(&[_]u8{ 0x82, 125 });
    try testing.expectEqual(125, short.extended_len);

    const marker_126_min = try root.decode_header(&[_]u8{ 0x82, 126, 0, 126 });
    try testing.expectEqual(126, marker_126_min.extended_len);
    const marker_126_max = try root.decode_header(&[_]u8{ 0x82, 126, 0xff, 0xff });
    try testing.expectEqual(65535, marker_126_max.extended_len);

    const marker_127_min = try root.decode_header(&[_]u8{
        0x82, 127, 0, 0, 0, 0, 0, 1, 0, 0,
    });
    try testing.expectEqual(65536, marker_127_min.extended_len);
    const marker_127_max = try root.decode_header(&[_]u8{
        0x82, 127, 0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
    });
    try testing.expectEqual(root.MaxPayloadLen, marker_127_max.extended_len);

    try testing.expectError(
        error.ProtocolError,
        root.decode_header(&[_]u8{ 0x82, 126, 0, 125 }),
    );
    try testing.expectError(
        error.ProtocolError,
        root.decode_header(&[_]u8{ 0x82, 127, 0, 0, 0, 0, 0, 0, 0xff, 0xff }),
    );
    try testing.expectError(
        error.InvalidLength,
        root.decode_header(&[_]u8{ 0x82, 127, 0x80, 0, 0, 0, 0, 0, 0, 0 }),
    );
}

test "Frame: reject reserved bits without negotiated extensions" {
    try testing.expectError(error.ProtocolError, root.decode_header(&[_]u8{ 0xc1, 0x00 }));
    try testing.expectError(error.ProtocolError, root.decode_header(&[_]u8{ 0xa1, 0x00 }));
    try testing.expectError(error.ProtocolError, root.decode_header(&[_]u8{ 0x91, 0x00 }));
}

test "Connection: enforce endpoint masking direction" {
    var server_nodes: [1]root.Conn.FrameNode = undefined;
    var server = try init_conn(&server_nodes, .server, 1024, 1024);
    try testing.expectError(error.PayloadNotMasked, load_header(&server, &[_]u8{ 0x81, 0x00 }));

    server = try init_conn(&server_nodes, .server, 1024, 1024);
    const masked_empty = [_]u8{ 0x81, 0x80, 1, 2, 3, 4 };
    try testing.expectEqual(root.RxAction.emit_frame, try load_header(&server, &masked_empty));
    server.complete_frame();

    var client_nodes: [1]root.Conn.FrameNode = undefined;
    var client = try init_conn(&client_nodes, .client, 1024, 1024);
    try testing.expectError(error.PayloadMasked, load_header(&client, &masked_empty));

    client = try init_conn(&client_nodes, .client, 1024, 1024);
    try testing.expectEqual(root.RxAction.emit_frame, try load_header(&client, &[_]u8{ 0x81, 0x00 }));
}

test "Connection: enforce frame and fragmented message limits" {
    var nodes: [1]root.Conn.FrameNode = undefined;
    var conn = try init_conn(&nodes, .client, 10, 10);

    try testing.expectError(error.PayloadTooLarge, load_header(&conn, &[_]u8{ 0x81, 11 }));

    conn = try init_conn(&nodes, .client, 10, 10);
    try testing.expectEqual(root.RxAction.need_payload, try load_header(&conn, &[_]u8{ 0x01, 6 }));
    try conn.advance_payload_read(6);
    conn.complete_frame();

    try testing.expectError(error.PayloadTooLarge, load_header(&conn, &[_]u8{ 0x80, 5 }));
}

test "Connection: validate fragmented frame ordering" {
    var nodes: [1]root.Conn.FrameNode = undefined;
    var conn = try init_conn(&nodes, .client, 1024, 1024);

    try testing.expectError(error.ProtocolError, load_header(&conn, &[_]u8{ 0x80, 0x00 }));

    conn = try init_conn(&nodes, .client, 1024, 1024);
    try testing.expectEqual(root.RxAction.emit_frame, try load_header(&conn, &[_]u8{ 0x01, 0x00 }));
    conn.complete_frame();

    try testing.expectEqual(root.RxAction.emit_frame, try load_header(&conn, &[_]u8{ 0x89, 0x00 }));
    conn.complete_frame();
    try testing.expect(conn.fragmented_opcode != null);

    var invalid_nodes: [1]root.Conn.FrameNode = undefined;
    var invalid = try init_conn(&invalid_nodes, .client, 1024, 1024);
    try testing.expectEqual(root.RxAction.emit_frame, try load_header(&invalid, &[_]u8{ 0x01, 0x00 }));
    invalid.complete_frame();
    try testing.expectError(error.ProtocolError, load_header(&invalid, &[_]u8{ 0x82, 0x00 }));

    try testing.expectEqual(root.RxAction.emit_frame, try load_header(&conn, &[_]u8{ 0x00, 0x00 }));
    conn.complete_frame();
    try testing.expect(conn.fragmented_opcode != null);

    try testing.expectEqual(root.RxAction.emit_frame, try load_header(&conn, &[_]u8{ 0x80, 0x00 }));
    conn.complete_frame();
    try testing.expectEqual(null, conn.fragmented_opcode);
}

test "Connection: fail closed for masking keys and outbound direction" {
    const payload = "hello";
    const key = root.MaskingKey{ 1, 2, 3, 4 };

    var client_nodes: [1]root.Conn.FrameNode = undefined;
    const client = try init_conn(&client_nodes, .client, 5, 5);
    try testing.expectError(
        error.MaskingKeyRequired,
        client.prepare_frame(true, .text, payload, true, null),
    );
    try testing.expectError(
        error.PayloadNotMasked,
        client.prepare_frame(true, .text, payload, false, null),
    );
    _ = try client.prepare_frame(true, .text, payload, true, key);

    var server_nodes: [1]root.Conn.FrameNode = undefined;
    const server = try init_conn(&server_nodes, .server, 5, 5);
    try testing.expectError(
        error.PayloadMasked,
        server.prepare_frame(true, .text, payload, true, key),
    );
    _ = try server.prepare_frame(true, .text, payload, false, null);
    try testing.expectError(
        error.PayloadTooLarge,
        server.prepare_frame(true, .text, "longer", false, null),
    );
}

test "Connection: empty transmit queue is safe" {
    var no_nodes: [0]root.Conn.FrameNode = .{};
    var conn = try init_conn(&no_nodes, .server, 1024, 1024);
    try testing.expectEqual(null, conn.advance_tx());
}

test "Connection: revalidate prepared nodes at the destination queue" {
    var source_nodes: [1]root.Conn.FrameNode = undefined;
    const source = try init_conn(&source_nodes, .server, 1024, 1024);
    const unmasked = try source.prepare_frame(true, .binary, "payload", false, null);

    var client_nodes: [2]root.Conn.FrameNode = undefined;
    var client = try init_conn(&client_nodes, .client, 1024, 1024);
    try testing.expectError(error.PayloadNotMasked, client.queue_frame(unmasked));

    var limited_nodes: [2]root.Conn.FrameNode = undefined;
    var limited = try init_conn(&limited_nodes, .server, 3, 3);
    try testing.expectError(error.PayloadTooLarge, limited.queue_frame(unmasked));
}

test "Connection: validate outbound fragmented frame ordering" {
    var nodes: [8]root.Conn.FrameNode = undefined;
    var conn = try init_conn(&nodes, .server, 10, 10);

    const orphan = try conn.prepare_frame(true, .continuation, "", false, null);
    try testing.expectError(error.ProtocolError, conn.queue_frame(orphan));

    const start = try conn.prepare_frame(false, .text, "123456", false, null);
    try conn.queue_frame(start);
    try testing.expect(conn.tx_fragmented_opcode != null);

    const ping = try conn.prepare_frame(true, .ping, "", false, null);
    try conn.queue_frame(ping);
    try testing.expect(conn.tx_fragmented_opcode != null);

    const overlapping = try conn.prepare_frame(true, .binary, "", false, null);
    try testing.expectError(error.ProtocolError, conn.queue_frame(overlapping));

    const oversized = try conn.prepare_frame(true, .continuation, "12345", false, null);
    try testing.expectError(error.PayloadTooLarge, conn.queue_frame(oversized));

    const finish = try conn.prepare_frame(true, .continuation, "1234", false, null);
    try conn.queue_frame(finish);
    try testing.expectEqual(null, conn.tx_fragmented_opcode);

    const next = try conn.prepare_frame(true, .binary, "", false, null);
    try conn.queue_frame(next);
}

test "C API: stream chunks with explicit frame completion" {
    const payload_len = 5000;
    const key = root.MaskingKey{ 0x11, 0x22, 0x33, 0x44 };
    const header = root.FrameHeader{
        .opcode = @intFromEnum(root.Opcode.binary),
        .rsv3 = false,
        .rsv2 = false,
        .rsv1 = false,
        .fin = true,
        .payload_len = 126,
        .mask = true,
    };

    var wire: [payload_len + 8]u8 = undefined;
    const header_len = try root.encode_header(&wire, header, payload_len, key);
    for (wire[header_len..], 0..) |*byte, index| byte.* = @truncate(index);
    root.mask(wire[header_len..], key, 0);

    var harness = CApiHarness{ .input = &wire };
    var conn_mem: [1024]u8 align(64) = undefined;
    var tx_nodes: [1]root.Conn.FrameNode = undefined;

    try testing.expect(c_api.zslay_conn_get_size() <= conn_mem.len);
    try testing.expect(c_api.zslay_conn_get_align() <= 64);
    const conn_opt = c_api.zslay_conn_init(
        &conn_mem,
        &harness,
        CApiHarness.recv,
        CApiHarness.send,
        CApiHarness.on_frame,
        null,
        &tx_nodes,
        tx_nodes.len,
        @intFromEnum(root.EndpointRole.server),
        payload_len,
        payload_len,
    );
    try testing.expect(conn_opt != null);
    const conn = conn_opt.?;

    try testing.expectEqual(c_api.ResultProgress, c_api.zslay_conn_recv(conn));
    try testing.expectEqual(0, harness.chunk_count);
    try testing.expectEqual(c_api.ResultProgress, c_api.zslay_conn_recv(conn));
    try testing.expectEqual(0, harness.chunk_count);
    try testing.expectEqual(c_api.ResultProgress, c_api.zslay_conn_recv(conn));
    try testing.expectEqual(1, harness.chunk_count);
    try testing.expectEqual(c_api.ResultProgress, c_api.zslay_conn_recv(conn));

    try testing.expectEqual(2, harness.chunk_count);
    try testing.expectEqual(4096, harness.chunk_lens[0]);
    try testing.expectEqual(payload_len - 4096, harness.chunk_lens[1]);
    try testing.expectEqual(0, harness.chunk_offsets[0]);
    try testing.expectEqual(4096, harness.chunk_offsets[1]);
    try testing.expectEqual(payload_len, harness.chunk_totals[0]);
    try testing.expectEqual(payload_len, harness.chunk_totals[1]);
    try testing.expectEqual(0, harness.chunk_ends[0]);
    try testing.expectEqual(1, harness.chunk_ends[1]);
    try testing.expectEqual(payload_len, harness.received_len);

    for (harness.received[0..harness.received_len], 0..) |byte, index| {
        try testing.expectEqual(@as(u8, @truncate(index)), byte);
    }
}

test "C API: reject callback over-reporting" {
    var harness = CApiHarness{ .over_report = true };
    var conn_mem: [1024]u8 align(64) = undefined;
    var tx_nodes: [1]root.Conn.FrameNode = undefined;

    const conn_opt = c_api.zslay_conn_init(
        &conn_mem,
        &harness,
        CApiHarness.recv,
        CApiHarness.send,
        CApiHarness.on_frame,
        null,
        &tx_nodes,
        tx_nodes.len,
        @intFromEnum(root.EndpointRole.server),
        1024,
        1024,
    );
    try testing.expect(conn_opt != null);
    try testing.expectEqual(c_api.ResultCallbackError, c_api.zslay_conn_recv(conn_opt.?));
}

test "C API: bound empty frame delivery to one frame per call" {
    const wire = [_]u8{
        0x81, 0x80, 1, 2, 3, 4,
        0x81, 0x80, 5, 6, 7, 8,
    };
    var harness = CApiHarness{ .input = &wire };
    var conn_mem: [1024]u8 align(64) = undefined;
    var tx_nodes: [1]root.Conn.FrameNode = undefined;

    const conn_opt = c_api.zslay_conn_init(
        &conn_mem,
        &harness,
        CApiHarness.recv,
        CApiHarness.send,
        CApiHarness.on_frame,
        null,
        &tx_nodes,
        tx_nodes.len,
        @intFromEnum(root.EndpointRole.server),
        1024,
        1024,
    );
    try testing.expect(conn_opt != null);
    const conn = conn_opt.?;

    try testing.expectEqual(c_api.ResultProgress, c_api.zslay_conn_recv(conn));
    try testing.expectEqual(c_api.ResultProgress, c_api.zslay_conn_recv(conn));
    try testing.expectEqual(c_api.ResultProgress, c_api.zslay_conn_recv(conn));
    try testing.expectEqual(1, harness.chunk_count);
    try testing.expectEqual(6, harness.input_offset);
    try testing.expectEqual(0, harness.chunk_lens[0]);
    try testing.expectEqual(1, harness.chunk_ends[0]);

    try testing.expectEqual(c_api.ResultProgress, c_api.zslay_conn_recv(conn));
    try testing.expectEqual(1, harness.chunk_count);
    try testing.expectEqual(8, harness.input_offset);
}

test "C API: reject send callback over-reporting" {
    const payload = "x";
    var harness = CApiHarness{ .over_report_send = true };
    var conn_mem: [1024]u8 align(64) = undefined;
    var tx_nodes: [1]root.Conn.FrameNode = undefined;
    var node: root.Conn.FrameNode = undefined;

    const conn_opt = c_api.zslay_conn_init(
        &conn_mem,
        &harness,
        CApiHarness.recv,
        CApiHarness.send,
        CApiHarness.on_frame,
        null,
        &tx_nodes,
        tx_nodes.len,
        @intFromEnum(root.EndpointRole.server),
        1024,
        1024,
    );
    try testing.expect(conn_opt != null);
    const conn = conn_opt.?;

    try testing.expectEqual(
        c_api.ResultOk,
        c_api.zslay_conn_prepare_frame(conn, &node, 1, 2, payload.ptr, payload.len, 0),
    );
    try testing.expectEqual(c_api.ResultOk, c_api.zslay_conn_queue_frame(conn, &node));
    try testing.expectEqual(c_api.ResultCallbackError, c_api.zslay_conn_send(conn));
    try testing.expectEqual(0, tx_nodes[0].sent_header);
}

test "C API: require a successful client mask generator" {
    const payload = "x";
    var harness = CApiHarness{};
    var conn_mem: [1024]u8 align(64) = undefined;
    var tx_nodes: [1]root.Conn.FrameNode = undefined;
    var node = root.Conn.FrameNode{ .header_size = 123 };

    var conn_opt = c_api.zslay_conn_init(
        &conn_mem,
        &harness,
        CApiHarness.recv,
        CApiHarness.send,
        CApiHarness.on_frame,
        null,
        &tx_nodes,
        tx_nodes.len,
        @intFromEnum(root.EndpointRole.client),
        1024,
        1024,
    );
    try testing.expect(conn_opt != null);
    try testing.expectEqual(
        c_api.ResultProtocolError,
        c_api.zslay_conn_prepare_frame(conn_opt.?, &node, 1, 1, payload.ptr, payload.len, 1),
    );
    try testing.expectEqual(123, node.header_size);

    harness.mask_result = -1;
    conn_opt = c_api.zslay_conn_init(
        &conn_mem,
        &harness,
        CApiHarness.recv,
        CApiHarness.send,
        CApiHarness.on_frame,
        CApiHarness.gen_mask,
        &tx_nodes,
        tx_nodes.len,
        @intFromEnum(root.EndpointRole.client),
        1024,
        1024,
    );
    try testing.expect(conn_opt != null);
    try testing.expectEqual(
        c_api.ResultCallbackError,
        c_api.zslay_conn_prepare_frame(conn_opt.?, &node, 1, 1, payload.ptr, payload.len, 1),
    );
    try testing.expectEqual(123, node.header_size);

    harness.mask_result = 0;
    try testing.expectEqual(
        c_api.ResultOk,
        c_api.zslay_conn_prepare_frame(conn_opt.?, &node, 1, 1, payload.ptr, payload.len, 1),
    );
    try testing.expectEqualSlices(
        u8,
        &harness.mask_key,
        node.header_buf[node.header_size - harness.mask_key.len .. node.header_size],
    );
}

test "Benchmark: Multi-Session Ping/Pong Throughput & Latency" {
    const io = testing.io;

    const num_sessions = 10_000;
    const iterations_per_session = 100;
    const total_ops = num_sessions * iterations_per_session;

    // Simulate DOD-friendly session contexts (zero heap during runtime, flat arrays)
    const sessions = try testing.allocator.alloc(root.FrameHeader, num_sessions);
    defer testing.allocator.free(sessions);

    for (sessions) |*s| {
        s.* = root.FrameHeader{
            .opcode = @intFromEnum(root.Opcode.ping),
            .rsv3 = false,
            .rsv2 = false,
            .rsv1 = false,
            .fin = true,
            .payload_len = 0,
            .mask = true,
        };
    }

    const key = root.MaskingKey{ 0x1, 0x2, 0x3, 0x4 };
    var buf: [16]u8 = undefined;

    // Warmup
    for (0..1_000) |_| {
        const size = try root.encode_header(&buf, sessions[0], 0, key);
        _ = try root.decode_header(buf[0..size]);
    }

    // Benchmark tracking
    const latencies = try testing.allocator.alloc(u64, total_ops);
    defer testing.allocator.free(latencies);

    const test_start = std.Io.Timestamp.now(io, .boot).nanoseconds;

    var op_idx: usize = 0;
    for (0..iterations_per_session) |_| {
        // Bulk process across all sessions (DOD cache-locality friendly)
        for (sessions) |session| {
            const op_start = std.Io.Timestamp.now(io, .boot).nanoseconds;

            const size = try root.encode_header(&buf, session, 0, key);
            const decoded = try root.decode_header(buf[0..size]);
            std.mem.doNotOptimizeAway(decoded);

            const op_end = std.Io.Timestamp.now(io, .boot).nanoseconds;
            latencies[op_idx] = @intCast(op_end - op_start);
            op_idx += 1;
        }
    }

    const test_end = std.Io.Timestamp.now(io, .boot).nanoseconds;
    const elapsed_s = @as(f64, @floatFromInt(test_end - test_start)) / 1_000_000_000.0;
    const ops_per_sec = @as(f64, @floatFromInt(total_ops)) / elapsed_s;

    std.mem.sort(u64, latencies, {}, std.sort.asc(u64));

    const min_lat = latencies[0];
    const max_lat = latencies[latencies.len - 1];
    const med_lat = latencies[latencies.len / 2];

    var sum_lat: u64 = 0;
    for (latencies) |l| sum_lat += l;
    const avg_lat = @as(f64, @floatFromInt(sum_lat)) / @as(f64, @floatFromInt(latencies.len));

    std.debug.print(
        \\
        \\====================================================
        \\[Benchmark] Multi-Session Ping/Pong
        \\====================================================
        \\Active WS Sessions : {d}
        \\Total Operations   : {d}
        \\Throughput         : {d:.2} ops/sec
        \\
        \\Latency / Delay (nanoseconds per frame)
        \\  Min    : {d} ns
        \\  Max    : {d} ns
        \\  Median : {d} ns
        \\  Avg    : {d:.2} ns
        \\====================================================
        \\
    , .{
        num_sessions,
        total_ops,
        ops_per_sec,
        min_lat,
        max_lat,
        med_lat,
        avg_lat,
    });
}

test "Fuzz: Random garbage resilience" {
    // We only need a single context for fuzzing
    var rx_nodes: [4]root.Conn.FrameNode = undefined;
    var conn = try init_conn(&rx_nodes, .client, 1024 * 1024, 1024 * 1024);

    // Initialize RNG
    var prng = std.Random.DefaultPrng.init(0xDEADBEEF);
    const random = prng.random();

    // Run 100,000 iterations of pure random garbage injected directly into the parsing buffer
    const iterations = 100_000;

    for (0..iterations) |_| {
        // Reset state machine for the next garbage payload
        conn.reset_rx();

        // Fill header buffer with random noise
        random.bytes(&conn.header_buf);
        conn.header_bytes_read = 2; // pretend we read 2 bytes

        // Attempt to parse it. It SHOULD throw errors (like InvalidOpcode, ProtocolError, etc)
        // But it MUST NEVER panic, segfault, or OOM.
        if (conn.advance_rx()) |_| {
            // It randomly managed to parse a valid frame header by pure luck!
        } else |_| {
            // Expected: mostly ProtocolError or BufferTooShort
        }
    }
}
