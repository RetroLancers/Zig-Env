const std = @import("std");

pub fn main() !void {
    // Print all public declarations in std.io
    inline for (std.meta.declarations(std.io)) |decl| {
        std.debug.print("{s}: {s}\n", .{ decl.name, @typeName(@field(std.io, decl.name)) });
    }
}
