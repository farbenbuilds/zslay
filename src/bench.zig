const std = @import("std");
const root = @import("root.zig");

const WarmupOperations = 10_000;
const IterationsPerSample = 100_000;
const Repetitions = 7;
const PayloadLen = 128;
const MaskBufferLen = 1024;
const Key: root.MaskingKey = .{ 1, 2, 3, 4 };

const HeaderContext = struct {
    header: root.FrameHeader,
    encoded: root.FrameHeaderBuffer,
    encoded_len: usize,
    payload_len: u16,
};

const MaskContext = struct {
    buffer: [MaskBufferLen]u8,
};

const RxContext = struct {
    conn: root.Conn,
    encoded: root.FrameHeaderBuffer,
    encoded_len: usize,
};

const Result = struct {
    name: []const u8,
    bytes_per_op: usize,
    samples_ns: [Repetitions]u64,

    fn median_ns(self: Result) u64 {
        var sorted = self.samples_ns;
        std.mem.sort(u64, &sorted, {}, std.sort.asc(u64));
        return sorted[Repetitions / 2];
    }
};

fn encode(ctx: *HeaderContext) !void {
    var encoded: root.FrameHeaderBuffer = undefined;
    const payload_len = ctx.payload_len;
    const encoded_len = try root.encode_header(&encoded, ctx.header, payload_len, Key);
    if (encoded_len != ctx.encoded_len or encoded[3] != @as(u8, @intCast(payload_len))) {
        return error.BenchmarkMismatch;
    }
    ctx.payload_len = if (payload_len == PayloadLen) PayloadLen + 1 else PayloadLen;
    std.mem.doNotOptimizeAway(encoded);
}

fn decode(ctx: *HeaderContext) !void {
    ctx.encoded[3] = @intCast(ctx.payload_len);
    const decoded = try root.decode_header(ctx.encoded[0..ctx.encoded_len]);
    if (decoded.payload_len != ctx.payload_len or decoded.header_len != ctx.encoded_len) {
        return error.BenchmarkMismatch;
    }
    ctx.payload_len = if (ctx.payload_len == PayloadLen) PayloadLen + 1 else PayloadLen;
    std.mem.doNotOptimizeAway(decoded);
}

fn mask_payload(ctx: *MaskContext) !void {
    root.mask(&ctx.buffer, Key, 0);
    std.mem.doNotOptimizeAway(&ctx.buffer);
}

fn receive_state(ctx: *RxContext) !void {
    const conn = &ctx.conn;
    if (try conn.advance_rx() != .need_header) return error.BenchmarkMismatch;
    @memcpy(conn.get_header_buffer(), ctx.encoded[0..2]);
    try conn.advance_header_read(2);
    if (try conn.advance_rx() != .need_header) return error.BenchmarkMismatch;
    @memcpy(conn.get_header_buffer(), ctx.encoded[2..ctx.encoded_len]);
    try conn.advance_header_read(ctx.encoded_len - 2);
    if (try conn.advance_rx() != .need_payload) return error.BenchmarkMismatch;
    try conn.advance_payload_read(PayloadLen);
    if (try conn.advance_rx() != .emit_frame) return error.BenchmarkMismatch;
    conn.complete_frame();
    std.mem.doNotOptimizeAway(conn);
}

fn measure(io: std.Io, ctx: anytype, comptime operation: anytype) ![Repetitions]u64 {
    for (0..WarmupOperations) |_| try operation(ctx);

    var samples: [Repetitions]u64 = undefined;
    for (&samples) |*sample| {
        const start = std.Io.Timestamp.now(io, .boot).nanoseconds;
        for (0..IterationsPerSample) |_| try operation(ctx);
        const end = std.Io.Timestamp.now(io, .boot).nanoseconds;
        if (end <= start) return error.InvalidClock;
        sample.* = @intCast(end - start);
    }
    return samples;
}

