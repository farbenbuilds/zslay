const std = @import("std");
const types = @import("types.zig");
const frame = @import("frame.zig");
const queue = @import("queue.zig");

// invoked to read raw data from underlying transport
pub const RecvCallback = *const fn (ctx: *anyopaque, buf: []u8) anyerror!usize;

// invoked to write raw serialized data to the transport
pub const SendCallback = *const fn (ctx: *anyopaque, buf: []const u8) anyerror!usize;

// invoked to populate a 4-byte WebSocket masking key
pub const GenMaskCallback = *const fn (ctx: *anyopaque, buf: *[2]u8) anyerror!void;

// invoked when a WebSocket frame is successfully parsed
pub const OnFrameCallback = *const fn (
    ctx: *anyopaque,
    opcode: types.Opcode,
    fin: bool,
    payload: []const u8,
) anyerror!void;

// state of the WebSocket frame receiver machine
pub const RxState = enum {
    read_base_header,
    read_extended_header,
    read_payload,
};
