const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Env = struct {
    map: std.StringHashMap([]const u8),
    allocator: Allocator,

    pub fn init(allocator: Allocator) Env {
        return .{
            .map = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Env) void {
        var it = self.map.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.map.deinit();
    }

    pub fn get(self: Env, key: []const u8) ?[]const u8 {
        return self.map.get(key);
    }

    pub fn getWithDefault(self: Env, key: []const u8, default: []const u8) []const u8 {
        return self.map.get(key) orelse default;
    }

    /// Internal helper to put owned strings into the map
    pub fn put(self: *Env, key: []const u8, value: []const u8) !void {
        const gop = try self.map.getOrPut(key);
        if (gop.found_existing) {
            self.allocator.free(gop.key_ptr.*);
            self.allocator.free(gop.value_ptr.*);
            gop.key_ptr.* = key;
        }
        gop.value_ptr.* = value;
    }
};
