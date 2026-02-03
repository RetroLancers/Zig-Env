const std = @import("std");
const EnvStream = @import("env_stream.zig").EnvStream;
const EnvPair = @import("../data/env_pair.zig").EnvPair;
const ParserOptions = @import("../data/parser_options.zig").ParserOptions;
const ReadResult = @import("../data/read_result.zig").ReadResult;
const readKey = @import("read_key.zig").readKey;
const readValue = @import("read_value.zig").readValue;
const interpolation = @import("../interpolation/interpolation.zig");
const memory = @import("../buffer/memory_utils.zig");
const file_scanner = @import("file_scanner.zig");
const testing = std.testing;

pub fn readPair(allocator: std.mem.Allocator, stream: *EnvStream, pair: *EnvPair, options: ParserOptions) !ReadResult {
    const result = try readKey(stream, &pair.key);
    if (result == ReadResult.fail or result == ReadResult.empty) {
        return ReadResult.fail;
    }
    if (result == ReadResult.comment_encountered) {
        return ReadResult.comment_encountered;
    }
    if (result == ReadResult.end_of_stream_key) {
        return ReadResult.end_of_stream_key;
    }

    if (result == ReadResult.end_of_stream_value) {
        return ReadResult.success;
    }

    // Trim right side of key
    while (pair.key.key_index > 0) {
        if (pair.key.key[pair.key.key_index - 1] != ' ') {
            break;
        }
        pair.key.key_index -= 1;
    }

    // Copy key to own buffer
    if (!pair.key.hasOwnBuffer()) {
        const tmp_str = try allocator.alloc(u8, pair.key.key_index);
        errdefer allocator.free(tmp_str);
        pair.key.setOwnBuffer(tmp_str);
    } else {
        try pair.key.clipOwnBuffer(pair.key.key_index);
    }

    // Read value
    const value_result = try readValue(allocator, stream, &pair.value, options);
    if (value_result == ReadResult.end_of_stream_value) {
        return ReadResult.end_of_stream_value;
    }

    if (value_result == ReadResult.comment_encountered or value_result == ReadResult.success) {
        // Copy value to own buffer
        if (!pair.value.hasOwnBuffer()) {
            const tmp_str = try allocator.alloc(u8, pair.value.value_index);
            errdefer allocator.free(tmp_str);
            @memcpy(tmp_str, pair.value.value[0..pair.value.value_index]);
            pair.value.setOwnBuffer(tmp_str);
        } else {
            try pair.value.clipOwnBuffer(pair.value.value_index);
        }
        interpolation.removeUnclosedInterpolation(&pair.value);
        return ReadResult.success;
    }

    if (value_result == ReadResult.empty) {
        interpolation.removeUnclosedInterpolation(&pair.value);
        return ReadResult.empty;
    }

    if (value_result == ReadResult.end_of_stream_key) {
        interpolation.removeUnclosedInterpolation(&pair.value);
        return ReadResult.end_of_stream_key;
    }

    interpolation.removeUnclosedInterpolation(&pair.value);
    return ReadResult.fail;
}

pub fn readPairsWithHints(
    allocator: std.mem.Allocator,
    stream: *EnvStream,
    hints: file_scanner.BufferSizeHints,
    options: ParserOptions,
) !std.ArrayListUnmanaged(EnvPair) {
    // Pre-allocate capacity if we have a pair count estimate
    var pairs = std.ArrayListUnmanaged(EnvPair){};
    if (hints.estimated_pair_count > 0) {
        try pairs.ensureTotalCapacity(allocator, hints.estimated_pair_count);
    }
    errdefer memory.deletePairs(allocator, &pairs);

    while (true) {
        // Use capacity hints for initialization
        var pair = try EnvPair.initWithCapacity(
            allocator,
            hints.max_key_size,
            hints.max_value_size,
        );

        const result = try readPair(allocator, stream, &pair, options);
        if (result == ReadResult.end_of_stream_value) {
            try pairs.append(allocator, pair);
            break;
        }
        if (result == ReadResult.success) {
            try pairs.append(allocator, pair);
            continue;
        }

        // Free failed pair
        pair.deinit();

        if (result == ReadResult.comment_encountered or result == ReadResult.fail) {
            continue;
        }
        break;
    }

    return pairs;
}

pub fn readPairsWithOptions(allocator: std.mem.Allocator, stream: *EnvStream, options: ParserOptions) !std.ArrayListUnmanaged(EnvPair) {
    // Use default hints (0 capacity = start small)
    const default_hints = file_scanner.BufferSizeHints{
        .max_key_size = 0,
        .max_value_size = 0,
        .estimated_pair_count = 0,
    };
    return readPairsWithHints(allocator, stream, default_hints, options);
}

