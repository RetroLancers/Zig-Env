const std = @import("std");
const testing = std.testing;
const parser = @import("Zig_Env_lib");

test "control codes - ControlCodes" {
    const allocator = testing.allocator;

    // KEY="line1\nline2\ttab"
    const content = "KEY=\"line1\\nline2\\ttab\"";

    var env = try parser.parseString(allocator, content);
    defer env.deinit();

    try testing.expectEqualStrings("line1\nline2\ttab", env.get("KEY").?);
}

test "all control characters" {
    const allocator = testing.allocator;

    const content = "KEY=\"\\n\\t\\r\\b\\f\\v\\a\\\"\\'\\\\\"";

    var env = try parser.parseString(allocator, content);
    defer env.deinit();

    const expected = "\n\t\r\x08\x0C\x0B\x07\"\'\\";
    try testing.expectEqualStrings(expected, env.get("KEY").?);
}