fn print_result(out: *std.Io.Writer, result: Result, last: bool) !void {
    const ns_per_op = @as(f64, @floatFromInt(result.median_ns())) / IterationsPerSample;
    const ops_per_sec = 1_000_000_000.0 / ns_per_op;
    try out.print(
        "{{\"name\":\"{s}\",\"bytes_per_op\":{d},\"ns_per_op\":{d:.3},\"ops_per_sec\":{d:.3},\"sample_durations_ns\":[",
        .{ result.name, result.bytes_per_op, ns_per_op, ops_per_sec },
    );
    for (result.samples_ns, 0..) |sample, index| {
        if (index != 0) try out.writeAll(",");
        try out.print("{d}", .{sample});
    }
    try out.writeAll("],\"samples_ns_per_op\":[");
    for (result.samples_ns, 0..) |sample, index| {
        if (index != 0) try out.writeAll(",");
        const sample_ns_per_op = @as(f64, @floatFromInt(sample)) / IterationsPerSample;
        try out.print("{d:.3}", .{sample_ns_per_op});
    }
    try out.writeAll(if (last) "]}" else "]},");
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const header: root.FrameHeader = .{
        .opcode = @intFromEnum(root.Opcode.binary),
        .rsv3 = false,
        .rsv2 = false,
        .rsv1 = false,
        .fin = true,
        .payload_len = 126,
        .mask = true,
    };
    var header_ctx = HeaderContext{
        .header = header,
        .encoded = undefined,
        .encoded_len = undefined,
        .payload_len = PayloadLen,
    };
    header_ctx.encoded_len = try root.encode_header(&header_ctx.encoded, header, PayloadLen, Key);
    if (header_ctx.encoded_len != 8) return error.BenchmarkMismatch;
    const decoded = try root.decode_header(header_ctx.encoded[0..header_ctx.encoded_len]);
    if (decoded.payload_len != PayloadLen or decoded.masking_key == null) return error.BenchmarkMismatch;

    var mask_ctx = MaskContext{ .buffer = [_]u8{0x5a} ** MaskBufferLen };
    try mask_payload(&mask_ctx);
    try mask_payload(&mask_ctx);
    for (mask_ctx.buffer) |byte| {
        if (byte != 0x5a) return error.BenchmarkMismatch;
    }

    var tx_storage: [1]root.FrameNode = undefined;
    var rx_ctx = RxContext{
        .conn = try root.Conn.init(&tx_storage, .{
            .role = .server,
            .max_frame_len = PayloadLen,
            .max_message_len = PayloadLen,
        }),
        .encoded = header_ctx.encoded,
        .encoded_len = header_ctx.encoded_len,
    };
    try receive_state(&rx_ctx);

    var results: [4]Result = undefined;
    results[0] = .{
        .name = "header_encode_masked",
        .bytes_per_op = header_ctx.encoded_len,
        .samples_ns = try measure(io, &header_ctx, encode),
    };
    results[1] = .{
        .name = "header_decode_masked",
        .bytes_per_op = header_ctx.encoded_len,
        .samples_ns = try measure(io, &header_ctx, decode),
    };
    results[2] = .{
        .name = "payload_mask_1024b",
        .bytes_per_op = MaskBufferLen,
        .samples_ns = try measure(io, &mask_ctx, mask_payload),
    };
    for (mask_ctx.buffer) |byte| {
        if (byte != 0x5a) return error.BenchmarkMismatch;
    }
    results[3] = .{
        .name = "conn_rx_state_128b",
        .bytes_per_op = header_ctx.encoded_len + PayloadLen,
        .samples_ns = try measure(io, &rx_ctx, receive_state),
    };
    if (rx_ctx.conn.rx_state != .read_base_header or rx_ctx.conn.header_bytes_read != 0) {
        return error.BenchmarkMismatch;
    }

    var out_buf: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(io, &out_buf);
    const out = &stdout.interface;
    try out.print(
        "{{\"schema_version\":1,\"benchmark\":\"zslay-core\",\"warmup_operations\":{d},\"iterations_per_sample\":{d},\"repetitions\":{d},\"cases\":[",
        .{ WarmupOperations, IterationsPerSample, Repetitions },
    );
    for (results, 0..) |result, index| try print_result(out, result, index == results.len - 1);
    try out.writeAll("]}\n");
    try out.flush();
}
