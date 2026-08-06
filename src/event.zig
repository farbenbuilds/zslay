const std = @import("std");
const types = @import("types.zig");
const frame = @import("frame.zig");
const queue = @import("queue.zig");

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

// zero-allocation, I/O-agnostic WebSocket connection context
// coordinates frame streaming, XOR masking, and instrusive TX queueing
pub const Conn = struct {
    // group of all callbacks provided by the consumer
    callbacks: Callbacks,

    // consumer provided state context
    ctx: *anyopaque,

    // queue to store outgoing frames using instrusive doubly-linked list
    tx_queue: queue.Queue(FrameNode, "link") = queue.Queue(FrameNode, "link").init(),

    // decoded frame header of currently processed incoming frame
    decoded_header: ?frame.DecoderHeader = null,

    // bytes of current payload processed so far
    payload_bytes_processed: u64 = 0,

    // total header bytes parsed so far
    header_bytes_read: usize = 0,

    // current expected physical header size (2 to 14 bytes)
    header_bytes_needed: usize = 2,

    // temporary buffer to accumulate and parse incoming frame headers
    // maximum possible WebSocket frame header size is 14 bytes
    header_buf: [14]u8 = undefined,

    // receiver machine parsing state
    rx_state: RxState = .read_base_header,

    // instrusive queue element representing an outgoing frame
    // allocated out-of-band by the user to guarantee zero-heap usage
    pub const FrameNode = struct {
        payload: []const u8 = &.{},
        link: queue.Node(FrameNode) = .{},

        header_size: usize = 0,
        sent_header: usize = 0,
        sent_payload: usize = 0,

        // maximum possible WebSocket frame header size is 14 bytes
        header_buf: [14]u8 = undefined,
    };
};
