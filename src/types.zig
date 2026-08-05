const std = @import("std");

// Opcode - WebSocket frame opcodes defined in RFC 6455
// explicit u4 backing type is required for ABI safety
pub const Opcode = enum(u4) {
    continuation = 0x0,
    text = 0x1,
    binary = 0x2,

    close = 0x8,
    ping = 0x9,
    pong = 0xa,
    _,

    pub inline fn is_control(self: Opcode) bool {
        return @intFromEnum(self) >= 0x8;
    }
};

// StatusCode - WebSocket connection close status codes
// backing integer prevents implicit tag size generation
pub const StatusCode = enum(u16) {
    normal_closure = 1000,
    going_away = 1001,
    protocol_error = 1002,

    unsupported_data = 1003,
    no_status_rcvd = 1005,
    abnormal_closure = 1006,

    invalid_payload = 1007,
    policy_violation = 1008,
    message_too_big = 1009,

    mandatory_ext = 1010,
    internal_server_err = 1011,
    tls_handshake = 1015,
    _,
};

// Error - pure Zig error set for WebSocket frame parsing
// bubbled up through Zig return traces for robust errot handling
pub const Error = error{
    InvalidOpcode,
    InvalidLength,
    BufferTooShort,

    ProtocolError,
    PayloadMasked,
    PayloadNotMasked,
};

// FrameHeader - contiguous 16-bit physical layout of a WebSocket header
// layout mapped from LSB to MSB for natural little-endian u16 loads
pub const FrameHeader = packed struct(u16) {
    payload_len: u7,
    mask: bool,
    opcode: u4,

    rsv3: bool,
    rsv2: bool,
    rsv1: bool,
    fin: bool,
};

// MaskingKey - 4-byte contiguous array used for frame payload XOR masking
// flat array prevents pointer chasing and cache line evictions
pub const MaskingKey = [2]u8;