pub fn readPairs(allocator: std.mem.Allocator, stream: *EnvStream) !std.ArrayListUnmanaged(EnvPair) {
    return readPairsWithOptions(allocator, stream, ParserOptions.defaults());
}

test "readPair simple pair" {
    const default_options = ParserOptions.defaults();
    var stream = EnvStream.init("KEY=value");

    var pair = EnvPair.init(testing.allocator);
    defer pair.deinit();

    const result = try readPair(testing.allocator, &stream, &pair, default_options);

    try testing.expectEqual(ReadResult.success, result);
    try testing.expectEqualStrings("KEY", pair.key.key);
    try testing.expectEqualStrings("value", pair.value.value);
}

test "readPair with whitespace" {
    const default_options = ParserOptions.defaults();
    var stream = EnvStream.init("  KEY  =  value  ");

    var pair = EnvPair.init(testing.allocator);
    defer pair.deinit();

    const result = try readPair(testing.allocator, &stream, &pair, default_options);

    try testing.expectEqual(ReadResult.success, result);
    try testing.expectEqualStrings("KEY", pair.key.key);
    // Value should have right trimming if implicit double quote
}

test "readPair with quotes" {
    const default_options = ParserOptions.defaults();
    var stream = EnvStream.init("KEY=\"quoted value\"");

    var pair = EnvPair.init(testing.allocator);
    defer pair.deinit();

    const result = try readPair(testing.allocator, &stream, &pair, default_options);

    try testing.expectEqual(ReadResult.success, result);
    try testing.expectEqualStrings("KEY", pair.key.key);
}

test "readPair comment line" {
    const default_options = ParserOptions.defaults();
    var stream = EnvStream.init("#comment\nKEY=value");

    var pair = EnvPair.init(testing.allocator);
    defer pair.deinit();

    const result = try readPair(testing.allocator, &stream, &pair, default_options);

    try testing.expectEqual(ReadResult.comment_encountered, result);
}

test "readPairs multiple pairs" {
    var stream = EnvStream.init("KEY1=value1\nKEY2=value2\nKEY3=value3");

    var pairs = try readPairs(testing.allocator, &stream);
    defer {
        for (pairs.items) |*pair| {
            pair.deinit();
        }
        pairs.deinit(testing.allocator);
    }

    try testing.expectEqual(@as(usize, 3), pairs.items.len);
    try testing.expectEqualStrings("KEY1", pairs.items[0].key.key);
    try testing.expectEqualStrings("value1", pairs.items[0].value.value);
    try testing.expectEqualStrings("KEY2", pairs.items[1].key.key);
    try testing.expectEqualStrings("value2", pairs.items[1].value.value);
    try testing.expectEqualStrings("KEY3", pairs.items[2].key.key);
    try testing.expectEqualStrings("value3", pairs.items[2].value.value);
}

test "readPairs with comments" {
    var stream = EnvStream.init("#comment\nKEY1=value1\n#another comment\nKEY2=value2");

    var pairs = try readPairs(testing.allocator, &stream);
    defer {
        for (pairs.items) |*pair| {
            pair.deinit();
        }
        pairs.deinit(testing.allocator);
    }

    try testing.expectEqual(@as(usize, 2), pairs.items.len);
    try testing.expectEqualStrings("KEY1", pairs.items[0].key.key);
    try testing.expectEqualStrings("KEY2", pairs.items[1].key.key);
}

test "readPairs with empty lines" {
    var stream = EnvStream.init("KEY1=value1\n\nKEY2=value2");

    var pairs = try readPairs(testing.allocator, &stream);
    defer {
        for (pairs.items) |*pair| {
            pair.deinit();
        }
        pairs.deinit(testing.allocator);
    }

    // Empty lines should be skipped as fail (in loop) or handled
    try testing.expect(pairs.items.len >= 2);
}

test "readPairs windows line endings" {
    var stream = EnvStream.init("KEY1=value1\r\nKEY2=value2\r\n");

    var pairs = try readPairs(testing.allocator, &stream);
    defer {
        for (pairs.items) |*pair| {
            pair.deinit();
        }
        pairs.deinit(testing.allocator);
    }

    try testing.expectEqual(@as(usize, 2), pairs.items.len);
    try testing.expectEqualStrings("KEY1", pairs.items[0].key.key);
    try testing.expectEqualStrings("KEY2", pairs.items[1].key.key);
}

test "readPairs empty stream" {
    var stream = EnvStream.init("");

    var pairs = try readPairs(testing.allocator, &stream);
    defer {
        for (pairs.items) |*pair| {
            pair.deinit();
        }
        pairs.deinit(testing.allocator);
    }

    try testing.expectEqual(@as(usize, 0), pairs.items.len);
}
