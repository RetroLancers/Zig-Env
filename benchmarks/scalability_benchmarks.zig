const std = @import("std");
const zigenv = @import("zigenv");
const framework = @import("framework.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Scalability Benchmarks ===\n", .{});

    // Test sizes: 10, 100, 1000, 10000 entries
    const sizes = [_]usize{ 10, 100, 1000, 10000 };

    for (sizes) |size| {
        const content = try generateContent(allocator, size);
        defer allocator.free(content);

        const name = try std.fmt.allocPrint(allocator, "{d} entries", .{size});
        defer allocator.free(name);

        const result = try framework.benchmarkWithSetup(
            allocator,
            name,
            content,
            struct {
                fn run(ctx: []const u8, alloc: std.mem.Allocator) !void {
                    var env = try zigenv.parse(alloc, ctx);
                    env.deinit();
                }
            }.run,
            null,
            .{ .warmup_iterations = 10, .measurement_iterations = 50 },
        );

        try framework.printResults(result);
    }
}

fn generateContent(allocator: std.mem.Allocator, count: usize) ![]u8 {
    var buffer = zigenv.ReusableBuffer.init(allocator);
    errdefer buffer.deinit();
    var i: usize = 0;
    while (i < count) : (i += 1) {
        try buffer.writer().print("KEY_{d}=VALUE_{d}\n", .{ i, i });
    }
    return buffer.toOwnedSlice();
}
