const std = @import("std");
const EnvStream = @import("env_stream.zig").EnvStream;
const EnvKey = @import("env_key.zig").EnvKey;
const ReadResult = @import("result_enums.zig").ReadResult;
const EnvValue = @import("env_value.zig").EnvValue;
const buffer_utils = @import("buffer_utils.zig");
const escape_processor = @import("escape_processor.zig");
const quote_parser = @import("quote_parser.zig");
const interpolation = @import("interpolation.zig");
const testing = std.testing;
const memory = @import("memory.zig");

pub fn clearGarbage(stream: *EnvStream) void {
    while (true) {
        const char_opt = stream.get();
        if (char_opt == null) break;
        if (!stream.good()) break;
        if (char_opt.? == '\n') break;
    }
}

pub fn readNextChar(allocator: std.mem.Allocator, value: *EnvValue, char: u8) !bool {
    // Handle pending backslash streak (if not in single quote mode and current char is not backslash)
    if (!value.quoted and !value.triple_quoted and value.back_slash_streak > 0) {
        if (char != '\\') {
            try escape_processor.walkBackSlashes(value);
            if (value.back_slash_streak == 1) {
                value.back_slash_streak = 0;
                if (try escape_processor.processPossibleControlCharacter(value, char)) {
                    return true;
                }
                try buffer_utils.addToBuffer(value, '\\');
            }
        }
    }

    // Handle pending single quote streak (if not in double quote mode and current char is not single quote)
    if (!value.triple_double_quoted and !value.double_quoted and value.single_quote_streak > 0) {
        if (char != '\'') {
            if (try quote_parser.walkSingleQuotes(value)) {
                return false;
            }
        }
    }

    // Handle pending double quote streak (if not in single quote mode and current char is not double quote)
    if (!value.triple_quoted and !value.quoted and value.double_quote_streak > 0) {
        if (char != '"') {
            if (try quote_parser.walkDoubleQuotes(value)) {
                return false;
            }
        }
    }

    // Handle first character special cases
    if (value.value_index == 0) {
        if (char == '`') {
            if (value.backtick_quoted) {
                return false;
            }
            if (!value.quoted and !value.triple_quoted and !value.double_quoted and !value.triple_double_quoted) {
                value.double_quoted = true;
                value.backtick_quoted = true;
                return true;
            }
        }

        if (char == '#') {
            if (!value.quoted and !value.triple_quoted and !value.double_quoted and !value.triple_double_quoted) {
                return false;
            }
        } else if (char != '"' and char != '\'') {
            if (!value.quoted and !value.triple_quoted and !value.double_quoted and !value.triple_double_quoted) {
                value.double_quoted = true;
                value.implicit_double_quote = true;
            }
        }
        if (char == ' ' and value.implicit_double_quote) {
            return true; // trim left on implicit quotes
        }
    }

    // Process current character
    switch (char) {
        '`' => {
            if (value.backtick_quoted) {
                return false;
            }
            try buffer_utils.addToBuffer(value, char);
        },
        '#' => {
            if (value.implicit_double_quote) {
                return false;
            }
            try buffer_utils.addToBuffer(value, char);
        },
        '\n' => {
            if (!(value.triple_double_quoted or value.triple_quoted or (value.double_quoted and !value.implicit_double_quote))) {
                if (value.value_index > 0) {
                    if (value.value[value.value_index - 1] == '\r') {
                        value.value_index -= 1;
                    }
                }
                return false;
            }
            try buffer_utils.addToBuffer(value, char);
            return true;
        },
        '\\' => {
            if (value.quoted or value.triple_quoted) {
                try buffer_utils.addToBuffer(value, char);
                return true;
            }
            value.back_slash_streak += 1;
            return true;
        },
        '{' => {
            try buffer_utils.addToBuffer(value, char);
            if (!value.quoted and !value.triple_quoted) {
                if (!value.is_parsing_variable) {
                    if (!buffer_utils.isPreviousCharAnEscape(value)) {
                        try interpolation.openVariable(allocator, value);
                    }
                }
            }
            return true;
        },
        '}' => {
            try buffer_utils.addToBuffer(value, char);
            if (value.is_parsing_variable) {
                if (!buffer_utils.isPreviousCharAnEscape(value)) {
                    try interpolation.closeVariable(allocator, value);
                }
            }
            return true;
        },
        '\'' => {
            if (!value.double_quoted and !value.triple_double_quoted) {
                value.single_quote_streak += 1;
            } else {
                try buffer_utils.addToBuffer(value, char);
            }
            return true;
        },
        '"' => {
            if (!value.quoted and !value.triple_quoted and !value.backtick_quoted and !value.implicit_double_quote) {
                value.double_quote_streak += 1;
            } else {
                try buffer_utils.addToBuffer(value, char);
            }
            return true;
        },
        else => {
            try buffer_utils.addToBuffer(value, char);
        },
    }
    return true;
}

