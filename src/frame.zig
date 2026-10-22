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

// Pure: derives the number of header bytes from the second base header byte
pub fn header_bytes_needed(base_len_byte: u8) usize {
    const len_marker = base_len_byte & 0x7f;

    var needed: usize = 2;
    if (len_marker == 126) {
        needed += 2;
    } else if (len_marker == 127) {
        needed += 8;
    }

    if ((base_len_byte & 0x80) != 0) needed += types.MaskingKeyLen;

    return needed;
}

// Pure: performs in-place WebSocket XOR masking with wide-integer chunks
pub fn mask(buf: []u8, masking_key: types.MaskingKey, pos: u64) void {
    if (buf.len == 0) return;

    const key_pos: usize = @intCast(pos % @as(u64, types.MaskingKeyLen));
    var key: types.MaskingKey = undefined;
    for (0..types.MaskingKeyLen) |i| key[i] = masking_key[(key_pos + i) % types.MaskingKeyLen];

    // The wide word must be a multiple of the four-byte masking key
    const Word = if (@bitSizeOf(usize) >= 64) u64 else u32;
    const word_size = @sizeOf(Word);
    var i: usize = 0;

    if (buf.len >= word_size) {
        var wide_key_buf: [word_size]u8 = undefined;
        for (&wide_key_buf, 0..) |*byte, j| byte.* = key[j % types.MaskingKeyLen];
        const wide_key = std.mem.readInt(Word, &wide_key_buf, .native);

        while (buf.len - i >= word_size) : (i += word_size) {
            const chunk = buf[i .. i + word_size];
            const val = std.mem.readInt(Word, chunk[0..word_size], .native);
            std.mem.writeInt(Word, chunk[0..word_size], val ^ wide_key, .native);
        }
    }

    while (i < buf.len) : (i += 1) buf[i] ^= key[i % types.MaskingKeyLen];
}

// Pure: computes the physical header byte count or rejects an unencodable length
pub fn get_serialized_size(payload_len: u64, is_masked: bool) types.Error!usize {
    if (payload_len > types.MaxPayloadLen) return error.InvalidLength;

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
    const op: types.Opcode = @fromBackingInt(header.opcode);
    switch (op) {
        .continuation, .text, .binary, .close, .ping, .pong => {},
        _ => return error.InvalidOpcode,
    }

    if (header.rsv1 or header.rsv2 or header.rsv3) return error.ProtocolError;
    if (payload_len > types.MaxPayloadLen) return error.InvalidLength;

    const marker: u7 = if (payload_len < 126)
        @intCast(payload_len)
    else if (payload_len <= 65535)
        126
    else
        127;

    if (header.payload_len != marker) return error.ProtocolError;
    if (op.is_control() and (!header.fin or payload_len > 125)) return error.ProtocolError;
    if (header.mask and masking_key == null) return error.MaskingKeyRequired;
    if (!header.mask and masking_key != null) return error.ProtocolError;

    const extended_size: usize = switch (marker) {
        126 => 2,
        127 => 8,
        else => 0,
    };
    const required_size = 2 + extended_size + if (header.mask) types.MaskingKeyLen else 0;

    if (buf.len < required_size) return error.BufferTooShort;

    const header_int: u16 = @bitCast(header);
    buf[0] = @intCast(header_int & 0xff);
    buf[1] = @intCast(header_int >> 8);

    var index: usize = 2;

    if (marker == 126) {
        std.mem.writeInt(u16, buf[index .. index + 2][0..2], @intCast(payload_len), .big);
        index += 2;
    } else if (marker == 127) {
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
    const op: types.Opcode = @fromBackingInt(header.opcode);

    if (header.rsv1 or header.rsv2 or header.rsv3) return error.ProtocolError;

    switch (op) {
        .continuation, .text, .binary, .close, .ping, .pong => {},
        _ => return error.InvalidOpcode,
    }

    if (op.is_control() and (header.payload_len >= 126 or !header.fin)) return error.ProtocolError;

    const decoded_len = try read_length(buf, header.payload_len);
    if (op == .close and decoded_len.payload_len == 1) return error.ProtocolError;

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

// Pure: validates a close frame payload code and UTF-8 reason
pub fn validate_close_payload(payload: []const u8) types.Error!void {
    if (payload.len > 125) return error.ProtocolError;
    if (payload.len == 0) return;
    if (payload.len == 1) return error.ProtocolError;

    const code: u16 = std.mem.readInt(u16, payload[0..2][0..2], .big);
    if (!is_valid_close_code(code)) return error.ProtocolError;
    if (!std.unicode.utf8ValidateSlice(payload[2..])) return error.InvalidUtf8;
}

// Close codes permitted on the wire by RFC 6455 and IANA registrations
pub fn is_valid_close_code(code: u16) bool {
    return (code >= 1000 and code <= 1003) or (code >= 1007 and code <= 1014) or (code >= 3000 and code <= 4999);
}
