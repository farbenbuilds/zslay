const std = @import("std");

/// WebSocket frame opcodes defined in RFC 6455
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

/// WebSocket connection close status codes
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

/// Pure Zig error set for WebSocket frame parsing
pub const Error = error{
    InvalidOpcode,
    InvalidLength,
    BufferTooShort,

    ProtocolError,
    PayloadMasked,
    PayloadNotMasked,
};

/// Contiguous 16-bit physical layout of a WebSocket header
pub const FrameHeader = packed struct(u16) {
    opcode: u4,
    rsv3: bool,
    rsv2: bool,
    rsv1: bool,
    fin: bool,

    payload_len: u7,
    mask: bool,
};

/// 4-byte contiguous array used for frame payload XOR masking
pub const MaskingKey = [4]u8;
