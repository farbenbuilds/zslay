const std = @import("std");
const types = @import("types.zig");

// Unpacked frame header: physical layout plus resolved wire values
pub const DecodedHeader = struct {
    header: types.FrameHeader,
    payload_len: u64,
    header_len: usize,
    masking_key: ?types.MaskingKey,
};

// Payload byte count and physical header byte count resolved together
const DecodedLength = struct {
    payload_len: u64,
    header_len: usize,
};

// Pure: resolves payload length and header byte count from a base header
fn read_length(buf: []const u8, payload_len: u7) types.Error!DecodedLength {
    if (payload_len == 126) {
        if (buf.len < 4) return error.BufferTooShort;

        const len: u64 = std.mem.readInt(u16, buf[2..4][0..2], .big);
        if (len < 126) return error.ProtocolError;

        return .{ .payload_len = len, .header_len = 4 };
    }

    if (payload_len == 127) {
        if (buf.len < 10) return error.BufferTooShort;

        const len: u64 = std.mem.readInt(u64, buf[2..10][0..8], .big);
        if (len < 65536) return error.ProtocolError;
        if (len >> 63 != 0) return error.InvalidLength;

        return .{ .payload_len = len, .header_len = 10 };
    }

    return .{ .payload_len = payload_len, .header_len = 2 };
}

// Pure: performs in-place WebSocket XOR masking with wide-integer chunks
pub fn mask(buf: []u8, masking_key: types.MaskingKey, pos: u64) void {
    if (buf.len == 0) return;

    const key_pos: usize = @intCast(pos % masking_key.len);
    var key: types.MaskingKey = undefined;
    for (0..types.MaskingKeyLen) |i| key[i] = masking_key[(key_pos + i) % types.MaskingKeyLen];

    const word_size = @sizeOf(usize);
    var i: usize = 0;

    if (buf.len >= word_size) {
        var wide_key_buf: [word_size]u8 = undefined;
        for (&wide_key_buf, 0..) |*b, j| b.* = key[j % types.MaskingKeyLen];

        const wide_key: usize = std.mem.readInt(usize, &wide_key_buf, .native);

        while (i + word_size <= buf.len) : (i += word_size) {
            const chunk = buf[i .. i + word_size];
            const val: usize = std.mem.readInt(usize, chunk[0..word_size], .native);
            std.mem.writeInt(usize, chunk[0..word_size], val ^ wide_key, .native);
        }
    }

    while (i < buf.len) : (i += 1) buf[i] ^= key[i % types.MaskingKeyLen];
}

// Computes physical header byte length
pub fn get_serialized_size(payload_len: u64, is_masked: bool) usize {
    var size: usize = 2;

    if (payload_len >= 126 and payload_len <= 65535) {
        size += 2;
    } else if (payload_len > 65535) {
        size += 8;
    }

    if (is_masked) size += types.MaskingKeyLen;

    return size;
}

// Serializes frame properties into a raw byte buffer
pub fn encode_header(
    buf: []u8,
    header: types.FrameHeader,
    payload_len: u64,
    masking_key: ?types.MaskingKey,
) types.Error!usize {
    const op: types.Opcode = @enumFromInt(header.opcode);
    switch (op) {
        .continuation, .text, .binary, .close, .ping, .pong => {},
        _ => return error.InvalidOpcode,
    }

    if (header.rsv1 or header.rsv2 or header.rsv3) return error.ProtocolError;

    const extended_size: usize = switch (header.payload_len) {
        126 => blk: {
            if (payload_len < 126 or payload_len > 65535) return error.ProtocolError;
            break :blk 2;
        },
        127 => blk: {
            if (payload_len > types.MaxPayloadLen) return error.InvalidLength;
            if (payload_len < 65536) return error.ProtocolError;
            break :blk 8;
        },
        else => 0,
    };
    const actual_len: u64 = if (header.payload_len < 126) header.payload_len else payload_len;

    if (op.is_control() and (!header.fin or actual_len > 125)) return error.ProtocolError;
    if (header.mask and masking_key == null) return error.MaskingKeyRequired;

    const required_size = 2 + extended_size + if (header.mask) types.MaskingKeyLen else 0;

    if (buf.len < required_size) return error.BufferTooShort;

    const header_int: u16 = @bitCast(header);
    buf[0] = @intCast(header_int & 0xff);
    buf[1] = @intCast(header_int >> 8);

    var index: usize = 2;

    if (header.payload_len == 126) {
        std.mem.writeInt(u16, buf[index .. index + 2][0..2], @intCast(payload_len), .big);
        index += 2;
    } else if (header.payload_len == 127) {
        std.mem.writeInt(u64, buf[index .. index + 8][0..8], payload_len, .big);
        index += 8;
    }

    if (header.mask) {
        const key = masking_key.?;
        @memcpy(buf[index .. index + types.MaskingKeyLen], &key);
        index += types.MaskingKeyLen;
    }

    return index;
}

// Pure: parses a raw byte buffer into a DecodedHeader value
pub fn decode_header(buf: []const u8) types.Error!DecodedHeader {
    if (buf.len < 2) return error.BufferTooShort;

    const header_int = std.mem.readInt(u16, buf[0..2][0..2], .little);
    const header: types.FrameHeader = @bitCast(header_int);
    const op: types.Opcode = @enumFromInt(header.opcode);

    if (header.rsv1 or header.rsv2 or header.rsv3) return error.ProtocolError;

    switch (op) {
        .continuation, .text, .binary, .close, .ping, .pong => {},
        _ => return error.InvalidOpcode,
    }

    if (op.is_control() and (header.payload_len >= 126 or !header.fin)) return error.ProtocolError;

    const decoded_len = try read_length(buf, header.payload_len);

    if (!header.mask) {
        return .{
            .header = header,
            .payload_len = decoded_len.payload_len,
            .header_len = decoded_len.header_len,
            .masking_key = null,
        };
    }

    if (buf.len < decoded_len.header_len + types.MaskingKeyLen) return error.BufferTooShort;

    var key: types.MaskingKey = undefined;
    @memcpy(&key, buf[decoded_len.header_len .. decoded_len.header_len + types.MaskingKeyLen]);

    return .{
        .header = header,
        .payload_len = decoded_len.payload_len,
        .header_len = decoded_len.header_len + types.MaskingKeyLen,
        .masking_key = key,
    };
}
