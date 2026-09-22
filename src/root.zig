// zslay - A pure Zig port of the wslay WebSocket parser library.
// Provides the I/O-agnostic, zero-allocation core API.

// re-exports the public interface for pure Zig applications
pub const types = @import("types.zig");
pub const frame = @import("frame.zig");

pub const queue = @import("queue.zig");
pub const event = @import("event.zig");

// re-exports core WebSocket types
pub const Opcode = types.Opcode;
pub const StatusCode = types.StatusCode;
pub const Error = types.Error;
pub const EndpointRole = types.EndpointRole;
pub const MaxPayloadLen = types.MaxPayloadLen;

pub const FrameHeader = types.FrameHeader;
pub const MaskingKey = types.MaskingKey;
pub const MaskingKeyLen = types.MaskingKeyLen;
pub const MaxFrameHeaderLen = types.MaxFrameHeaderLen;
pub const FrameHeaderBuffer = types.FrameHeaderBuffer;

// re-exports frame operations
pub const DecodedHeader = frame.DecodedHeader;
pub const decode_header = frame.decode_header;
pub const encode_header = frame.encode_header;

pub const get_serialized_size = frame.get_serialized_size;
pub const mask = frame.mask;

pub const validate_close_payload = frame.validate_close_payload;

// re-exports ring buffer/dequeue
pub const Queue = queue.Queue;

// re-exports high-level connection context and callbacks
pub const Conn = event.Conn;
pub const ConnConfig = event.ConnConfig;
pub const FrameNode = event.FrameNode;
pub const RxState = event.RxState;

pub const RxAction = event.RxAction;
pub const TxAction = event.TxAction;
