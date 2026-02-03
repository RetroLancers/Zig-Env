const std = @import("std");
const reader = @import("reader.zig");
const finalizer = @import("finalizer.zig");
const EnvStream = @import("env_stream.zig").EnvStream;
const memory = @import("memory.zig");
const EnvPair = @import("env_pair.zig").EnvPair;
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
    fn put(self: *Env, key: []const u8, value: []const u8) !void {
        try self.map.put(key, value);
    }
};

/// High-level API to parse a .env file from disk
pub fn parseFile(allocator: Allocator, path: []const u8) !Env {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(content);

    return parseString(allocator, content);
}

/// Parse .env content from a string
pub fn parseString(allocator: Allocator, content: []const u8) !Env {
    var stream = EnvStream.init(content);
    var pairs = try reader.readPairs(allocator, &stream);
    errdefer memory.deletePairs(allocator, &pairs);

    try finalizer.finalizeAllValues(allocator, &pairs);

    var env = Env.init(allocator);
    errdefer env.deinit();

    for (pairs.items) |*pair| {
        // Take ownership of buffers
        const key = pair.key.buffer.toOwnedSlice();
        errdefer allocator.free(key);

        const value = try pair.value.buffer.toOwnedSlice();
        errdefer allocator.free(value);

        try env.put(key, value);
    }

    // Clean up pair structures (interpolations, etc.) but buffers are already emptied by toOwnedSlice
    for (pairs.items) |*pair| {
        pair.deinit();
    }
    pairs.deinit();

    return env;
}

/// Parse .env content from a string (alias for parseString)
pub const parse = parseString;

/// Parse from any std.io.Reader
pub fn parseReader(allocator: Allocator, reader_obj: anytype) !Env {
    const content = try reader_obj.readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(content);
    return parseString(allocator, content);
}

test "parseString basic" {
    const allocator = std.testing.allocator;
    const content = "KEY=VALUE\nNAME=WORLD";
    var env = try parseString(allocator, content);
    defer env.deinit();

    try std.testing.expectEqualStrings("VALUE", env.get("KEY").?);
    try std.testing.expectEqualStrings("WORLD", env.get("NAME").?);
}

test "parseString with interpolation" {
    const allocator = std.testing.allocator;
    const content = "USER=antigravity\nWELCOME=hello ${USER}";
    var env = try parseString(allocator, content);
    defer env.deinit();

    try std.testing.expectEqualStrings("antigravity", env.get("USER").?);
    try std.testing.expectEqualStrings("hello antigravity", env.get("WELCOME").?);
}

test "parseFile basic" {
    const allocator = std.testing.allocator;
    const path = "test_env_file.env";
    const content = "FILE_KEY=FILE_VALUE";

    // Create temp file
    const file = try std.fs.cwd().createFile(path, .{});
    try file.writeAll(content);
    file.close();
    defer std.fs.cwd().deleteFile(path) catch {};

    var env = try parseFile(allocator, path);
    defer env.deinit();

    try std.testing.expectEqualStrings("FILE_VALUE", env.get("FILE_KEY").?);
}

test "Env methods" {
    const allocator = std.testing.allocator;
    var env = Env.init(allocator);
    defer env.deinit();

    const key = try allocator.dupe(u8, "K");
    const val = try allocator.dupe(u8, "V");

    try env.put(key, val);

    try std.testing.expectEqualStrings("V", env.get("K").?);
    try std.testing.expectEqualStrings("V", env.getWithDefault("K", "D"));
    try std.testing.expectEqualStrings("D", env.getWithDefault("MISSING", "D"));
}
