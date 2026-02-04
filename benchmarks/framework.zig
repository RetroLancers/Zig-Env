const std = @import("std");
const stats = @import("statistics.zig");

pub const BenchmarkResult = struct {
    name: []const u8,
    iterations: usize,
    total_time_ns: u64,
    min_time_ns: u64,
    max_time_ns: u64,
    avg_time_ns: f64,
    median_time_ns: u64,
    p95_time_ns: u64,
    p99_time_ns: u64,
    stddev_time_ns: f64,
};

pub const BenchmarkConfig = struct {
    warmup_iterations: usize = 100,
    measurement_iterations: usize = 1000,
};

pub fn benchmark(
    allocator: std.mem.Allocator,
    name: []const u8,
    func: *const fn (std.mem.Allocator) anyerror!void,
    config: BenchmarkConfig,
) !BenchmarkResult {
    std.debug.print("Running benchmark: {s}...\n", .{name});

    // Warmup
    var i: usize = 0;
    while (i < config.warmup_iterations) : (i += 1) {
        try func(allocator);
    }

    var samples = try std.ArrayListUnmanaged(u64).initCapacity(allocator, config.measurement_iterations);
    defer samples.deinit(allocator);

    var total_time_ns: u64 = 0;
    var iterations: usize = 0;
    var timer = try std.time.Timer.start();

    // Measurement loop
    while (iterations < config.measurement_iterations) : (iterations += 1) {
        timer.reset();
        try func(allocator);
        const duration = timer.read();
        try samples.append(allocator, duration);
        total_time_ns += duration;
    }

    const slice = samples.items;
    std.mem.sort(u64, slice, {}, std.sort.asc(u64));

    const mean = stats.calculateMean(slice);

    return BenchmarkResult{
        .name = name,
        .iterations = iterations,
        .total_time_ns = total_time_ns,
        .min_time_ns = slice[0],
        .max_time_ns = slice[slice.len - 1],
        .avg_time_ns = mean,
        .median_time_ns = stats.calculatePercentile(slice, 50.0),
        .p95_time_ns = stats.calculatePercentile(slice, 95.0),
        .p99_time_ns = stats.calculatePercentile(slice, 99.0),
        .stddev_time_ns = stats.calculateStdDev(slice, mean),
    };
}

pub fn benchmarkWithSetup(
    allocator: std.mem.Allocator,
    name: []const u8,
    context: anytype,
    runFn: fn (@TypeOf(context), std.mem.Allocator) anyerror!void,
    resetFn: ?fn (@TypeOf(context)) void,
    config: BenchmarkConfig,
) !BenchmarkResult {
    std.debug.print("Running benchmark: {s}...\n", .{name});

    // Warmup
    var i: usize = 0;
    while (i < config.warmup_iterations) : (i += 1) {
        if (resetFn) |f| f(context);
        try runFn(context, allocator);
    }

    var samples = try std.ArrayListUnmanaged(u64).initCapacity(allocator, config.measurement_iterations);
    defer samples.deinit(allocator);

    var total_time_ns: u64 = 0;
    var iterations: usize = 0;
    var timer = try std.time.Timer.start();

    // Measurement loop
    while (iterations < config.measurement_iterations) : (iterations += 1) {
        if (resetFn) |f| f(context);

        timer.reset();
        try runFn(context, allocator);
        const duration = timer.read();

        try samples.append(allocator, duration);
        total_time_ns += duration;
    }

    const slice = samples.items;
    std.mem.sort(u64, slice, {}, std.sort.asc(u64));

    const mean = stats.calculateMean(slice);

    return BenchmarkResult{
        .name = name,
        .iterations = iterations,
        .total_time_ns = total_time_ns,
        .min_time_ns = slice[0],
        .max_time_ns = slice[slice.len - 1],
        .avg_time_ns = mean,
        .median_time_ns = stats.calculatePercentile(slice, 50.0),
        .p95_time_ns = stats.calculatePercentile(slice, 95.0),
        .p99_time_ns = stats.calculatePercentile(slice, 99.0),
        .stddev_time_ns = stats.calculateStdDev(slice, mean),
    };
}

pub fn printResults(result: BenchmarkResult) !void {
    std.debug.print("\nResults for {s}:\n", .{result.name});
    std.debug.print("  Iterations: {d}\n", .{result.iterations});
    std.debug.print("  Total Time: {d} ns\n", .{result.total_time_ns});
    std.debug.print("  Avg Time:   {d:.2} ns\n", .{result.avg_time_ns});
    std.debug.print("  Min Time:   {d} ns\n", .{result.min_time_ns});
    std.debug.print("  Max Time:   {d} ns\n", .{result.max_time_ns});
    std.debug.print("  Median:     {d} ns\n", .{result.median_time_ns});
    std.debug.print("  P95:        {d} ns\n", .{result.p95_time_ns});
    std.debug.print("  P99:        {d} ns\n", .{result.p99_time_ns});
    std.debug.print("  StdDev:     {d:.2} ns\n", .{result.stddev_time_ns});
    std.debug.print("--------------------------------------------------\n", .{});
}
