const std = @import("std");

pub fn Queue(comptime T: type) type {
    return struct {
        const Self = @This();

        buffer: []T,
        head: u16 = 0,
        tail: u16 = 0,
        len: u16 = 0,

        // initializes a queue with a pre-allocated slice
        pub fn init(buffer: []T) Self {
            std.debug.assert(buffer.len <= std.math.maxInt(u16));
            return .{
                .buffer = buffer,
            };
        }

        // appends an item to the tail of the queue
        pub fn push_back(self: *Self, item: T) error{QueueFull}!void {
            if (self.len >= self.buffer.len) return error.QueueFull;

            self.buffer[self.tail] = item;
            self.tail = @intCast((self.tail + 1) % self.buffer.len);
            self.len += 1;
        }

        // prepends an item to the head of the queue
        pub fn push_front(self: *Self, item: T) error{QueueFull}!void {
            if (self.len >= self.buffer.len) return error.QueueFull;

            self.head = if (self.head == 0) @intCast(self.buffer.len - 1) else self.head - 1;
            self.buffer[self.head] = item;
            self.len += 1;
        }

        // removes and returns the head item of the queue
        pub fn pop_front(self: *Self) ?T {
            if (self.len == 0) return null;

            const item = self.buffer[self.head];
            self.head = @intCast((self.head + 1) % self.buffer.len);
            self.len -= 1;
            return item;
        }

        // removes and returns the tail item of the queue
        pub fn pop_back(self: *Self) ?T {
            if (self.len == 0) return null;

            self.tail = if (self.tail == 0) @intCast(self.buffer.len - 1) else self.tail - 1;
            const item = self.buffer[self.tail];
            self.len -= 1;
            return item;
        }
    };
}
