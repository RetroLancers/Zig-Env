const std = @import("std");
const EnvPair = @import("env_pair.zig").EnvPair;
const FinalizeResult = @import("result_enums.zig").FinalizeResult;
const VariablePosition = @import("variable_position.zig").VariablePosition;

/// Finalizes all values in the provided list of pairs.
pub fn finalizeAllValues(allocator: std.mem.Allocator, pairs: *std.ArrayList(EnvPair)) !void {
    for (pairs.items) |*pair| {
        _ = try finalizeValue(allocator, pair, pairs);
    }
}

/// Recursively finalizes a single value, resolving all variable interpolations.
pub fn finalizeValue(allocator: std.mem.Allocator, pair: *EnvPair, pairs: *std.ArrayList(EnvPair)) !FinalizeResult {
    if (pair.value.is_already_interpolated) {
        return .copied;
    }

    if (pair.value.is_being_interpolated) {
        return .circular;
    }

    if (pair.value.interpolations.items.len == 0) {
        pair.value.is_already_interpolated = true;
        return .copied;
    }

    pair.value.is_being_interpolated = true;
    defer pair.value.is_being_interpolated = false;

    var result_status = FinalizeResult.copied;
    var found_circular = false;

    // Process interpolations in REVERSE order to keep earlier positions valid
    var i: usize = pair.value.interpolations.items.len;
    while (i > 0) {
        i -= 1;
        const interp = pair.value.interpolations.items[i];

        const var_name = interp.variable_str;

        // Find matching key in pairs
        if (findPairByKey(pairs, var_name)) |referenced_pair| {
            // Recursively finalize the referenced value
            const res = try finalizeValue(allocator, referenced_pair, pairs);

            if (res == .circular) {
                found_circular = true;
            } else {
                // Replace the interpolation with the value
                try replaceInterpolation(allocator, pair, i, referenced_pair.value.value);
                result_status = .interpolated;
            }
        }
        // If not found, we leave the ${var} as is, per requirements.
    }

    pair.value.is_already_interpolated = true;
    if (found_circular) return .circular;
    return if (result_status == .interpolated) .interpolated else .copied;
}

fn findPairByKey(pairs: *std.ArrayList(EnvPair), key: []const u8) ?*EnvPair {
    for (pairs.items) |*pair| {
        if (std.mem.eql(u8, pair.key.key, key)) {
            return pair;
        }
    }
    return null;
}

fn replaceInterpolation(allocator: std.mem.Allocator, pair: *EnvPair, interp_idx: usize, replacement: []const u8) !void {
    _ = allocator;
    const interp = pair.value.interpolations.items[interp_idx];

    const old_val = pair.value.value;
    const prefix = old_val[0..interp.dollar_sign];
    const suffix = old_val[interp.end_brace + 1 ..];

    const new_len = prefix.len + replacement.len + suffix.len;
    const value_allocator = pair.value.buffer.allocator;
    var new_buffer = try value_allocator.alloc(u8, new_len);
    errdefer value_allocator.free(new_buffer);

    @memcpy(new_buffer[0..prefix.len], prefix);
    @memcpy(new_buffer[prefix.len .. prefix.len + replacement.len], replacement);
    @memcpy(new_buffer[prefix.len + replacement.len ..], suffix);

    // Update the value's buffer
    pair.value.setOwnBuffer(new_buffer);

    // We don't need to update other interpolation positions because we process in reverse.
    // However, we should probably remove the interpolation we just processed.
    // The C++ version might handle this differently, but since we are done with this one,
    // and we process in reverse, it's fine to leave it or remove it.
    // Actually, if we remove it, the index 'i' in finalizeValue loop will still be correct because it's decreasing.
    var removed = pair.value.interpolations.orderedRemove(interp_idx);
    removed.deinit();
}

