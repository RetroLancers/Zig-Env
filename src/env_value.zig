const std = @import("std");
const VariablePosition = @import("variable_position.zig").VariablePosition;

pub const EnvValue = struct {
    value: []const u8,
    interpolations: std.ArrayList(VariablePosition),

    // Parsing state
    is_parsing_variable: bool,
    interpolation_index: usize,

    // Quote tracking flags
    quoted: bool,
    double_quoted: bool,
    backtick_quoted: bool,
    triple_quoted: bool,
    triple_double_quoted: bool,
    implicit_double_quote: bool,

    // Parsing streaks
    single_quote_streak: usize,
    double_quote_streak: usize,
    back_slash_streak: usize,

    // Interpolation state (for resolution)
    is_being_interpolated: bool,
    is_already_interpolated: bool,

    // Buffer management
    buffer: std.ArrayList(u8),
    value_index: usize,

    pub fn init(allocator: std.mem.Allocator) EnvValue {
        return EnvValue{
            .value = "",
            .interpolations = std.ArrayList(VariablePosition).init(allocator),

            .is_parsing_variable = false,
            .interpolation_index = 0,

            .quoted = false,
            .double_quoted = false,
            .backtick_quoted = false,
            .triple_quoted = false,
            .triple_double_quoted = false,
            .implicit_double_quote = false,

            .single_quote_streak = 0,
            .double_quote_streak = 0,
            .back_slash_streak = 0,

            .is_being_interpolated = false,
            .is_already_interpolated = false,

            .buffer = std.ArrayList(u8).init(allocator),
            .value_index = 0,
        };
    }

    pub fn deinit(self: *EnvValue) void {
        for (self.interpolations.items) |*item| {
            item.deinit();
        }
        self.interpolations.deinit();
        self.buffer.deinit();
    }

    pub fn hasOwnBuffer(self: *const EnvValue) bool {
        return self.buffer.items.len > 0;
    }

    /// Takes ownership of the provided buffer.
    /// If there was already an owned buffer, it is freed.
    /// The `value` field is updated to point to the new buffer.
    pub fn setOwnBuffer(self: *EnvValue, buffer: []u8) void {
        const allocator = self.buffer.allocator;
        self.buffer.deinit();
        self.buffer = std.ArrayList(u8).fromOwnedSlice(allocator, buffer);
        self.value = self.buffer.items;
        self.value_index = self.buffer.items.len;
    }

    /// Shrinks the owned buffer to the specified length.
    pub fn clipOwnBuffer(self: *EnvValue, length: usize) !void {
        try self.buffer.resize(length);
        self.value = self.buffer.items;
        self.value_index = self.buffer.items.len;
    }
};

test "EnvValue initialization" {
    const allocator = std.testing.allocator;
    var val = EnvValue.init(allocator);
    defer val.deinit();

    try std.testing.expectEqualStrings("", val.value);
    try std.testing.expect(val.interpolations.items.len == 0);
    try std.testing.expect(!val.quoted);
}

test "EnvValue buffer ownership" {
    const allocator = std.testing.allocator;
    var val = EnvValue.init(allocator);
    defer val.deinit();

    const buffer = try allocator.alloc(u8, 5);
    @memcpy(buffer, "value");

    val.setOwnBuffer(buffer);

    try std.testing.expect(val.hasOwnBuffer());
    try std.testing.expectEqualStrings("value", val.value);
}

test "EnvValue interpolations" {
    const allocator = std.testing.allocator;
    var val = EnvValue.init(allocator);
    defer val.deinit();

    // Assuming VariablePosition can be initialized easily.
    // We might need to mock or just use the struct if it's simple.
    // Let's assume VariablePosition is defined in variable_position.zig

    try val.interpolations.append(VariablePosition.init(0, 0, 0));

    try std.testing.expect(val.interpolations.items.len == 1);
}
