const std = @import("std");
const framework = @import("framework.zig");
const zigenv = @import("zigenv");
const stats = @import("statistics.zig");

pub fn runColdStart(allocator: std.mem.Allocator, content: []const u8) !u64 {
    var timer = try std.time.Timer.start();
    var env = try zigenv.parse(allocator, content);
    env.deinit();
    return timer.read();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Latency Benchmarks ===\n", .{});

    const content = "KEY=value\n".* ** 100; // 100 entries

    // Cold Start (first parse)
    {
        const latency = try runColdStart(allocator, &content);
        std.debug.print("Cold Start Latency: {d:.2} us\n", .{@as(f64, @floatFromInt(latency)) / 1000.0});
    }

    // Warm Cache (p50, p95, p99)
    {
        const result = try framework.benchmark(allocator, "Warm Cache Latency", struct {
            fn run(alloc: std.mem.Allocator) !void {
                var env = try zigenv.parse(alloc, &content);
                env.deinit();
            }
        }.run, .{ .warmup_iterations = 100, .measurement_iterations = 1000 });

        try framework.printResults(result);
    }
}
