const std = @import("std");

pub const EnvKey = struct {
    key: []const u8,
    // Buffer management
    buffer: std.ArrayList(u8),
    key_index: usize,

    pub fn init(allocator: std.mem.Allocator) EnvKey {
        return EnvKey{
            .key = "",
            .buffer = std.ArrayList(u8).init(allocator),
            .key_index = 0,
        };
    }

    pub fn deinit(self: *EnvKey, allocator: std.mem.Allocator) void {
        _ = allocator;
        self.buffer.deinit();
    }

    pub fn hasOwnBuffer(self: *const EnvKey) bool {
        return self.buffer.items.len > 0;
    }

    /// Takes ownership of the provided buffer.
    /// If there was already an owned buffer, it is freed.
    /// The `key` field is updated to point to the new buffer.
    pub fn setOwnBuffer(self: *EnvKey, allocator: std.mem.Allocator, buffer: []u8) void {
        _ = allocator;
        self.buffer.deinit();
        self.buffer = std.ArrayList(u8).fromOwnedSlice(self.buffer.allocator, buffer);
        self.key = self.buffer.items;
        self.key_index = self.buffer.items.len;
    }

    /// Shrinks the owned buffer to the specified length.
    pub fn clipOwnBuffer(self: *EnvKey, allocator: std.mem.Allocator, length: usize) !void {
        _ = allocator;
        try self.buffer.resize(length);
        self.key = self.buffer.items;
        self.key_index = self.buffer.items.len;
    }
};

test "EnvKey initialization" {
    const allocator = std.testing.allocator;
    var key = EnvKey.init(allocator);
    defer key.deinit(allocator);

    try std.testing.expectEqualStrings("", key.key);
    try std.testing.expect(key.buffer.items.len == 0);
    try std.testing.expectEqual(@as(usize, 0), key.key_index);
}

test "EnvKey buffer ownership" {
    const allocator = std.testing.allocator;
    var key = EnvKey.init(allocator);
    defer key.deinit(allocator);

    const buffer = try allocator.alloc(u8, 5);
    @memcpy(buffer, "hello");

    key.setOwnBuffer(allocator, buffer);

    try std.testing.expect(key.hasOwnBuffer());
    try std.testing.expectEqualStrings("hello", key.key);
}

test "EnvKey clip buffer" {
    const allocator = std.testing.allocator;
    var key = EnvKey.init(allocator);
    defer key.deinit(allocator);

    const buffer = try allocator.alloc(u8, 10);
    @memcpy(buffer, "helloworld");
    key.setOwnBuffer(allocator, buffer);

    try key.clipOwnBuffer(allocator, 5);

    try std.testing.expectEqualStrings("hello", key.key);
    try std.testing.expectEqual(@as(usize, 5), key.buffer.items.len);
}
