const std = @import("std");
const EnvValue = @import("env_value.zig").EnvValue;
const VariablePosition = @import("variable_position.zig").VariablePosition;
const whitespace_utils = @import("whitespace_utils.zig");

/// Search backward from current position to find `$` that precedes `{`.
/// Returns position of `$` or null if not found or if escaped.
/// Called AFTER '{' is added to buffer, so we start from value_index - 2 to skip the '{'.
pub fn positionOfDollarLastSign(value: *const EnvValue) ?usize {
    if (value.value_index < 2) {
        return null;
    }

    // value.value_index is where the NEXT char will go.
    // value_index - 1 is the '{' that was just added.
    // So we start searching from value_index - 2.

    // Using isize for calculation to avoid underflow
    var tmp: isize = @as(isize, @intCast(value.value_index)) - 2;

    while (tmp >= 0) {
        const u_tmp = @as(usize, @intCast(tmp));
        if (value.value[u_tmp] == '$') {
            // Check for explicit escape recorded during parsing
            if (value.escaped_dollar_index) |esc_idx| {
                if (u_tmp == esc_idx) return null;
            }
            // Check for literal backslash check (still useful for some cases)
            if (u_tmp > 0 and value.value[u_tmp - 1] == '\\') {
                return null; // escaped $
            }
            return u_tmp;
        }
        if (value.value[u_tmp] == ' ') {
            tmp -= 1;
            continue; // skip whitespace between $ and {
        }
        return null; // non-whitespace (other than '{') between $ and {
    }
    return null;
}

/// Called when `{` is encountered; start tracking a new variable interpolation.
pub fn openVariable(allocator: std.mem.Allocator, value: *EnvValue) !void {
    _ = allocator;
    const dollar_pos_opt = positionOfDollarLastSign(value);

    if (dollar_pos_opt) |dollar_pos| {
        value.is_parsing_variable = true;

        // Create VariablePosition (by value, as ArrayList stores struct)
        // Create VariablePosition
        const new_pos = VariablePosition.init(value.value_index, value.value_index - 1, dollar_pos);

        try value.interpolations.append(value.buffer.allocator, new_pos);
    }
}

/// Called when first char of variable name is encountered in braceless mode (e.g. $VAR)
/// Assumes pre-checks (unquoted/double-quoted, previous char was $) are done by caller.
pub fn openBracelessVariable(allocator: std.mem.Allocator, value: *EnvValue) !void {
    _ = allocator;
    // We assume caller verified previous char is $
    // value.value_index points to where the current/next char will be written.
    // Previous char (value_index - 1) is $.
    const dollar_pos = value.value_index - 1;

    value.is_parsing_braceless_variable = true;

    // start_brace is just used as boundary for whitespace check.
    // We set it to dollar_pos so checks stop at $.
    // variable_start is where the current char will be written (value.value_index),
    // because processing logic usually adds the char to buffer AFTER calling open logic
    // (if done in `readNextChar` before specific char handling).
    // OR if existing logic adds $ then processes next char:
    // If we call this when processing 'V', 'V' is NOT yet in buffer.
    // So variable_start = value.value_index.
    const new_pos = VariablePosition.init(value.value_index, dollar_pos, dollar_pos);

    try value.interpolations.append(value.buffer.allocator, new_pos);
}

/// Called when `}` is encountered; finalize the current variable interpolation.
pub fn closeVariable(allocator: std.mem.Allocator, value: *EnvValue) !void {
    value.is_parsing_variable = false;

    // Get the current active interpolation
    // C++: value->interpolations->at(value->interpolation_index)
    if (value.interpolations.items.len <= value.interpolation_index) {
        return; // Should not happen if logic is correct
    }

    const interpolation = &value.interpolations.items[value.interpolation_index];

    interpolation.end_brace = value.value_index - 1;
    // variable_end = value.value_index - 2 (character before })
    if (value.value_index >= 2) {
        interpolation.variable_end = value.value_index - 2;
    } else {
        // Should catch this, but 0 based index...
        interpolation.variable_end = 0;
    }

    // Trim left whitespace
    const left = whitespace_utils.getWhiteSpaceOffsetLeft(value.value, interpolation);
    if (left > 0) {
        interpolation.variable_start += left;
    }

    // Trim right whitespace
    const right = whitespace_utils.getWhiteSpaceOffsetRight(value.value, interpolation);
    if (right > 0) {
        if (interpolation.variable_end >= right) {
            interpolation.variable_end -= right;
        }
    }

    // Extract variable name
    // Length = (end - start) + 1
    // Example: indices 2, 3, 4. end=4, start=2. 4-2+1 = 3.
    if (interpolation.variable_end >= interpolation.variable_start) {
        const len = (interpolation.variable_end - interpolation.variable_start) + 1;
        const start = interpolation.variable_start;
        // Safety check
        if (start + len <= value.value.len) {
            const var_name = value.value[start .. start + len];
            try interpolation.setVariableStr(allocator, var_name);
        }
    }

    interpolation.closed = true;
    value.interpolation_index += 1;
}