pub fn readKey(stream: *EnvStream, key: *EnvKey) !ReadResult {
    if (!stream.good()) return ReadResult.end_of_stream_key;

    while (stream.good()) {
        const char_opt = stream.get();
        if (char_opt == null) break;
        const key_char = char_opt.?;

        if (key_char == '#') {
            clearGarbage(stream);
            return ReadResult.comment_encountered;
        }

        switch (key_char) {
            ' ' => {
                if (key.key_index == 0) continue; // left trim
                try key.buffer.append(key_char);
                key.key_index += 1;
            },
            '=' => {
                key.key = key.buffer.items;
                // If we are at EOF immediately after '=', we can't read value.
                if (stream.eof()) return ReadResult.end_of_stream_value;
                return ReadResult.success;
            },
            '\r' => continue,
            '\n' => {
                return ReadResult.fail;
            },
            else => {
                try key.buffer.append(key_char);
                key.key_index += 1;
            },
        }

        key.key = key.buffer.items;
    }

    return ReadResult.end_of_stream_key;
}

pub fn readValue(allocator: std.mem.Allocator, stream: *EnvStream, value: *EnvValue) !ReadResult {
    if (!stream.good()) return ReadResult.end_of_stream_value;

    var key_char: u8 = 0;
    while (stream.good()) {
        const char_opt = stream.get();
        if (char_opt == null) break;
        key_char = char_opt.?;

        if (try readNextChar(allocator, value, key_char) and stream.good()) {
            continue;
        }
        break;
    }

    // End-of-value cleanup
    if (value.back_slash_streak > 0) {
        try escape_processor.walkBackSlashes(value);
        if (value.back_slash_streak == 1) {
            _ = try escape_processor.processPossibleControlCharacter(value, '\x00');
        }
    }

    if (value.single_quote_streak > 0) {
        if (try quote_parser.walkSingleQuotes(value)) {
            if (key_char != '\n') {
                clearGarbage(stream);
            }
        }
    }

    if ((value.triple_double_quoted or value.triple_quoted) and key_char != '\n') {
        clearGarbage(stream);
    }

    if (value.double_quote_streak > 0) {
        if (try quote_parser.walkDoubleQuotes(value)) {
            if (key_char != '\n') {
                clearGarbage(stream);
            }
        }
    }

    // Trim right side of implicit double quote
    if (value.implicit_double_quote) {
        while (value.value_index > 0 and value.value[value.value_index - 1] == ' ') {
            value.value_index -= 1;
        }
    }

    return ReadResult.success;
}

