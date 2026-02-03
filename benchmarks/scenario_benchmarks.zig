const std = @import("std");
const zigenv = @import("zigenv");
const framework = @import("framework.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Scenario Benchmarks ===\n", .{});

    // Scenario 1: Web Server Startup (loading .env, .env.local, .env.development)
    {
        const result = try framework.benchmark(allocator, "Web Server Startup Simulation", struct {
            fn run(alloc: std.mem.Allocator) !void {
                const base = "PORT=3000\nDATABASE_URL=postgres://localhost\n";
                const local = "DATABASE_URL=postgres://user:pass@localhost\nDEBUG=true\n";

                var env = try zigenv.parse(alloc, base);
                defer env.deinit();

                var env_local = try zigenv.parse(alloc, local);
                defer env_local.deinit();

                // Merge (simulated)
                var it = env_local.map.iterator();
                while (it.next()) |entry| {
                    try env.put(entry.key_ptr.*, entry.value_ptr.*);
                }
            }
        }.run, .{ .warmup_iterations = 100, .measurement_iterations = 1000 });

        try framework.printResults(result);
    }
}
