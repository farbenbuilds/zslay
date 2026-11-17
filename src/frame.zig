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

pub fn length_marker(payload_len: u64) u7 {
    if (payload_len < types.ExtendedLength16Threshold) return @intCast(payload_len);
    if (payload_len < types.ExtendedLength64Threshold) return types.ExtendedLength16Marker;
    return types.ExtendedLength64Marker;
}

fn extended_length_size(marker: u7) usize {
    return switch (marker) {
        types.ExtendedLength16Marker => types.ExtendedLength16Len,
        types.ExtendedLength64Marker => types.ExtendedLength64Len,
        else => 0,
    };
}

fn read_length(buf: []const u8, payload_len: u7) types.Error!DecodedLength {
    const header_len = types.BaseHeaderLen + extended_length_size(payload_len);

    if (payload_len == types.ExtendedLength16Marker) {
        if (buf.len < header_len) return error.BufferTooShort;

        const len: u64 = std.mem.readInt(
            u16,
            buf[types.BaseHeaderLen..header_len][0..types.ExtendedLength16Len],
            .big,
        );
        if (len < types.ExtendedLength16Threshold) return error.ProtocolError;

        return .{ .payload_len = len, .header_len = header_len };
    }

    if (payload_len == types.ExtendedLength64Marker) {
        if (buf.len < header_len) return error.BufferTooShort;

        const len: u64 = std.mem.readInt(
            u64,
            buf[types.BaseHeaderLen..header_len][0..types.ExtendedLength64Len],
            .big,
        );
        if (len < types.ExtendedLength64Threshold) return error.ProtocolError;
        if (len >> 63 != 0) return error.InvalidLength;

        return .{ .payload_len = len, .header_len = header_len };
    }

    return .{ .payload_len = payload_len, .header_len = header_len };
}

pub fn header_bytes_needed(base_len_byte: u8) usize {
    const len_marker: u7 = @intCast(base_len_byte & 0x7f);
    var needed = types.BaseHeaderLen + extended_length_size(len_marker);

    if ((base_len_byte & 0x80) != 0) needed += types.MaskingKeyLen;

    return needed;
}

pub fn mask(buf: []u8, masking_key: types.MaskingKey, pos: u64) void {
    if (buf.len == 0) return;

    const key_pos: usize = @intCast(pos % @as(u64, types.MaskingKeyLen));
    var key: types.MaskingKey = undefined;
    for (0..types.MaskingKeyLen) |i| key[i] = masking_key[(key_pos + i) % types.MaskingKeyLen];

    // The wide word must be a multiple of the four-byte masking key
    const Word = if (@bitSizeOf(usize) >= 64) u64 else u32;
    const word_size = @sizeOf(Word);
    comptime {
        std.debug.assert(types.MaskingKeyLen > 0);
        std.debug.assert(word_size % types.MaskingKeyLen == 0);
    }

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

pub fn get_serialized_size(payload_len: u64, is_masked: bool) types.Error!usize {
    if (payload_len > types.MaxPayloadLen) return error.InvalidLength;

    var size = types.BaseHeaderLen + extended_length_size(length_marker(payload_len));
    if (is_masked) size += types.MaskingKeyLen;

    return size;
}

pub fn encode_header(
    buf: []u8,
    header: types.FrameHeader,
    payload_len: u64,
    masking_key: ?types.MaskingKey,
) types.Error!usize {
    const op = types.Opcode.from_wire(header.opcode) orelse return error.InvalidOpcode;

    if (header.rsv1) return error.ProtocolError;
    if (header.rsv2) return error.ProtocolError;
    if (header.rsv3) return error.ProtocolError;
    if (payload_len > types.MaxPayloadLen) return error.InvalidLength;

    if (op.is_control()) {
        if (!header.fin) return error.ProtocolError;
        if (payload_len > types.ControlPayloadMax) return error.ProtocolError;
    }

    if (header.mask) {
        if (masking_key == null) return error.MaskingKeyRequired;
    } else {
        if (masking_key != null) return error.ProtocolError;
    }

    const marker = length_marker(payload_len);
    if (header.payload_len != marker) return error.ProtocolError;

    const required_size = types.BaseHeaderLen + extended_length_size(marker) +
        if (header.mask) types.MaskingKeyLen else 0;

    if (buf.len < required_size) return error.BufferTooShort;

    const header_int: u16 = @bitCast(header);
    buf[0] = @intCast(header_int & 0xff);
    buf[1] = @intCast(header_int >> 8);

    var index: usize = types.BaseHeaderLen;

    if (marker == types.ExtendedLength16Marker) {
        std.mem.writeInt(
            u16,
            buf[index .. index + types.ExtendedLength16Len][0..types.ExtendedLength16Len],
            @intCast(payload_len),
            .big,
        );
        index += types.ExtendedLength16Len;
    } else if (marker == types.ExtendedLength64Marker) {
        std.mem.writeInt(
            u64,
            buf[index .. index + types.ExtendedLength64Len][0..types.ExtendedLength64Len],
            payload_len,
            .big,
        );
        index += types.ExtendedLength64Len;
    }

    if (header.mask) {
        const key = masking_key.?;
        @memcpy(buf[index .. index + types.MaskingKeyLen], &key);
        index += types.MaskingKeyLen;
    }

    return index;
}

pub fn decode_header(buf: []const u8) types.Error!DecodedHeader {
    if (buf.len < types.BaseHeaderLen) return error.BufferTooShort;

    const header_int = std.mem.readInt(u16, buf[0..types.BaseHeaderLen][0..types.BaseHeaderLen], .little);
    const header: types.FrameHeader = @bitCast(header_int);

    if (header.rsv1) return error.ProtocolError;
    if (header.rsv2) return error.ProtocolError;
    if (header.rsv3) return error.ProtocolError;

    const op = types.Opcode.from_wire(header.opcode) orelse return error.InvalidOpcode;

    if (op.is_control()) {
        if (!header.fin) return error.ProtocolError;
        if (header.payload_len >= types.ExtendedLength16Marker) return error.ProtocolError;
    }

    const decoded_len = try read_length(buf, header.payload_len);
    if (op == .close) {
        if (decoded_len.payload_len == 1) return error.ProtocolError;
    }

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

pub fn validate_close_payload(payload: []const u8) types.Error!void {
    if (payload.len > types.ControlPayloadMax) return error.ProtocolError;
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