pub fn readPair(allocator: std.mem.Allocator, stream: *EnvStream, pair: *EnvPair) !ReadResult {
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
    const value_result = try readValue(allocator, stream, &pair.value);
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

const EnvPair = @import("env_pair.zig").EnvPair;

pub fn readPairs(allocator: std.mem.Allocator, stream: *EnvStream) !std.ArrayList(EnvPair) {
    var pairs = std.ArrayList(EnvPair){};
    errdefer memory.deletePairs(allocator, &pairs);

    while (true) {
        var pair = EnvPair.init(allocator);

        const result = try readPair(allocator, stream, &pair);
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

test "clearGarbage clears to newline" {
    var stream = EnvStream.init("garbage\nnext");

    clearGarbage(&stream);

    const next = stream.get();
    try testing.expectEqual(@as(?u8, 'n'), next);
}

test "clearGarbage handles EOF" {
    var stream = EnvStream.init("garbage");

    clearGarbage(&stream);

    try testing.expect(!stream.good());
}

test "readKey simple key" {
    var stream = EnvStream.init("KEY=value");

    var key = EnvKey.init(testing.allocator);
    defer key.deinit();

    const result = try readKey(&stream, &key);

    try testing.expectEqual(ReadResult.success, result);
    try testing.expectEqualStrings("KEY", key.key);
}

test "readKey leading spaces" {
    var stream = EnvStream.init("  SPACED_KEY=value");

    var key = EnvKey.init(testing.allocator);
    defer key.deinit();

    const result = try readKey(&stream, &key);

    try testing.expectEqual(ReadResult.success, result);
    try testing.expectEqualStrings("SPACED_KEY", key.key);
}

test "readKey internal spaces" {
    var stream = EnvStream.init("my key=value");

    var key = EnvKey.init(testing.allocator);
    defer key.deinit();

    const result = try readKey(&stream, &key);

    try testing.expectEqual(ReadResult.success, result);
    try testing.expectEqualStrings("my key", key.key);
}

test "readKey comment line" {
    var stream = EnvStream.init("#comment\nnext");

    var key = EnvKey.init(testing.allocator);
    defer key.deinit();

    const result = try readKey(&stream, &key);

    try testing.expectEqual(ReadResult.comment_encountered, result);
    try testing.expectEqualStrings("", key.key);

    // clearGarbage consumes until newline, so next char should be 'n' from "next"
    const next = stream.get();
    try testing.expectEqual(@as(?u8, 'n'), next);
}

test "readKey invalid key" {
    var stream = EnvStream.init("INVALID\n");

    var key = EnvKey.init(testing.allocator);
    defer key.deinit();

    const result = try readKey(&stream, &key);

    try testing.expectEqual(ReadResult.fail, result);
}

test "readKey windows line endings" {
    var stream = EnvStream.init("KEY\r=value");

    var key = EnvKey.init(testing.allocator);
    defer key.deinit();

    const result = try readKey(&stream, &key);
    try testing.expectEqual(ReadResult.success, result);
    try testing.expectEqualStrings("KEY", key.key);
}

test "readKey EOF during key" {
    var stream = EnvStream.init("INCOMPLETE");

    var key = EnvKey.init(testing.allocator);
    defer key.deinit();

    const result = try readKey(&stream, &key);

    try testing.expectEqual(ReadResult.end_of_stream_key, result);
    try testing.expectEqualStrings("INCOMPLETE", key.key);
}

test "readNextChar basic" {
    var val = EnvValue.init(testing.allocator);
    defer val.deinit();

    // 'a'
    const cont = try readNextChar(testing.allocator, &val, 'a');
    try testing.expect(cont);
    try testing.expectEqualStrings("a", val.value);
}

test "readNextChar implicit double quote" {
    var val = EnvValue.init(testing.allocator);
    defer val.deinit();

    // First char 'a' -> implicit double quote
    _ = try readNextChar(testing.allocator, &val, 'a');
    try testing.expect(val.implicit_double_quote);
    try testing.expect(val.double_quoted);
}

test "readNextChar backtick" {
    var val = EnvValue.init(testing.allocator);
    defer val.deinit();

    // `
    _ = try readNextChar(testing.allocator, &val, '`');
    try testing.expect(val.backtick_quoted);
    try testing.expect(val.double_quoted);
    // Opening backtick sets the mode but is not added to buffer
}

test "readNextChar comment" {
    var val = EnvValue.init(testing.allocator);
    defer val.deinit();

    // #
    const cont = try readNextChar(testing.allocator, &val, '#');
    try testing.expect(!cont);
}

test "readNextChar quotes" {
    var val = EnvValue.init(testing.allocator);
    defer val.deinit();

    // '
    _ = try readNextChar(testing.allocator, &val, '\'');
    // Not quoted yet, still in streak
    try testing.expect(!val.quoted);

    // val - this triggers the walk
    _ = try readNextChar(testing.allocator, &val, 'v');
    try testing.expect(val.quoted);
    try testing.expectEqualStrings("v", val.value);

    // ' -> closing quote starts streak
    const cont = try readNextChar(testing.allocator, &val, '\'');
    try testing.expect(cont);

    // any other char -> triggers the walk that returns false
    const cont2 = try readNextChar(testing.allocator, &val, ' ');
    try testing.expect(!cont2);
    try testing.expectEqualStrings("v", val.value);
}

test "readNextChar double quotes" {
    var val = EnvValue.init(testing.allocator);
    defer val.deinit();

    // "
    _ = try readNextChar(testing.allocator, &val, '"');
    try testing.expect(!val.double_quoted);

    // v - this triggers the walk
    _ = try readNextChar(testing.allocator, &val, 'v');
    try testing.expect(val.double_quoted);
    try testing.expectEqualStrings("v", val.value);

    // " -> closing quote starts streak
    const cont = try readNextChar(testing.allocator, &val, '"');
    try testing.expect(cont);

    // any other char -> triggers the walk that returns false
    const cont2 = try readNextChar(testing.allocator, &val, ' ');
    try testing.expect(!cont2);
    try testing.expectEqualStrings("v", val.value);
}

test "readNextChar escape" {
    var val = EnvValue.init(testing.allocator);
    defer val.deinit();

    // \
    _ = try readNextChar(testing.allocator, &val, '\\');
    try testing.expectEqual(@as(usize, 1), val.back_slash_streak);
    try testing.expectEqualStrings("", val.value); // Not added yet

    // n -> \n
    const cont = try readNextChar(testing.allocator, &val, 'n');
    try testing.expect(cont);
    try testing.expectEqual(@as(usize, 0), val.back_slash_streak);
    try testing.expectEqualStrings("\n", val.value);
}

test "readNextChar interpolation" {
    var val = EnvValue.init(testing.allocator);
    defer val.deinit();

    // IMPLICIT quotes because start with non-quote
    // a
    _ = try readNextChar(testing.allocator, &val, 'a');
    try testing.expect(val.implicit_double_quote);

    // $
    _ = try readNextChar(testing.allocator, &val, '$');

    // {
    _ = try readNextChar(testing.allocator, &val, '{');
    try testing.expect(val.is_parsing_variable);
    try testing.expectEqualStrings("a${", val.value);

    // b
    _ = try readNextChar(testing.allocator, &val, 'b');

    // }
    _ = try readNextChar(testing.allocator, &val, '}');
    try testing.expect(!val.is_parsing_variable);
    try testing.expectEqualStrings("a${b}", val.value);

    try testing.expectEqual(@as(usize, 1), val.interpolations.items.len);
}

// Tests for readValue
test "readValue simple value" {
    var stream = EnvStream.init("simple");

    var val = EnvValue.init(testing.allocator);
    defer val.deinit();

    const result = try readValue(testing.allocator, &stream, &val);

    try testing.expectEqual(ReadResult.success, result);
    try testing.expectEqual(@as(usize, 6), val.value_index);
}

test "readValue quoted value" {
    var stream = EnvStream.init("\"quoted value\"");

    var val = EnvValue.init(testing.allocator);
    defer val.deinit();

    const result = try readValue(testing.allocator, &stream, &val);

    try testing.expectEqual(ReadResult.success, result);
    try testing.expect(val.double_quoted);
}

test "readValue with escape" {
    var stream = EnvStream.init("test\\nvalue");

    var val = EnvValue.init(testing.allocator);
    defer val.deinit();

    const result = try readValue(testing.allocator, &stream, &val);

    try testing.expectEqual(ReadResult.success, result);
    try testing.expect(val.value_index > 0);
}

test "readValue implicit double quote trimming" {
    var stream = EnvStream.init("value  ");

    var val = EnvValue.init(testing.allocator);
    defer val.deinit();

    const result = try readValue(testing.allocator, &stream, &val);

    try testing.expectEqual(ReadResult.success, result);
    try testing.expect(val.implicit_double_quote);
    // Value should be trimmed on the right
    try testing.expectEqual(@as(usize, 5), val.value_index);
}

test "readValue with interpolation" {
    var stream = EnvStream.init("a${b}c");

    var val = EnvValue.init(testing.allocator);
    defer val.deinit();

    const result = try readValue(testing.allocator, &stream, &val);

    try testing.expectEqual(ReadResult.success, result);
    try testing.expectEqual(@as(usize, 1), val.interpolations.items.len);
}

// Tests for readPair
test "readPair simple pair" {
    var stream = EnvStream.init("KEY=value");

    var pair = EnvPair.init(testing.allocator);
    defer pair.deinit();

    const result = try readPair(testing.allocator, &stream, &pair);

    try testing.expectEqual(ReadResult.success, result);
    try testing.expectEqualStrings("KEY", pair.key.key);
    try testing.expectEqualStrings("value", pair.value.value);
}

test "readPair with whitespace" {
    var stream = EnvStream.init("  KEY  =  value  ");

    var pair = EnvPair.init(testing.allocator);
    defer pair.deinit();

    const result = try readPair(testing.allocator, &stream, &pair);

    try testing.expectEqual(ReadResult.success, result);
    try testing.expectEqualStrings("KEY", pair.key.key);
    // Value should have right trimming if implicit double quote
}

test "readPair with quotes" {
    var stream = EnvStream.init("KEY=\"quoted value\"");

    var pair = EnvPair.init(testing.allocator);
    defer pair.deinit();

    const result = try readPair(testing.allocator, &stream, &pair);

    try testing.expectEqual(ReadResult.success, result);
    try testing.expectEqualStrings("KEY", pair.key.key);
}

test "readPair comment line" {
    var stream = EnvStream.init("#comment\nKEY=value");

    var pair = EnvPair.init(testing.allocator);
    defer pair.deinit();

    const result = try readPair(testing.allocator, &stream, &pair);

    try testing.expectEqual(ReadResult.comment_encountered, result);
}

// Tests for readPairs
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

    // Empty lines should be skipped as fail
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
