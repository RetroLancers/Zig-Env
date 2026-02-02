const std = @import("std");

pub const EnvKey = struct {
    key: []const u8,
    own_buffer: ?[]u8,
    key_index: usize,

    pub fn init() EnvKey {
        return EnvKey{
            .key = "",
            .own_buffer = null,
            .key_index = 0,
        };
    }

    pub fn deinit(self: *EnvKey, allocator: std.mem.Allocator) void {
        if (self.own_buffer) |buffer| {
            allocator.free(buffer);
            self.own_buffer = null;
        }
    }

    pub fn hasOwnBuffer(self: *const EnvKey) bool {
        return self.own_buffer != null;
    }

    /// Takes ownership of the provided buffer.
    /// If there was already an owned buffer, it is freed.
    /// The `key` field is updated to point to the new buffer.
    pub fn setOwnBuffer(self: *EnvKey, allocator: std.mem.Allocator, buffer: []u8) void {
        if (self.own_buffer) |old_buffer| {
            allocator.free(old_buffer);
        }
        self.own_buffer = buffer;
        self.key = buffer;
    }

    /// Shrinks the owned buffer to the specified length.
    pub fn clipOwnBuffer(self: *EnvKey, allocator: std.mem.Allocator, length: usize) !void {
        if (self.own_buffer) |buffer| {
            if (length == buffer.len) return;
            // Reallocate the buffer to the new length.
            const new_buffer = try allocator.realloc(buffer, length);
            self.own_buffer = new_buffer;
            self.key = new_buffer;
        }
    }
};

test "EnvKey initialization" {
    const key = EnvKey.init();
    try std.testing.expectEqualStrings("", key.key);
    try std.testing.expect(key.own_buffer == null);
    try std.testing.expectEqual(@as(usize, 0), key.key_index);
}

test "EnvKey buffer ownership" {
    const allocator = std.testing.allocator;
    var key = EnvKey.init();
    defer key.deinit(allocator);

    const buffer = try allocator.alloc(u8, 5);
    @memcpy(buffer, "hello");

    key.setOwnBuffer(allocator, buffer);

    try std.testing.expect(key.hasOwnBuffer());
    try std.testing.expectEqualStrings("hello", key.key);
}

test "EnvKey clip buffer" {
    const allocator = std.testing.allocator;
    var key = EnvKey.init();
    defer key.deinit(allocator);

    const buffer = try allocator.alloc(u8, 10);
    @memcpy(buffer, "helloworld");
    key.setOwnBuffer(allocator, buffer);

    try key.clipOwnBuffer(allocator, 5);

    try std.testing.expectEqualStrings("hello", key.key);
    try std.testing.expectEqual(@as(usize, 5), key.own_buffer.?.len);
}
