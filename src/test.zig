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

    // Statistics Calculation
    const Sorter = struct {
        fn lessThan(context: void, a: u64, b: u64) bool {
            _ = context;
            return a < b;
        }
    };
    std.mem.sort(u64, latencies, {}, Sorter.lessThan);

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