test "finalizeValue - basic substitution" {
    const allocator = std.testing.allocator;
    var pairs = std.ArrayList(EnvPair){};
    defer {
        for (pairs.items) |*p| p.deinit();
        pairs.deinit(allocator);
    }

    var p1 = EnvPair.init(allocator);
    p1.key.key = "VAR";
    p1.value.value = "hello";
    try pairs.append(allocator, p1);

    var p2 = EnvPair.init(allocator);
    p2.key.key = "REF";
    p2.value.value = "${VAR} world";
    var vp_ref = VariablePosition.init(0, 1, 0);
    vp_ref.end_brace = 5;
    try vp_ref.setVariableStr(allocator, "VAR");
    try p2.value.interpolations.append(allocator, vp_ref);
    try pairs.append(allocator, p2);

    const res = try finalizeValue(allocator, &pairs.items[1], &pairs);
    try std.testing.expect(res == .interpolated);
    try std.testing.expectEqualStrings("hello world", pairs.items[1].value.value);
}

test "finalizeValue - recursive substitution" {
    const allocator = std.testing.allocator;
    var pairs = std.ArrayList(EnvPair){};
    defer {
        for (pairs.items) |*p| p.deinit();
        pairs.deinit(allocator);
    }

    // A=${B}
    var p1 = EnvPair.init(allocator);
    p1.key.key = "A";
    p1.value.value = "${B}";
    var vp_a1 = VariablePosition.init(0, 1, 0);
    vp_a1.end_brace = 3;
    try vp_a1.setVariableStr(allocator, "B");
    try p1.value.interpolations.append(allocator, vp_a1);
    try pairs.append(allocator, p1);

    // B=${C}
    var p2 = EnvPair.init(allocator);
    p2.key.key = "B";
    p2.value.value = "${C}";
    var vp_b1 = VariablePosition.init(0, 1, 0);
    vp_b1.end_brace = 3;
    try vp_b1.setVariableStr(allocator, "C");
    try p2.value.interpolations.append(allocator, vp_b1);
    try pairs.append(allocator, p2);

    // C=final
    var p3 = EnvPair.init(allocator);
    p3.key.key = "C";
    p3.value.value = "final";
    try pairs.append(allocator, p3);

    const res = try finalizeValue(allocator, &pairs.items[0], &pairs);
    try std.testing.expect(res == .interpolated);
    try std.testing.expectEqualStrings("final", pairs.items[0].value.value);
    try std.testing.expectEqualStrings("final", pairs.items[1].value.value);
}

test "finalizeValue - circular dependency" {
    const allocator = std.testing.allocator;
    var pairs = std.ArrayList(EnvPair){};
    defer {
        for (pairs.items) |*p| p.deinit();
        pairs.deinit(allocator);
    }

    // A=${B}
    var p1 = EnvPair.init(allocator);
    p1.key.key = "A";
    p1.value.value = "${B}";
    var vp_a2 = VariablePosition.init(0, 1, 0);
    vp_a2.end_brace = 3;
    try vp_a2.setVariableStr(allocator, "B");
    try p1.value.interpolations.append(allocator, vp_a2);
    try pairs.append(allocator, p1);

    // B=${A}
    var p2 = EnvPair.init(allocator);
    p2.key.key = "B";
    p2.value.value = "${A}";
    var vp_b2 = VariablePosition.init(0, 1, 0);
    vp_b2.end_brace = 3;
    try vp_b2.setVariableStr(allocator, "A");
    try p2.value.interpolations.append(allocator, vp_b2);
    try pairs.append(allocator, p2);

    const res = try finalizeValue(allocator, &pairs.items[0], &pairs);
    // When circular, it should return circular and keep the original string
    try std.testing.expect(res == .circular);
    try std.testing.expectEqualStrings("${B}", pairs.items[0].value.value);
}

test "finalizeValue - missing variable" {
    const allocator = std.testing.allocator;
    var pairs = std.ArrayList(EnvPair){};
    defer {
        for (pairs.items) |*p| p.deinit();
        pairs.deinit(allocator);
    }

    var p1 = EnvPair.init(allocator);
    p1.key.key = "A";
    p1.value.value = "${MISSING}";
    var vp_missing = VariablePosition.init(0, 1, 0);
    vp_missing.end_brace = 9;
    try vp_missing.setVariableStr(allocator, "MISSING");
    try p1.value.interpolations.append(allocator, vp_missing);
    try pairs.append(allocator, p1);

    const res = try finalizeValue(allocator, &pairs.items[0], &pairs);
    try std.testing.expect(res == .copied);
    try std.testing.expectEqualStrings("${MISSING}", pairs.items[0].value.value);
}

