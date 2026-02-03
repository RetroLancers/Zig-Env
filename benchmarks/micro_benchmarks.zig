const std = @import("std");
const framework = @import("framework.zig");
const zigenv = @import("zigenv");

// Key Parsing
const KeyParsingContext = struct {
    stream: zigenv.EnvStream,
    key: zigenv.EnvKey,
    content: []const u8,

    pub fn init(allocator: std.mem.Allocator) KeyParsingContext {
        return KeyParsingContext{
            .content = "KEY=value",
            .stream = undefined, // Set in reset
            .key = zigenv.EnvKey.init(allocator),
        };
    }

    pub fn deinit(self: *KeyParsingContext) void {
        self.key.deinit();
    }
};

fn resetKeyParsing(ctx: *KeyParsingContext) void {
    ctx.key.clear();
    ctx.stream = zigenv.EnvStream.init(ctx.content);
}

fn runKeyParsing(ctx: *KeyParsingContext, _: std.mem.Allocator) !void {
    _ = try zigenv.reader.readKey(&ctx.stream, &ctx.key);
}

pub fn benchmarkKeyParsing(allocator: std.mem.Allocator) !framework.BenchmarkResult {
    var ctx = KeyParsingContext.init(allocator);
    defer ctx.deinit();

    return framework.benchmarkWithSetup(
        allocator,
        "Key Parsing",
        &ctx,
        runKeyParsing,
        resetKeyParsing,
        .{},
    );
}

// Value Parsing
const ValueParsingContext = struct {
    stream: zigenv.EnvStream,
    value: zigenv.EnvValue,
    content: []const u8,
    options: zigenv.ParserOptions,

    pub fn init(allocator: std.mem.Allocator) ValueParsingContext {
        return ValueParsingContext{
            .content = "value",
            .stream = undefined,
            .value = zigenv.EnvValue.init(allocator),
            .options = .{},
        };
    }

    pub fn deinit(self: *ValueParsingContext) void {
        self.value.deinit();
    }
};

fn resetValueParsing(ctx: *ValueParsingContext) void {
    ctx.value.clear();
    ctx.stream = zigenv.EnvStream.init(ctx.content);
}

fn runValueParsing(ctx: *ValueParsingContext, allocator: std.mem.Allocator) !void {
    _ = try zigenv.reader.readValue(allocator, &ctx.stream, &ctx.value, ctx.options);
}

pub fn benchmarkValueParsing(allocator: std.mem.Allocator) !framework.BenchmarkResult {
    var ctx = ValueParsingContext.init(allocator);
    defer ctx.deinit();

    return framework.benchmarkWithSetup(
        allocator,
        "Value Parsing",
        &ctx,
        runValueParsing,
        resetValueParsing,
        .{},
    );
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Key Parsing
    const key_result = try benchmarkKeyParsing(allocator);
    try framework.printResults(key_result);

    // Value Parsing
    const value_result = try benchmarkValueParsing(allocator);
    try framework.printResults(value_result);
}
