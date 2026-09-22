const std = @import("std");
const root = @import("root.zig");

const NumSessions = 10_000;
const IterationsPerSession = 100;
const TotalOps = NumSessions * IterationsPerSession;
const MaxSamples = 1024;

// Reports encode/decode throughput and sampled latency percentiles
pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var sessions: [NumSessions]root.FrameHeader = undefined;
    for (&sessions) |*session| {
        session.* = .{
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
    var buf: [root.MaxFrameHeaderLen]u8 = undefined;

    for (0..1_000) |_| {
        const size = try root.encode_header(&buf, sessions[0], 0, key);
        _ = try root.decode_header(buf[0..size]);
    }

    var latencies: [MaxSamples]u64 = undefined;
    var sample_count: usize = 0;
    const sample_stride = @max(1, TotalOps / MaxSamples);

    const start = std.Io.Timestamp.now(io, .boot).nanoseconds;
    var op_index: usize = 0;

    for (0..IterationsPerSession) |_| {
        for (&sessions) |session| {
            const op_start = std.Io.Timestamp.now(io, .boot).nanoseconds;

            const size = try root.encode_header(&buf, session, 0, key);
            const decoded = try root.decode_header(buf[0..size]);
            std.mem.doNotOptimizeAway(decoded);

            const op_end = std.Io.Timestamp.now(io, .boot).nanoseconds;

            if (op_index % sample_stride == 0 and sample_count < MaxSamples) {
                latencies[sample_count] = @intCast(op_end - op_start);
                sample_count += 1;
            }

            op_index += 1;
        }
    }

    const end = std.Io.Timestamp.now(io, .boot).nanoseconds;
    const elapsed_ns: u64 = @intCast(end - start);
    const elapsed_s = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;
    const ops_per_sec = @as(f64, @floatFromInt(TotalOps)) / elapsed_s;

    if (sample_count == 0) return;

    std.mem.sort(u64, latencies[0..sample_count], {}, std.sort.asc(u64));

    const min_lat = latencies[0];
    const max_lat = latencies[sample_count - 1];
    const med_lat = latencies[sample_count / 2];

    var sum_lat: u64 = 0;
    for (latencies[0..sample_count]) |lat| sum_lat += lat;
    const avg_lat = @as(f64, @floatFromInt(sum_lat)) / @as(f64, @floatFromInt(sample_count));

    var out_buf: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(io, &out_buf);
    const out = &stdout.interface;

    try out.print(
        \\
        \\====================================================
        \\[Benchmark] Multi-Session Ping/Pong
        \\====================================================
        \\Active WS Sessions : {d}
        \\Total Operations   : {d}
        \\Throughput         : {d:.2} ops/sec
        \\
        \\Latency / Delay (nanoseconds per frame, sampled)
        \\  Min    : {d} ns
        \\  Max    : {d} ns
        \\  Median : {d} ns
        \\  Avg    : {d:.2} ns
        \\====================================================
        \\
    , .{
        NumSessions,
        TotalOps,
        ops_per_sec,
        min_lat,
        max_lat,
        med_lat,
        avg_lat,
    });
    try out.flush();
}
