const std = @import("std");

// intrusive link node containing pointers to neighbors
// embedded inside the queued structures to avoid dynamic memory allocation
pub fn node(comptime T: type) type {
    return struct {
        next: ?*T = null,
        prev: ?*T = null,
    };
}

// a generic, zero allocation intrusive doubly-linked list
// target struct T must contain a field of type node(T)
pub fn queue(comptime T: type, comptime link_name: []const u8) type {
    return struct {
        const Self = @This();

        head: ?*T = null,
        tail: ?*T = null,
        len: usize = 0,

        // init - initializes an empty intrusive queue
        pub fn init() Self {
            return .{};
        }

        // get_link - helper to obtain a pointer to the link node inside T
        inline fn get_link(node: *T) *Node(T) {
            return &@field(node, link_name);
        }

        pub fn push_back(self: *Self, node: *T) void {
            const link = get_link(node);

            link.next = null;
            link.prev = self.tail;

            if (self.tail) |t| {
                get_link(t).next = node;
            } else {
                self.head = node;
            }

            self.tail = node;
            self.len += 1;
        }

        // push_front - prepends a node to the head of the queue
        pub fn push_front(self: *Self, node: *T) void {
            const link = get_link(node);
            link.next = self.head;
            link.prev = null;

            if (self.head) |h| {
                get_link(h).prev = node;
            } else {
                self.tail = node;
            }

            self.head = node;
            self.len += 1;
        }

        // pop_front - removes and returns the head node of the queue
        pub fn pop_front(self: *Self) ?*T {
            const node = self.head orelse return null;
            const link = get_link(node);

            self.head = link.next;

            if (self.head) |h| {
                get_link(h).prev = null;
            } else {
                self.tail = null;
            }

            link.next = null;
            link.prev = null;
            self.len -= 1;
            return node;
        }

        // remove - removes a specific node from anywhere in the queue
        pub fn remove(self: *Self, node: *T) void {
            const link = get_link(node);

            if (link.prev) |p| {
                get_link(p).next = link.next;
            } else {
                self.head = link.next;
            }

            if (link.next) |n| {
                get_link(n).prev = link.prev;
            } else {
                self.tail = link.prev;
            }

            link.next = null;
            link.prev = null;
            self.len -= 1;
        }
    };
}
