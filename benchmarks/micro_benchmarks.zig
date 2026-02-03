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

// Quote Processing
const QuoteParsingContext = struct {
    value: zigenv.EnvValue,

    pub fn init(allocator: std.mem.Allocator) QuoteParsingContext {
        return QuoteParsingContext{
            .value = zigenv.EnvValue.init(allocator),
        };
    }

    pub fn deinit(self: *QuoteParsingContext) void {
        self.value.deinit();
    }
};

fn resetQuoteParsing(ctx: *QuoteParsingContext) void {
    ctx.value.clear();
    ctx.value.single_quote_streak = 1;
}

fn runQuoteParsing(ctx: *QuoteParsingContext, _: std.mem.Allocator) !void {
    _ = try zigenv.internal.quote_parser.walkSingleQuotes(&ctx.value);
}

pub fn benchmarkQuoteProcessing(allocator: std.mem.Allocator) !framework.BenchmarkResult {
    var ctx = QuoteParsingContext.init(allocator);
    defer ctx.deinit();

    return framework.benchmarkWithSetup(
        allocator,
        "Quote Processing",
        &ctx,
        runQuoteParsing,
        resetQuoteParsing,
        .{},
    );
}

// Escape Processing
const EscapeProcessingContext = struct {
    value: zigenv.EnvValue,

    pub fn init(allocator: std.mem.Allocator) EscapeProcessingContext {
        return EscapeProcessingContext{
            .value = zigenv.EnvValue.init(allocator),
        };
    }

    pub fn deinit(self: *EscapeProcessingContext) void {
        self.value.deinit();
    }
};

fn resetEscapeProcessing(ctx: *EscapeProcessingContext) void {
    ctx.value.clear();
}

fn runEscapeProcessing(ctx: *EscapeProcessingContext, _: std.mem.Allocator) !void {
    _ = try zigenv.internal.escape_processor.processPossibleControlCharacter(&ctx.value, 'n');
}

pub fn benchmarkEscapeProcessing(allocator: std.mem.Allocator) !framework.BenchmarkResult {
    var ctx = EscapeProcessingContext.init(allocator);
    defer ctx.deinit();

    return framework.benchmarkWithSetup(
        allocator,
        "Escape Processing",
        &ctx,
        runEscapeProcessing,
        resetEscapeProcessing,
        .{},
    );
}

// Comment Skipping
const CommentSkippingContext = struct {
    stream: zigenv.EnvStream,
    content: []const u8,

    pub fn init() CommentSkippingContext {
        return CommentSkippingContext{
            .content = "# This is a comment until the end of the line\n",
            .stream = undefined,
        };
    }
};

fn resetCommentSkipping(ctx: *CommentSkippingContext) void {
    ctx.stream = zigenv.EnvStream.init(ctx.content);
}

fn runCommentSkipping(ctx: *CommentSkippingContext, _: std.mem.Allocator) !void {
    ctx.stream.skipToNewline();
}

pub fn benchmarkCommentSkipping(allocator: std.mem.Allocator) !framework.BenchmarkResult {
    var ctx = CommentSkippingContext.init();

    return framework.benchmarkWithSetup(
        allocator,
        "Comment Skipping",
        &ctx,
        runCommentSkipping,
        resetCommentSkipping,
        .{},
    );
}

// HashMap Lookup
const HashMapLookupContext = struct {
    env: zigenv.Env,
    key: []const u8,

    pub fn init(allocator: std.mem.Allocator) !HashMapLookupContext {
        var env = zigenv.Env.init(allocator);
        try env.put("DATABASE_URL", "postgres://user:pass@localhost:5432/db");
        try env.put("API_KEY", "sk_live_123456789");
        try env.put("DEBUG", "true");
        return HashMapLookupContext{
            .env = env,
            .key = "API_KEY",
        };
    }

    pub fn deinit(self: *HashMapLookupContext) void {
        self.env.deinit();
    }
};

fn runHashMapLookup(ctx: *HashMapLookupContext, _: std.mem.Allocator) !void {
    _ = ctx.env.get(ctx.key);
}

pub fn benchmarkHashMapLookup(allocator: std.mem.Allocator) !framework.BenchmarkResult {
    var ctx = try HashMapLookupContext.init(allocator);
    defer ctx.deinit();

    return framework.benchmarkWithSetup(
        allocator,
        "HashMap Lookup",
        &ctx,
        runHashMapLookup,
        null,
        .{},
    );
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const benchmarks = [_]*const fn (std.mem.Allocator) anyerror!framework.BenchmarkResult{
        benchmarkKeyParsing,
        benchmarkValueParsing,
        benchmarkQuoteProcessing,
        benchmarkEscapeProcessing,
        benchmarkCommentSkipping,
        benchmarkHashMapLookup,
    };

    for (benchmarks) |bench| {
        // We can't easily get the name of the function, but we can print when we start.
        const result = try bench(allocator);
        try framework.printResults(result);
    }
}
