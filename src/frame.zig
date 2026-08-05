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
