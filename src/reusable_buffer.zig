const std = @import("std");

/// ReusableBuffer is a custom buffer type designed to replace std.ArrayList(u8) usage
/// throughout the codebase. It provides a similar interface to C++ std::string when
/// used as a reusable buffer.
///
/// Why use this instead of std.ArrayList?
/// - Zig 0.15+ changed ArrayList to be unmanaged by default
/// - Our usage pattern matches C++ std::string: a mutable, owned buffer
/// - Optimized for reuse with clearRetainingCapacity
/// - Simpler API for our specific use case
///
/// Memory ownership:
/// - The buffer owns its memory and will free it on deinit()
/// - Use fromOwnedSlice() to transfer ownership of existing memory
/// - Use clone() to create an independent copy
pub const ReusableBuffer = struct {
    allocator: std.mem.Allocator,
    items: []u8,
    capacity: usize,

    /// Initialize an empty buffer with no initial allocation
    pub fn init(allocator: std.mem.Allocator) ReusableBuffer {
        return .{
            .allocator = allocator,
            .items = &[_]u8{},
            .capacity = 0,
        };
    }

    /// Initialize a buffer with a specific capacity pre-allocated
    pub fn initCapacity(allocator: std.mem.Allocator, capacity: usize) !ReusableBuffer {
        if (capacity == 0) {
            return init(allocator);
        }

        const buffer = try allocator.alloc(u8, capacity);
        return .{
            .allocator = allocator,
            .items = buffer[0..0],
            .capacity = capacity,
        };
    }

    /// Free all memory owned by this buffer
    pub fn deinit(self: *ReusableBuffer) void {
        if (self.capacity > 0) {
            const full_slice = self.items.ptr[0..self.capacity];
            self.allocator.free(full_slice);
        }
        self.* = undefined;
    }

    /// Append a single byte to the buffer, growing by 30% if necessary
    pub fn append(self: *ReusableBuffer, item: u8) !void {
        if (self.items.len >= self.capacity) {
            try self.ensureCapacityWithGrowth(self.items.len + 1, 30);
        }
        self.appendAssumeCapacity(item);
    }

    /// Append multiple bytes to the buffer, growing by 30% if necessary
    pub fn appendSlice(self: *ReusableBuffer, items: []const u8) !void {
        const needed = self.items.len + items.len;
        if (needed > self.capacity) {
            try self.ensureCapacityWithGrowth(needed, 30);
        }
        self.appendSliceAssumeCapacity(items);
    }

    /// Ensures capacity, growing by specified percentage if needed
    pub fn ensureCapacityWithGrowth(self: *ReusableBuffer, new_capacity: usize, growth_percent: u8) !void {
        if (new_capacity <= self.capacity) return;

        const growth_factor = @as(f32, @floatFromInt(100 + growth_percent)) / 100.0;
        const new_size = @max(new_capacity, @as(usize, @intFromFloat(@as(f32, @floatFromInt(self.capacity)) * growth_factor)));

        try self.ensureCapacity(new_size);
    }

    /// Resize the buffer to a new length
    /// If growing, new bytes are uninitialized
    /// If shrinking, excess bytes are dropped but capacity is retained
    pub fn resize(self: *ReusableBuffer, new_len: usize) !void {
        if (new_len > self.capacity) {
            try self.ensureCapacity(new_len);
        }
        self.items = self.items.ptr[0..new_len];
    }

    /// Create a buffer from an existing slice, taking ownership of the memory
    /// The slice must have been allocated with the same allocator
    pub fn fromOwnedSlice(allocator: std.mem.Allocator, slice: []u8) ReusableBuffer {
        return .{
            .allocator = allocator,
            .items = slice,
            .capacity = slice.len,
        };
    }

    /// Clear the buffer contents but retain the allocated capacity for reuse
    pub fn clearRetainingCapacity(self: *ReusableBuffer) void {
        self.items = self.items.ptr[0..0];
    }

    /// Create an independent copy of this buffer
    pub fn clone(self: *const ReusableBuffer) !ReusableBuffer {
        var new_buffer = try initCapacity(self.allocator, self.items.len);
        new_buffer.appendSliceAssumeCapacity(self.items);
        return new_buffer;
    }

    /// Transfer ownership of the buffer contents out, leaving the buffer empty
    /// The caller is responsible for freeing the returned slice
    pub fn toOwnedSlice(self: *ReusableBuffer) []u8 {
        const result = self.allocator.realloc(self.items.ptr[0..self.capacity], self.items.len) catch {
            // If realloc fails, just return the full capacity
            return self.items.ptr[0..self.items.len];
        };
        self.* = init(self.allocator);
        return result;
    }

    /// Get the current length of the buffer
    pub inline fn len(self: *const ReusableBuffer) usize {
        return self.items.len;
    }

    // Private helper methods

    fn ensureUnusedCapacity(self: *ReusableBuffer, additional: usize) !void {
        const current_len = self.items.len;
        const needed_capacity = current_len + additional;
        if (self.capacity >= needed_capacity) {
            return;
        }
        try self.ensureCapacity(needed_capacity);
    }

    fn ensureCapacity(self: *ReusableBuffer, new_capacity: usize) !void {
        if (self.capacity >= new_capacity) {
            return;
        }

        const new_memory = if (self.capacity > 0)
            try self.allocator.realloc(self.items.ptr[0..self.capacity], new_capacity)
        else
            try self.allocator.alloc(u8, new_capacity);

        self.items = new_memory[0..self.items.len];
        self.capacity = new_capacity;
    }

    fn appendAssumeCapacity(self: *ReusableBuffer, item: u8) void {
        const new_len = self.items.len + 1;
        self.items = self.items.ptr[0..new_len];
        self.items[new_len - 1] = item;
    }

    fn appendSliceAssumeCapacity(self: *ReusableBuffer, items: []const u8) void {
        const old_len = self.items.len;
        const new_len = old_len + items.len;
        self.items = self.items.ptr[0..new_len];
        @memcpy(self.items[old_len..new_len], items);
    }
    pub const Writer = std.io.GenericWriter(*ReusableBuffer, std.mem.Allocator.Error, appendWrite);

    pub fn writer(self: *ReusableBuffer) Writer {
        return .{ .context = self };
    }

    fn appendWrite(self: *ReusableBuffer, bytes: []const u8) !usize {
        try self.appendSlice(bytes);
        return bytes.len;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "ReusableBuffer: init and deinit" {
    var buffer = ReusableBuffer.init(std.testing.allocator);
    defer buffer.deinit();

    try std.testing.expectEqual(@as(usize, 0), buffer.len());
    try std.testing.expectEqual(@as(usize, 0), buffer.capacity);
}

test "ReusableBuffer: initCapacity" {
    var buffer = try ReusableBuffer.initCapacity(std.testing.allocator, 10);
    defer buffer.deinit();

    try std.testing.expectEqual(@as(usize, 0), buffer.len());
    try std.testing.expectEqual(@as(usize, 10), buffer.capacity);
}

test "ReusableBuffer: append single byte" {
    var buffer = ReusableBuffer.init(std.testing.allocator);
    defer buffer.deinit();

    try buffer.append('a');
    try std.testing.expectEqual(@as(usize, 1), buffer.len());
    try std.testing.expectEqual(@as(u8, 'a'), buffer.items[0]);

    try buffer.append('b');
    try std.testing.expectEqual(@as(usize, 2), buffer.len());
    try std.testing.expectEqual(@as(u8, 'b'), buffer.items[1]);
}

test "ReusableBuffer: appendSlice" {
    var buffer = ReusableBuffer.init(std.testing.allocator);
    defer buffer.deinit();

    try buffer.appendSlice("hello");
    try std.testing.expectEqual(@as(usize, 5), buffer.len());
    try std.testing.expectEqualStrings("hello", buffer.items);

    try buffer.appendSlice(" world");
    try std.testing.expectEqual(@as(usize, 11), buffer.len());
    try std.testing.expectEqualStrings("hello world", buffer.items);
}

test "ReusableBuffer: resize grow" {
    var buffer = ReusableBuffer.init(std.testing.allocator);
    defer buffer.deinit();

    try buffer.appendSlice("test");
    try buffer.resize(10);

    try std.testing.expectEqual(@as(usize, 10), buffer.len());
    try std.testing.expectEqualStrings("test", buffer.items[0..4]);
}

test "ReusableBuffer: resize shrink" {
    var buffer = ReusableBuffer.init(std.testing.allocator);
    defer buffer.deinit();

    try buffer.appendSlice("hello world");
    const old_capacity = buffer.capacity;

    try buffer.resize(5);

    try std.testing.expectEqual(@as(usize, 5), buffer.len());
    try std.testing.expectEqualStrings("hello", buffer.items);
    try std.testing.expectEqual(old_capacity, buffer.capacity); // Capacity should not change
}

test "ReusableBuffer: clearRetainingCapacity" {
    var buffer = ReusableBuffer.init(std.testing.allocator);
    defer buffer.deinit();

    try buffer.appendSlice("hello");
    const old_capacity = buffer.capacity;

    buffer.clearRetainingCapacity();

    try std.testing.expectEqual(@as(usize, 0), buffer.len());
    try std.testing.expectEqual(old_capacity, buffer.capacity);

    // Should be able to reuse without reallocation
    try buffer.appendSlice("world");
    try std.testing.expectEqualStrings("world", buffer.items);
}

test "ReusableBuffer: fromOwnedSlice" {
    const slice = try std.testing.allocator.alloc(u8, 5);
    @memcpy(slice, "hello");

    var buffer = ReusableBuffer.fromOwnedSlice(std.testing.allocator, slice);
    defer buffer.deinit();

    try std.testing.expectEqual(@as(usize, 5), buffer.len());
    try std.testing.expectEqualStrings("hello", buffer.items);
}

test "ReusableBuffer: clone" {
    var original = ReusableBuffer.init(std.testing.allocator);
    defer original.deinit();

    try original.appendSlice("test");

    var cloned = try original.clone();
    defer cloned.deinit();

    try std.testing.expectEqualStrings(original.items, cloned.items);

    // Modify original, clone should be unaffected
    try original.append('!');
    try std.testing.expectEqual(@as(usize, 4), cloned.len());
    try std.testing.expectEqualStrings("test", cloned.items);
}

test "ReusableBuffer: toOwnedSlice" {
    var buffer = ReusableBuffer.init(std.testing.allocator);

    try buffer.appendSlice("owned");

    const slice = buffer.toOwnedSlice();
    defer std.testing.allocator.free(slice);

    try std.testing.expectEqualStrings("owned", slice);
    try std.testing.expectEqual(@as(usize, 0), buffer.len());
    try std.testing.expectEqual(@as(usize, 0), buffer.capacity);

    // Buffer should still be usable
    try buffer.appendSlice("new");
    try std.testing.expectEqualStrings("new", buffer.items);
    buffer.deinit();
}

test "ReusableBuffer: multiple operations" {
    var buffer = try ReusableBuffer.initCapacity(std.testing.allocator, 5);
    defer buffer.deinit();

    try buffer.append('a');
    try buffer.appendSlice("bc");
    try std.testing.expectEqualStrings("abc", buffer.items);

    buffer.clearRetainingCapacity();
    try buffer.appendSlice("xyz");
    try std.testing.expectEqualStrings("xyz", buffer.items);

    try buffer.resize(6);
    buffer.items[3] = '1';
    buffer.items[4] = '2';
    buffer.items[5] = '3';
    try std.testing.expectEqualStrings("xyz123", buffer.items);
}

test "ReusableBuffer: no memory leaks with many operations" {
    var buffer = ReusableBuffer.init(std.testing.allocator);
    defer buffer.deinit();

    // Do many allocations and deallocations
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        try buffer.appendSlice("test data");
        buffer.clearRetainingCapacity();
    }

    try std.testing.expect(true); // If we got here without leaks, success!
}