test "finalizeValue - multiple interpolations in reverse order" {
    const allocator = std.testing.allocator;
    var pairs = std.ArrayList(EnvPair){};
    defer {
        for (pairs.items) |*p| p.deinit();
        pairs.deinit(allocator);
    }

    var p1 = EnvPair.init(allocator);
    p1.key.key = "A";
    p1.value.value = "1";
    try pairs.append(allocator, p1);

    var p2 = EnvPair.init(allocator);
    p2.key.key = "B";
    p2.value.value = "2";
    try pairs.append(allocator, p2);

    var p3 = EnvPair.init(allocator);
    p3.key.key = "C";
    p3.value.value = "${A}${B}";
    var vp_a = VariablePosition.init(0, 1, 0);
    vp_a.end_brace = 3;
    try vp_a.setVariableStr(allocator, "A");
    try p3.value.interpolations.append(allocator, vp_a); // ${A}
    var vp_b = VariablePosition.init(4, 5, 4);
    vp_b.end_brace = 7;
    try vp_b.setVariableStr(allocator, "B");
    try p3.value.interpolations.append(allocator, vp_b); // ${B}
    try pairs.append(allocator, p3);

    const res = try finalizeValue(allocator, &pairs.items[2], &pairs);
    try std.testing.expect(res == .interpolated);
    try std.testing.expectEqualStrings("12", pairs.items[2].value.value);
}

test "finalizeValue - indirect circular dependency" {
    const allocator = std.testing.allocator;
    var pairs = std.ArrayList(EnvPair){};
    defer {
        for (pairs.items) |*p| p.deinit();
        pairs.deinit(allocator);
    }

    // A=${B}
    var p1 = EnvPair.init(allocator);
    p1.key.key = "A";
    p1.value.value = "${B}";
    var vp_a = VariablePosition.init(0, 1, 0);
    vp_a.end_brace = 3;
    try vp_a.setVariableStr(allocator, "B");
    try p1.value.interpolations.append(allocator, vp_a);
    try pairs.append(allocator, p1);

    // B=${C}
    var p2 = EnvPair.init(allocator);
    p2.key.key = "B";
    p2.value.value = "${C}";
    var vp_b = VariablePosition.init(0, 1, 0);
    vp_b.end_brace = 3;
    try vp_b.setVariableStr(allocator, "C");
    try p2.value.interpolations.append(allocator, vp_b);
    try pairs.append(allocator, p2);

    // C=${A}
    var p3 = EnvPair.init(allocator);
    p3.key.key = "C";
    p3.value.value = "${A}";
    var vp_c = VariablePosition.init(0, 1, 0);
    vp_c.end_brace = 3;
    try vp_c.setVariableStr(allocator, "A");
    try p3.value.interpolations.append(allocator, vp_c);
    try pairs.append(allocator, p3);

    const res = try finalizeValue(allocator, &pairs.items[0], &pairs);
    try std.testing.expect(res == .circular);
    try std.testing.expectEqualStrings("${B}", pairs.items[0].value.value);
}

test "finalizeValue - same variable twice" {
    const allocator = std.testing.allocator;
    var pairs = std.ArrayList(EnvPair){};
    defer {
        for (pairs.items) |*p| p.deinit();
        pairs.deinit(allocator);
    }

    var p1 = EnvPair.init(allocator);
    p1.key.key = "A";
    p1.value.value = "1";
    try pairs.append(allocator, p1);

    var p2 = EnvPair.init(allocator);
    p2.key.key = "B";
    p2.value.value = "${A}${A}";
    var vp1 = VariablePosition.init(0, 1, 0);
    vp1.end_brace = 3;
    try vp1.setVariableStr(allocator, "A");
    try p2.value.interpolations.append(allocator, vp1);
    var vp2 = VariablePosition.init(4, 5, 4);
    vp2.end_brace = 7;
    try vp2.setVariableStr(allocator, "A");
    try p2.value.interpolations.append(allocator, vp2);
    try pairs.append(allocator, p2);

    const res = try finalizeValue(allocator, &pairs.items[1], &pairs);
    try std.testing.expect(res == .interpolated);
    try std.testing.expectEqualStrings("11", pairs.items[1].value.value);
}
