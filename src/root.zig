// re-exports the public interface for pure Zig applications
pub const types = @import("types.zig");
pub const frame = @import("frame.zig");

pub const queue = @import("queue.zig");
pub const event = @import("event.zig");

// re-exports core WebSocket types
pub const Opcode = types.Opcode;
pub const StatusCode = types.StatusCode;
pub const Error = types.Error;

pub const FrameHeader = types.FrameHeader;
pub const MaskingKey = types.MaskingKey;

// re-exports frame operations
pub const DecodedHeader = frame.DecodedHeader;
pub const decode_header = frame.decode_header;
pub const encode_header = frame.encode_header;

pub const get_serialized_size = frame.get_serialized_size;
pub const mask = frame.mask;

// re-exports ring buffer/dequeue
pub const Queue = queue.Queue;

// re-exports high-level connection context and callbacks
pub const Conn = event.Conn;
pub const RxState = event.RxState;

pub const RecvCallback = event.RecvCallback;
pub const SendCallback = event.SendCallback;
pub const GenMaskCallback = event.GenMaskCallback;
pub const OnFrameCallback = event.OnFrameCallback;
