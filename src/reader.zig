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
            const stop = try quote_parser.walkSingleQuotes(value);
            if (stop) return false;
        }
    }

    // Handle pending double quote streak (if not in single quote mode and current char is not double quote)
    if (!value.triple_quoted and !value.quoted and value.double_quote_streak > 0) {
        if (char != '"') {
            const stop = try quote_parser.walkDoubleQuotes(value);
            if (stop) return false;
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

                // Determine if we should process immediately
                const should_process = (value.quoted or value.triple_quoted) or (value.value_index == value.single_quote_streak - 1);

                if (should_process) {
                    const stop = try quote_parser.walkSingleQuotes(value);
                    if (stop) return false; // Closing quote - don't add to buffer
                }

                // If we reach here, it's an opening quote - add to buffer
                try buffer_utils.addToBuffer(value, char);
            } else {
                try buffer_utils.addToBuffer(value, char);
            }
            return true;
        },
        '"' => {
            if (!value.quoted and !value.triple_quoted and !value.backtick_quoted and !value.implicit_double_quote) {
                value.double_quote_streak += 1;

                // Determine if we should process immediately
                const should_process = (value.double_quoted or value.triple_double_quoted) or (value.value_index == value.double_quote_streak - 1);

                if (should_process) {
                    const stop = try quote_parser.walkDoubleQuotes(value);
                    if (stop) return false; // Closing quote - don't add to buffer
                }

                // If we reach here, it's an opening quote - add to buffer
                try buffer_utils.addToBuffer(value, char);
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
    defer key.deinit(testing.allocator);

    const result = try readKey(&stream, &key);

    try testing.expectEqual(ReadResult.success, result);
    try testing.expectEqualStrings("KEY", key.key);
}

test "readKey leading spaces" {
    var stream = EnvStream.init("  SPACED_KEY=value");

    var key = EnvKey.init(testing.allocator);
    defer key.deinit(testing.allocator);

    const result = try readKey(&stream, &key);

    try testing.expectEqual(ReadResult.success, result);
    try testing.expectEqualStrings("SPACED_KEY", key.key);
}

test "readKey internal spaces" {
    var stream = EnvStream.init("my key=value");

    var key = EnvKey.init(testing.allocator);
    defer key.deinit(testing.allocator);

    const result = try readKey(&stream, &key);

    try testing.expectEqual(ReadResult.success, result);
    try testing.expectEqualStrings("my key", key.key);
}

test "readKey comment line" {
    var stream = EnvStream.init("#comment\nnext");

    var key = EnvKey.init(testing.allocator);
    defer key.deinit(testing.allocator);

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
    defer key.deinit(testing.allocator);

    const result = try readKey(&stream, &key);

    try testing.expectEqual(ReadResult.fail, result);
}

test "readKey windows line endings" {
    var stream = EnvStream.init("KEY\r=value");

    var key = EnvKey.init(testing.allocator);
    defer key.deinit(testing.allocator);

    const result = try readKey(&stream, &key);
    try testing.expectEqual(ReadResult.success, result);
    try testing.expectEqualStrings("KEY", key.key);
}

test "readKey EOF during key" {
    var stream = EnvStream.init("INCOMPLETE");

    var key = EnvKey.init(testing.allocator);
    defer key.deinit(testing.allocator);

    const result = try readKey(&stream, &key);

    try testing.expectEqual(ReadResult.end_of_stream_key, result);
    try testing.expectEqualStrings("INCOMPLETE", key.key);
}

test "readNextChar basic" {
    var val = EnvValue.init(testing.allocator);
    defer val.deinit(testing.allocator);

    // 'a'
    const cont = try readNextChar(testing.allocator, &val, 'a');
    try testing.expect(cont);
    try testing.expectEqualStrings("a", val.value);
}

test "readNextChar implicit double quote" {
    var val = EnvValue.init(testing.allocator);
    defer val.deinit(testing.allocator);

    // First char 'a' -> implicit double quote
    _ = try readNextChar(testing.allocator, &val, 'a');
    try testing.expect(val.implicit_double_quote);
    try testing.expect(val.double_quoted);
}

test "readNextChar backtick" {
    var val = EnvValue.init(testing.allocator);
    defer val.deinit(testing.allocator);

    // `
    _ = try readNextChar(testing.allocator, &val, '`');
    try testing.expect(val.backtick_quoted);
    try testing.expect(val.double_quoted);
    // Opening backtick sets the mode but is not added to buffer
}

test "readNextChar comment" {
    var val = EnvValue.init(testing.allocator);
    defer val.deinit(testing.allocator);

    // #
    const cont = try readNextChar(testing.allocator, &val, '#');
    try testing.expect(!cont);
}

test "readNextChar quotes" {
    var val = EnvValue.init(testing.allocator);
    defer val.deinit(testing.allocator);

    // '
    _ = try readNextChar(testing.allocator, &val, '\'');
    try testing.expect(val.quoted);
    try testing.expectEqualStrings("'", val.value);

    // val
    _ = try readNextChar(testing.allocator, &val, 'v');
    try testing.expectEqualStrings("'v", val.value);

    // ' -> end (stop reading)
    const cont = try readNextChar(testing.allocator, &val, '\'');
    try testing.expect(!cont);
    try testing.expectEqualStrings("'v", val.value);
}

test "readNextChar double quotes" {
    var val = EnvValue.init(testing.allocator);
    defer val.deinit(testing.allocator);

    // "
    _ = try readNextChar(testing.allocator, &val, '"');
    try testing.expect(val.double_quoted);

    // v
    _ = try readNextChar(testing.allocator, &val, 'v');

    // "
    const cont = try readNextChar(testing.allocator, &val, '"');
    try testing.expect(!cont);
    try testing.expectEqualStrings("\"v", val.value);
}

test "readNextChar escape" {
    var val = EnvValue.init(testing.allocator);
    defer val.deinit(testing.allocator);

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
    defer val.deinit(testing.allocator);

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
