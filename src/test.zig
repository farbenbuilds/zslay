const std = @import("std");
const testing = std.testing;
const root = @import("root.zig");

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

test "Benchmark: Ping/Pong throughput" {
    var buf: [16]u8 = undefined;
    const header = root.FrameHeader{
        .opcode = @intFromEnum(root.Opcode.ping),
        .rsv3 = false,
        .rsv2 = false,
        .rsv1 = false,
        .fin = true,
        .payload_len = 0,
        .mask = true,
    };
    const key = root.MaskingKey{ 0x1, 0x2, 0x3, 0x4 };

    // Warmup
    for (0..1_000) |_| {
        const size = try root.encode_header(&buf, header, 0, key);
        _ = try root.decode_header(buf[0..size]);
    }

    const iterations: u64 = 1_000_000;
    const io = testing.io;
    const start_ns = std.Io.Timestamp.now(io, .boot).nanoseconds;

    for (0..iterations) |_| {
        const size = try root.encode_header(&buf, header, 0, key);
        const decoded = try root.decode_header(buf[0..size]);
        std.mem.doNotOptimizeAway(decoded);
    }

    const end_ns = std.Io.Timestamp.now(io, .boot).nanoseconds;

    const elapsed_ns = @as(u64, @intCast(end_ns - start_ns));
    const elapsed_s = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / elapsed_s;
    const ns_per_op = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations));

    std.debug.print(
        "\n[Benchmark] Ping/Pong (Encode+Decode): {d:.2} ops/sec ({d:.2} ns/op)\n",
        .{ ops_per_sec, ns_per_op },
    );
}
