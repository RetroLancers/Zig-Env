const std = @import("std");

pub fn main() !void {
    if (@hasDecl(std.io, "GenericWriter")) {
        std.debug.print("std.io.GenericWriter exists\n", .{});
    } else {
        std.debug.print("std.io.GenericWriter DOES NOT exist\n", .{});
    }

    if (@hasDecl(std.io, "AnyWriter")) {
        std.debug.print("std.io.AnyWriter exists\n", .{});
    }

    if (@hasDecl(std.io, "Writer")) {
        std.debug.print("std.io.Writer exists and is type: {}\n", .{@TypeOf(std.io.Writer)});
    }
}
