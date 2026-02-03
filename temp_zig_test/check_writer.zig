const std = @import("std");

pub fn main() !void {
    std.debug.print("Type: {}\n", .{@TypeOf(std.io.Writer)});
}
