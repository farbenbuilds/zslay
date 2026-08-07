const std = @import("std");
const types = @import("types.zig");

// Unpacked frame header properties
pub const DecoderHeader = struct {
    extended_len: u64,
    header_size: usize,
    masking_key: ?types.MaskingKey,
    header: types.FrameHeader,
};

// Performs in-place WebSocket XOR masking/unmasking (Vectorized/Wide-Integer Optimized)
pub fn mask(buf: []u8, masking_key: types.MaskingKey, pos: usize) void {
    if (buf.len == 0) return;

    // Rotate masking key based on initial pos
    var k: [4]u8 = undefined;
    k[0] = masking_key[(pos + 0) % 4];
    k[1] = masking_key[(pos + 1) % 4];
    k[2] = masking_key[(pos + 2) % 4];
    k[3] = masking_key[(pos + 3) % 4];

    var i: usize = 0;

    // Wide integer XOR optimization for bulk masking
    if (buf.len >= @sizeOf(usize)) {
        var wide_key_buf: [@sizeOf(usize)]u8 = undefined;
        for (&wide_key_buf, 0..) |*b, j| b.* = k[j % 4];
        const wide_key = std.mem.readInt(usize, &wide_key_buf, .native);

        while (i + @sizeOf(usize) <= buf.len) {
            const chunk = buf[i .. i + @sizeOf(usize)];
            const val = std.mem.readInt(usize, chunk[0..@sizeOf(usize)], .native);
            std.mem.writeInt(usize, chunk[0..@sizeOf(usize)], val ^ wide_key, .native);
            i += @sizeOf(usize);
        }
    }

    // Scalar fallback for tail
    while (i < buf.len) : (i += 1) {
        buf[i] ^= k[i % 4];
    }
}

// Computes physical header byte length
pub fn get_serialized_size(payload_len: u64, is_masked: bool) usize {
    var size: usize = 2;

    if (payload_len >= 126 and payload_len <= 65535) {
        size += 2;
    } else if (payload_len > 65535) size += 8;

    if (is_masked) size += 4;

    return size;
}

// Serializes frame properties into a raw byte buffer
pub fn encode_header(buf: []u8, header: types.FrameHeader, extended_len: u64, masking_key: ?types.MaskingKey) types.Error!usize {
    const actual_len = if (header.payload_len < 126) header.payload_len else extended_len;
    const required_size = get_serialized_size(actual_len, header.mask);

    if (buf.len < required_size) return error.BufferTooShort;

    if (header.mask and masking_key == null) return error.ProtocolError;

    const header_int: u16 = @bitCast(header);
    buf[0] = @intCast(header_int & 0xff);
    buf[1] = @intCast(header_int >> 8);

    var index: usize = 2;

    if (header.payload_len == 126) {
        std.mem.writeInt(u16, buf[index .. index + 2][0..2], @intCast(extended_len), .big);
        index += 2;
    } else if (header.payload_len == 127) {
        std.mem.writeInt(u64, buf[index .. index + 8][0..8], extended_len, .big);
        index += 8;
    }

    if (header.mask) {
        const key = masking_key.?;
        @memcpy(buf[index .. index + 4], &key);
        index += 4;
    }

    return index;
}

// Parses a raw byte buffer into a DecoderHeader struct
pub fn decode_header(buf: []const u8) types.Error!DecoderHeader {
    if (buf.len < 2) return error.BufferTooShort;

    // Explicit endianness parsing for robust cross-platform decoding
    const header_int = std.mem.readInt(u16, buf[0..2][0..2], .little);
    const header: types.FrameHeader = @bitCast(header_int);
    const op: types.Opcode = @enumFromInt(header.opcode);

    switch (op) {
        .continuation, .text, .binary, .close, .ping, .pong => {},
        _ => return error.InvalidOpcode,
    }

    if (op.is_control()) {
        if (header.payload_len >= 126 or !header.fin) return error.ProtocolError;
    }

    var index: usize = 2;
    var extended_len: u64 = 0;

    if (header.payload_len == 126) {
        if (buf.len < 4) return error.BufferTooShort;

        extended_len = std.mem.readInt(u16, buf[index .. index + 2][0..2], .big);
        index += 2;

        if (extended_len < 126) return error.ProtocolError;
    } else if (header.payload_len == 127) {
        if (buf.len < 10) return error.BufferTooShort;

        extended_len = std.mem.readInt(u64, buf[index .. index + 8][0..8], .big);
        index += 8;

        if (extended_len < 65536) return error.ProtocolError;

        if (extended_len >> 63 != 0) return error.InvalidLength;
    } else {
        extended_len = header.payload_len;
    }

    if (header.mask and buf.len < index + 4) return error.BufferTooShort;

    var masking_key: ?types.MaskingKey = null;

    if (header.mask) {
        var key: types.MaskingKey = undefined;
        @memcpy(&key, buf[index .. index + 4]);
        masking_key = key;
        index += 4;
    }

    return DecoderHeader{
        .extended_len = extended_len,
        .header_size = index,
        .masking_key = masking_key,
        .header = header,
    };
}
