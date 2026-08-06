const std = @import("std");
const types = @import("types.zig");

// invoked to read raw data from underlying transport
pub const RecvCallback = *const fn (ctx: *anyopaque, buf: []u8) anyerror!usize;

// invoked to write raw serialized data to the transport
pub const SendCallback = *const fn (ctx: *anyopaque, buf: []const u8) anyerror!usize;

// invoked to populate a 4-byte WebSocket masking key
pub const GenMaskCallback = *const fn (ctx: *anyopaque, buf: *types.MaskingKey) anyerror!void;

// invoked when a WebSocket frame is successfully parsed
pub const OnFrameCallback = *const fn (
    ctx: *anyopaque,
    opcode: types.Opcode,
    fin: bool,
    payload: []const u8,
) anyerror!void;

// group of all callbacks provided by the consumer
pub const Callbacks = struct {
    recv_callback: ?RecvCallback = null,
    send_callback: ?SendCallback = null,
    gen_mask_callback: ?GenMaskCallback = null,
    on_frame_callback: ?OnFrameCallback = null,
};

// state of the WebSocket frame receiver machine
// Explicit u8 backing for compact state tracking and DOD caching
pub const RxState = enum(u8) {
    read_base_header = 0,
    read_extended_header = 1,
    read_payload = 2,
};