/// Called when a non-identifier char is encountered for a braceless variable.
/// The terminating char is NOT yet in the buffer.
pub fn closeBracelessVariable(allocator: std.mem.Allocator, value: *EnvValue) !void {
    value.is_parsing_braceless_variable = false;

    if (value.interpolations.items.len <= value.interpolation_index) {
        return; // Should not happen
    }

    const interpolation = &value.interpolations.items[value.interpolation_index];

    // The previous char added to buffer was the last char of variable name.
    // So end_brace (which we treat as end of token) is value.value_index - 1.
    if (value.value_index > 0) {
        interpolation.end_brace = value.value_index - 1;
        interpolation.variable_end = value.value_index - 1;
    } else {
        // Should catch this
        interpolation.end_brace = 0;
        interpolation.variable_end = 0;
    }

    // No whitespace trimming for braceless variables as they can't contain spaces.

    // Extract variable name
    if (interpolation.variable_end >= interpolation.variable_start) {
        const len = (interpolation.variable_end - interpolation.variable_start) + 1;
        const start = interpolation.variable_start;

        if (start + len <= value.value.len) {
            const var_name = value.value[start .. start + len];
            try interpolation.setVariableStr(allocator, var_name);
        }
    }

    interpolation.closed = true;
    value.interpolation_index += 1;
}

/// After parsing completes, remove any interpolation that wasn't closed with `}`.
pub fn removeUnclosedInterpolation(value: *EnvValue) void {
    var i: usize = value.interpolations.items.len;
    while (i > 0) {
        i -= 1;
        // Check if closed without copying the struct (to avoid double free issues if we were to deinit a copy)
        // But here we just check bool.
        if (!value.interpolations.items[i].closed) {
            // Remove returns the item. We must deinit it.
            var removed_item = value.interpolations.orderedRemove(i);
            removed_item.deinit();

            // If we remove one before interpolation_index, we should decrement index
            if (i < value.interpolation_index) {
                value.interpolation_index -= 1;
            }
        }
    }
}

test "positionOfDollarLastSign basic" {
    var val = EnvValue.init(std.testing.allocator);
    defer val.deinit();

    // Simulate content
    // "abc$ {"
    try val.buffer.appendSlice("abc$ ");
    val.value = val.buffer.items;
    val.value_index = val.buffer.items.len;

    // We are at the position where '{' is encountered.
    // So buffer has "$ ". val.value_index is length.

    const pos = positionOfDollarLastSign(&val);
    try std.testing.expect(pos != null);
    try std.testing.expectEqual(@as(usize, 3), pos.?); // 0:a, 1:b, 2:c, 3:$
}

test "positionOfDollarLastSign with escape" {
    var val = EnvValue.init(std.testing.allocator);
    defer val.deinit();

    try val.buffer.appendSlice("abc\\$");
    val.value = val.buffer.items;
    val.value_index = val.buffer.items.len;

    const pos = positionOfDollarLastSign(&val);
    try std.testing.expect(pos == null);
}

test "open and close variable" {
    var val = EnvValue.init(std.testing.allocator);
    defer val.deinit();

    // Parsing "Hello ${name}"
    // 1. "Hello "
    try val.buffer.appendSlice("Hello ");
    val.value_index = val.buffer.items.len;

    // 2. "$"
    try val.buffer.append('$');
    val.value = val.buffer.items;
    val.value_index = val.buffer.items.len;

    // 3. "{" -> openVariable (called after adding)
    try val.buffer.append('{');
    val.value = val.buffer.items;
    val.value_index = val.buffer.items.len;

    try openVariable(std.testing.allocator, &val);

    try std.testing.expect(val.is_parsing_variable);
    try std.testing.expectEqual(@as(usize, 1), val.interpolations.items.len);
    try std.testing.expectEqual(@as(usize, 6), val.interpolations.items[0].dollar_sign); // Hello_ is 6 chars. $ is at 6.

    // 4. "name"
    try val.buffer.appendSlice("name"); // We append name
    val.value = val.buffer.items;
    val.value_index = val.buffer.items.len;

    // 5. "}" -> closeVariable
    // closeVariable
    try val.buffer.append('}');
    val.value = val.buffer.items;
    val.value_index = val.buffer.items.len;

    try closeVariable(std.testing.allocator, &val);

    try std.testing.expect(!val.is_parsing_variable);
    const interp = val.interpolations.items[0];
    try std.testing.expect(interp.closed);
    try std.testing.expectEqualStrings("name", interp.variable_str);
}
