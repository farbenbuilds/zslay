const std = @import("std");

// Bounded FIFO deque over caller-provided storage
pub fn Queue(comptime Element: type) type {
    return struct {
        const Self = @This();

        buffer: []Element,
        head: usize = 0,
        tail: usize = 0,
        len: usize = 0,

        // Debug-only checks that indices stay within caller storage bounds
        fn assert_invariants(self: *const Self) void {
            std.debug.assert(self.len <= self.buffer.len);

            if (self.buffer.len == 0) {
                std.debug.assert(self.head == 0);
                std.debug.assert(self.tail == 0);
                return;
            }

            std.debug.assert(self.head < self.buffer.len);
            std.debug.assert(self.tail < self.buffer.len);
            if (self.len == 0) std.debug.assert(self.head == self.tail);
        }

        // initializes a queue with a pre-allocated slice
        pub fn init(buffer: []Element) Self {
            return .{
                .buffer = buffer,
            };
        }

        // appends an item to the tail of the queue
        pub fn push_back(self: *Self, item: Element) error{QueueFull}!void {
            self.assert_invariants();
            if (self.len >= self.buffer.len) return error.QueueFull;

            std.debug.assert(self.len < self.buffer.len);
            self.buffer[self.tail] = item;
            self.tail += 1;
            if (self.tail == self.buffer.len) self.tail = 0;
            self.len += 1;
            self.assert_invariants();
        }

        // prepends an item to the head of the queue
        pub fn push_front(self: *Self, item: Element) error{QueueFull}!void {
            self.assert_invariants();
            if (self.len >= self.buffer.len) return error.QueueFull;

            std.debug.assert(self.len < self.buffer.len);
            self.head = if (self.head == 0) self.buffer.len - 1 else self.head - 1;
            self.buffer[self.head] = item;
            self.len += 1;
            self.assert_invariants();
        }

        // removes and returns the head item of the queue
        pub fn pop_front(self: *Self) ?Element {
            self.assert_invariants();
            if (self.len == 0) return null;

            std.debug.assert(self.len > 0);
            const item = self.buffer[self.head];
            self.head += 1;
            if (self.head == self.buffer.len) self.head = 0;
            self.len -= 1;
            self.assert_invariants();
            return item;
        }

        // removes and returns the tail item of the queue
        pub fn pop_back(self: *Self) ?Element {
            self.assert_invariants();
            if (self.len == 0) return null;

            std.debug.assert(self.len > 0);
            self.tail = if (self.tail == 0) self.buffer.len - 1 else self.tail - 1;
            const item = self.buffer[self.tail];
            self.len -= 1;
            self.assert_invariants();
            return item;
        }

        // returns the head item without removing it
        pub fn front(self: *Self) ?*Element {
            self.assert_invariants();
            if (self.len == 0) return null;
            return &self.buffer[self.head];
        }

        // returns the head item through a read-only view
        pub fn front_const(self: *const Self) ?*const Element {
            self.assert_invariants();
            if (self.len == 0) return null;
            return &self.buffer[self.head];
        }

        // advances past the head item without copying it
        pub fn discard_front(self: *Self) void {
            self.assert_invariants();
            if (self.len == 0) return;

            std.debug.assert(self.len > 0);
            self.head += 1;
            if (self.head == self.buffer.len) self.head = 0;
            self.len -= 1;
            self.assert_invariants();
        }

        // drops every queued item and restores empty indices
        pub fn clear(self: *Self) void {
            self.assert_invariants();
            self.head = 0;
            self.tail = 0;
            self.len = 0;
            self.assert_invariants();
        }
    };
}
