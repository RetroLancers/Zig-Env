const std = @import("std");
const framework = @import("framework.zig");
const zigenv = @import("zigenv");

pub const ThroughputResult = struct {
    name: []const u8,
    bytes_processed: usize,
    entries_parsed: usize,
    elapsed_ns: u64,
    bytes_per_second: f64,
    entries_per_second: f64,
    mbps: f64,
};

fn runThroughput(allocator: std.mem.Allocator, content: []const u8, name: []const u8) !ThroughputResult {
    var timer = try std.time.Timer.start();

    // Parse the content
    var env = try zigenv.parse(allocator, content);
    defer env.deinit();

    const elapsed = timer.read();

    const bytes = content.len;
    const entries = env.map.count();

    const seconds = @as(f64, @floatFromInt(elapsed)) / 1_000_000_000.0;
    const bytes_per_sec = @as(f64, @floatFromInt(bytes)) / seconds;
    const entries_per_sec = @as(f64, @floatFromInt(entries)) / seconds;
    const mbps = bytes_per_sec / (1024.0 * 1024.0);

    return ThroughputResult{
        .name = name,
        .bytes_processed = bytes,
        .entries_parsed = entries,
        .elapsed_ns = elapsed,
        .bytes_per_second = bytes_per_sec,
        .entries_per_second = entries_per_sec,
        .mbps = mbps,
    };
}

fn printThroughput(result: ThroughputResult) void {
    std.debug.print("\nThroughput Results for {s}:\n", .{result.name});
    std.debug.print("  Bytes:      {d}\n", .{result.bytes_processed});
    std.debug.print("  Entries:    {d}\n", .{result.entries_parsed});
    std.debug.print("  Elapsed:    {d:.2} ms\n", .{@as(f64, @floatFromInt(result.elapsed_ns)) / 1_000_000.0});
    std.debug.print("  Throughput: {d:.2} MB/s\n", .{result.mbps});
    std.debug.print("  Rate:       {d:.2} entries/s\n", .{result.entries_per_second});
    std.debug.print("--------------------------------------------------\n", .{});
}

fn generateBenchmarkContent(allocator: std.mem.Allocator, entry_count: usize) ![]u8 {
    var buffer = zigenv.ReusableBuffer.init(allocator);
    errdefer buffer.deinit();

    var i: usize = 0;
    while (i < entry_count) : (i += 1) {
        try buffer.writer().print("KEY_{d}=VALUE_{d}\n", .{ i, i });
    }
    return buffer.toOwnedSlice();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Throughput Benchmarks ===\n", .{});

    // Small file (100 entries)
    {
        const content = try generateBenchmarkContent(allocator, 100);
        defer allocator.free(content);
        const result = try runThroughput(allocator, content, "Small File (0.1K entries)");
        printThroughput(result);
    }

    // Medium file (1,000 entries)
    {
        const content = try generateBenchmarkContent(allocator, 1_000);
        defer allocator.free(content);
        const result = try runThroughput(allocator, content, "Medium File (1K entries)");
        printThroughput(result);
    }

    // Large file (10,000 entries)
    {
        const content = try generateBenchmarkContent(allocator, 10_000);
        defer allocator.free(content);
        const result = try runThroughput(allocator, content, "Large File (10K entries)");
        printThroughput(result);
    }

    // Huge file (100,000 entries)
    {
        const content = try generateBenchmarkContent(allocator, 100_000);
        defer allocator.free(content);
        const result = try runThroughput(allocator, content, "Huge File (100K entries)");
        printThroughput(result);
    }
}
