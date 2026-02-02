const std = @import("std");
const EnvKey = @import("env_key.zig").EnvKey;
const EnvValue = @import("env_value.zig").EnvValue;

pub const EnvPair = struct {
    key: EnvKey,
    value: EnvValue,

    pub fn init(allocator: std.mem.Allocator) EnvPair {
        return EnvPair{
            .key = EnvKey.init(),
            .value = EnvValue.init(allocator),
        };
    }

    pub fn deinit(self: *EnvPair, allocator: std.mem.Allocator) void {
        self.key.deinit(allocator);
        self.value.deinit(allocator);
    }
};

test "EnvPair initialization and lifecycle" {
    const allocator = std.testing.allocator;
    var pair = EnvPair.init(allocator);
    defer pair.deinit(allocator);

    // Verify key init
    try std.testing.expectEqualStrings("", pair.key.key);
    
    // Verify value init
    try std.testing.expectEqualStrings("", pair.value.value);
    
    // Modify and check cleanup
    const kbuf = try allocator.alloc(u8, 3);
    @memcpy(kbuf, "key");
    pair.key.setOwnBuffer(allocator, kbuf);
    
    const vbuf = try allocator.alloc(u8, 5);
    @memcpy(vbuf, "value");
    pair.value.setOwnBuffer(allocator, vbuf);
    
    try std.testing.expectEqualStrings("key", pair.key.key);
    try std.testing.expectEqualStrings("value", pair.value.value);
}
