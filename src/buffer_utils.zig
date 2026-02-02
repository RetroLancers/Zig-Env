const std = @import("std");
const EnvValue = @import("env_value.zig").EnvValue;

/// Add a character to the value buffer, resizing if needed.
/// This implementation relies on std.ArrayList(u8) inside EnvValue.
pub fn addToBuffer(value: *EnvValue, char: u8) !void {
    try value.buffer.append(char);
    // Sync the value slice and index
    value.value = value.buffer.items;
    value.value_index = value.buffer.items.len;
}

/// Check if the character 2 positions back is a backslash.
/// Used for detecting escaped { and } in variable interpolation.
pub fn isPreviousCharAnEscape(value: *const EnvValue) bool {
    // value_index is the position where the next character will be written.
    // So value_index - 1 is the last character written.
    // value_index - 2 is the character before that.
    return value.value_index > 1 and value.buffer.items[value.value_index - 2] == '\\';
}

test "addToBuffer" {
    const allocator = std.testing.allocator;
    var val = EnvValue.init(allocator);
    defer val.deinit(allocator);

    try addToBuffer(&val, 'a');
    try addToBuffer(&val, 'b');
    try addToBuffer(&val, 'c');

    try std.testing.expectEqualStrings("abc", val.value);
    try std.testing.expectEqual(@as(usize, 3), val.value_index);
}

test "isPreviousCharAnEscape" {
    const allocator = std.testing.allocator;
    var val = EnvValue.init(allocator);
    defer val.deinit(allocator);

    try addToBuffer(&val, '\\');
    try addToBuffer(&val, '{');
    
    // index is 2. char at index 0 is \, char at index 1 is {.
    // isPreviousCharAnEscape checks index [2-2] = 0.
    try std.testing.expect(isPreviousCharAnEscape(&val));

    var val2 = EnvValue.init(allocator);
    defer val2.deinit(allocator);
    try addToBuffer(&val2, 'a');
    try addToBuffer(&val2, '{');
    try std.testing.expect(!isPreviousCharAnEscape(&val2));
}
