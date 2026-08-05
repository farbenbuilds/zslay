const std = @import("std");
const types = @import("types.zig");

// DecoderHeader - unpacked frame header properties
// contains both standard fields and extended parsing info
pub const DecoderHeader = struct {
    header: types.FrameHeader,
    extended_len: u64,
    masking_key: ?types.MaskingKey,
    header_size: usize,
};

// mask - performs in-place WebSocket XOR masking/unmasking
// uses a rolling index modulo 4 to apply the key
pub fn mask(buf: []u8, masking_key: types.MaskingKey, pos: usize) void {
    for (buf, 0..) |*b, i| {
        b.* ^= masking_key[(pos + i) % 4];
    }
}

// get_serialized_size - computes physical header byte length
// derived strictly from payload length and masking flags
pub fn get_serialized_size(payload_len: u64, is_masked: bool) usize {
    var size: usize = 2;

    if (payload_len >= 126 and payload_len <= 65535) {
        size += 2;
    } else if (payload_len > 65535) {
        size += 8;
    }

    if (is_masked) {
        size += 4;
    }

    return size;
}

// encode_header - serializes frame properties into a raw byte buffer
// returns the exact number of bytes written to the buffer
pub fn encode_header(buf: []u8, header: types.FrameHeader, extended_len: u64, masking_key: ?types.MaskingKey) types.Error!usize {
    const actual_len = if (header.payload_len < 126) header.payload_len else extended_len;
    const required_size = get_serialized_size(actual_len, header.mask);

    if (buf.len < required_size) {
        return error.BufferTooShort;
    }

    var b0: u8 = header.payload_len;

    if (header.rsv3) b0 |= 0x10;
    if (header.rsv2) b0 |= 0x20;
    if (header.rsv1) b0 |= 0x40;
    if (header.fin) b0 |= 0x80;

    var b1: u8 = header.payload_len;

    if (header.mask) b1 |= 0x80;

    buf = b0;
    buf[1] = b1;

    var index: usize = 2;

    if (header.payload_len == 126) {
        buf[index] = @intCast((extended_len >> 8) & 0xff);
        buf[index + 1] = @intCast(extended_len & 0xff);

        index += 2;
    } else if (header.payload_len == 127) {
        var i: usize = 0;

        while (i < 8) : (i += 1) {
            buf[index + 1] = @intCast((extended_len >> @intCast((7 - i) * 8)) & 0xff);
        }

        index += 8;
    }

    if (header.mask) {
        if (masking_key) |key| {
            @memcpy(buf[index .. index + 4], &key);

            index += 4;
        } else {
            return error.ProtocolError;
        }
    }

    return index;
}

// decode_header - parses a raw byte buffer into a DecodedHeader struct
// ensures absolute bounds safety and validates protocol invariants
pub fn decode_header(buf: []const u8) types.Error!DecoderHeader {
    if (buf.len < 2) {
        return error.BufferTooShort;
    }

    const b0 = buf;
    const b1 = buf[1];

    const header = types.FrameHeader{
        .payload_len = @intCast(b1 & 0x7f),
        .mask = (b1 & 0x80) != 0,
        .opcode = @intCast(b0 & 0x0f),
        .rsv3 = (b0 & 0x10) != 0,
        .rsv2 = (b0 & 0x20) != 0,
        .rsv1 = (b0 & 0x40) != 0,
        .fin = (b0 & 0x80) != 0,
    };

    const op: types.Opcode = @enumFromInt(header.opcode);

    switch (op) {
        .continuation, .text, .binary, .close, .ping, .pong => {},
        _ => return error.InvalidOpcode,
    }

    if (op.is_control()) {
        if (header.payload_len >= 126) {
            return error.ProtocolError;
        }

        if (!header.fin) {
            return error.ProtocolError;
        }
    }

    var index: usize = 2;
    var extended_len: u64 = 0;

    if (header.payload_len == 126) {
        if (buf.len < 4) {
            return error.BufferTooShort;
        }

        extended_len = (@as(u64, buf[index]) << 8) | buf[index + 1];
        index += 2;

        if (extended_len < 126) {
            return error.ProtocolError;
        }
    } else if (header.payload_len == 127) {
        if (buf.len < 10) {
            return error.BufferTooShort;
        }

        extended_len = 0;
        var i: usize = 0;

        while (i < 8) : (i += 1) {
            extended_len = (extended_len << 8) | buf[index + i];
        }

        index += 8;

        if (extended_len < 65536) {
            return error.ProtocolError;
        }

        if ((extended_len & (@as(u64, 1) << 63)) != 0) {
            return error.InvalidLength;
        }
    } else {
        extended_len = header.payload_len;
    }

    var masking_key: ?types.MaskingKey = null;

    if (header.mask) {
        if (buf.len < index + 4) {
            return error.BufferTooShort;
        }

        var key: types.MaskingKey = undefined;

        @memcpy(&key, buf[index .. index + 4]);

        masking_key = key;

        index += 4;
    }

    return DecoderHeader{
        .header = header,
        .extended_len = extended_len,
        .masking_key = masking_key,
        .header_size = index,
    };
}
