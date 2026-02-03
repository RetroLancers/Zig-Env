const std = @import("std");
const ReusableBuffer = @import("reusable_buffer.zig").ReusableBuffer;

pub const EnvKey = struct {
    key: []const u8,
    // Buffer management
    buffer: ReusableBuffer,
    key_index: usize,

    pub fn init(allocator: std.mem.Allocator) EnvKey {
        return EnvKey{
            .key = "",
            .buffer = ReusableBuffer.init(allocator),
            .key_index = 0,
        };
    }

    pub fn deinit(self: *EnvKey) void {
        self.buffer.deinit();
    }

    pub fn hasOwnBuffer(self: *const EnvKey) bool {
        return self.buffer.items.len > 0;
    }

    /// Takes ownership of the provided buffer.
    /// If there was already an owned buffer, it is freed.
    /// The `key` field is updated to point to the new buffer.
    pub fn setOwnBuffer(self: *EnvKey, buffer: []u8) void {
        const allocator = self.buffer.allocator;
        self.buffer.deinit();
        self.buffer = ReusableBuffer.fromOwnedSlice(allocator, buffer);
        self.key = self.buffer.items;
        self.key_index = self.buffer.items.len;
    }

    /// Shrinks the owned buffer to the specified length.
    pub fn clipOwnBuffer(self: *EnvKey, length: usize) !void {
        try self.buffer.resize(length);
        self.key = self.buffer.items;
        self.key_index = self.buffer.items.len;
    }
};

test "EnvKey initialization" {
    const allocator = std.testing.allocator;
    var key = EnvKey.init(allocator);
    defer key.deinit();

    try std.testing.expectEqualStrings("", key.key);
    try std.testing.expect(key.buffer.items.len == 0);
    try std.testing.expectEqual(@as(usize, 0), key.key_index);
}

test "EnvKey buffer ownership" {
    const allocator = std.testing.allocator;
    var key = EnvKey.init(allocator);
    defer key.deinit();

    const buffer = try allocator.alloc(u8, 5);
    @memcpy(buffer, "hello");

    key.setOwnBuffer(buffer);

    try std.testing.expect(key.hasOwnBuffer());
    try std.testing.expectEqualStrings("hello", key.key);
}

test "EnvKey clip buffer" {
    const allocator = std.testing.allocator;
    var key = EnvKey.init(allocator);
    defer key.deinit();

    const buffer = try allocator.alloc(u8, 10);
    @memcpy(buffer, "helloworld");
    key.setOwnBuffer(buffer);

    try key.clipOwnBuffer(5);

    try std.testing.expectEqualStrings("hello", key.key);
    try std.testing.expectEqual(@as(usize, 5), key.buffer.items.len);
}
