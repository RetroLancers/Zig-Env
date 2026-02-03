const std = @import("std");
const testing = std.testing;
const parser = @import("Zig_Env_lib");

test "double quotes - DoubleQuotes" {
    const allocator = testing.allocator;

    const content = "KEY=\"quoted value\"";

    var env = try parser.parseString(allocator, content);
    defer env.deinit();

    try testing.expectEqualStrings("quoted value", env.get("KEY").?);
}

test "empty double quotes" {
    const allocator = testing.allocator;

    const content = "KEY=\"\"";

    var env = try parser.parseString(allocator, content);
    defer env.deinit();

    try testing.expectEqualStrings("", env.get("KEY").?);
}

test "single quoted - SingleQuoted" {
    const allocator = testing.allocator;

    const content = "KEY='literal \\n ${var}'";

    var env = try parser.parseString(allocator, content);
    defer env.deinit();

    // In single quotes, \n is literal and ${var} is literal
    try testing.expectEqualStrings("literal \\n ${var}", env.get("KEY").?);
}

test "backtick quote - BackTickQuote" {
    const allocator = testing.allocator;

    const content = "KEY=`value`";

    var env = try parser.parseString(allocator, content);
    defer env.deinit();

    try testing.expectEqualStrings("value", env.get("KEY").?);
}
