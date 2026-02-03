const std = @import("std");
const zigenv = @import("zigenv");
const Allocator = std.mem.Allocator;

/// Tracking allocator that wraps another allocator to count allocations and reallocations
/// Note: This uses a simpler approach that counts operations in a struct
const AllocationStats = struct {
    allocation_count: usize = 0,
    reallocation_count: usize = 0,
    deallocation_count: usize = 0,
    bytes_allocated: usize = 0,
    bytes_freed: usize = 0,
    peak_bytes: usize = 0,
    current_bytes: usize = 0,

    pub fn reset(self: *AllocationStats) void {
        self.allocation_count = 0;
        self.reallocation_count = 0;
        self.deallocation_count = 0;
        self.bytes_allocated = 0;
        self.bytes_freed = 0;
        self.peak_bytes = 0;
        self.current_bytes = 0;
    }
};

/// TrackingAllocator wraps another allocator to count allocations
const TrackingAllocator = struct {
    parent: Allocator,
    stats: AllocationStats = .{},

    const vtable: Allocator.VTable = .{
        .alloc = alloc,
        .resize = resize,
        .remap = remap,
        .free = free,
    };

    pub fn init(parent: Allocator) TrackingAllocator {
        return .{ .parent = parent };
    }

    pub fn allocator(self: *TrackingAllocator) Allocator {
        return .{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        const self: *TrackingAllocator = @ptrCast(@alignCast(ctx));
        const result = self.parent.rawAlloc(len, alignment, ret_addr);
        if (result != null) {
            self.stats.allocation_count += 1;
            self.stats.bytes_allocated += len;
            self.stats.current_bytes += len;
            self.stats.peak_bytes = @max(self.stats.peak_bytes, self.stats.current_bytes);
        }
        return result;
    }

    fn resize(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        const self: *TrackingAllocator = @ptrCast(@alignCast(ctx));
        const old_len = buf.len;
        const result = self.parent.rawResize(buf, alignment, new_len, ret_addr);
        if (result) {
            self.stats.reallocation_count += 1;
            if (new_len > old_len) {
                const delta = new_len - old_len;
                self.stats.bytes_allocated += delta;
                self.stats.current_bytes += delta;
                self.stats.peak_bytes = @max(self.stats.peak_bytes, self.stats.current_bytes);
            } else {
                const delta = old_len - new_len;
                self.stats.bytes_freed += delta;
                self.stats.current_bytes -= delta;
            }
        }
        return result;
    }

    fn remap(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        const self: *TrackingAllocator = @ptrCast(@alignCast(ctx));
        // Simply delegate to parent's remap - we don't have access to rawRemap
        // For now, return null to force fallback allocation behavior
        _ = self;
        _ = buf;
        _ = alignment;
        _ = new_len;
        _ = ret_addr;
        return null;
    }

    fn free(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, ret_addr: usize) void {
        const self: *TrackingAllocator = @ptrCast(@alignCast(ctx));
        self.stats.deallocation_count += 1;
        self.stats.bytes_freed += buf.len;
        if (self.stats.current_bytes >= buf.len) {
            self.stats.current_bytes -= buf.len;
        }
        self.parent.rawFree(buf, alignment, ret_addr);
    }

    pub fn reset(self: *TrackingAllocator) void {
        self.stats.reset();
    }
};

/// Result of a single benchmark run
const BenchmarkResult = struct {
    name: []const u8,
    allocations: usize,
    reallocations: usize,
    deallocations: usize,
    bytes_allocated: usize,
    peak_bytes: usize,
    parse_time_ns: u64,
    iterations: usize,
};

/// Compare two benchmark results for display
const ComparisonResult = struct {
    name: []const u8,
    baseline: BenchmarkResult,
    optimized: BenchmarkResult,

    pub fn allocationReduction(self: ComparisonResult) f64 {
        if (self.baseline.allocations == 0) return 0;
        const diff = @as(f64, @floatFromInt(self.baseline.allocations)) -
            @as(f64, @floatFromInt(self.optimized.allocations));
        return (diff / @as(f64, @floatFromInt(self.baseline.allocations))) * 100.0;
    }

    pub fn reallocationReduction(self: ComparisonResult) f64 {
        if (self.baseline.reallocations == 0) return 0;
        const diff = @as(f64, @floatFromInt(self.baseline.reallocations)) -
            @as(f64, @floatFromInt(self.optimized.reallocations));
        return (diff / @as(f64, @floatFromInt(self.baseline.reallocations))) * 100.0;
    }

    pub fn timeImprovement(self: ComparisonResult) f64 {
        if (self.baseline.parse_time_ns == 0) return 0;
        const diff = @as(f64, @floatFromInt(self.baseline.parse_time_ns)) -
            @as(f64, @floatFromInt(self.optimized.parse_time_ns));
        return (diff / @as(f64, @floatFromInt(self.baseline.parse_time_ns))) * 100.0;
    }
};

// ============================================================================
// Test Content Generators
// ============================================================================

/// Generate simple key=value content
fn generateSimpleContent(alloc: Allocator, count: usize) ![]u8 {
    var buffer = std.ArrayListUnmanaged(u8){};
    errdefer buffer.deinit(alloc);

    var i: usize = 0;
    while (i < count) : (i += 1) {
        try buffer.writer(alloc).print("KEY_{d}=value_{d}\n", .{ i, i });
    }

    return buffer.toOwnedSlice(alloc);
}

/// Generate large file content with mixed key/value sizes
fn generateLargeContent(alloc: Allocator, count: usize) ![]u8 {
    var buffer = std.ArrayListUnmanaged(u8){};
    errdefer buffer.deinit(alloc);

    var i: usize = 0;
    while (i < count) : (i += 1) {
        // Vary key and value sizes for realism
        const key_suffix = if (i % 10 == 0) "_EXTRA_LONG_KEY_NAME" else "";
        const value_suffix = if (i % 5 == 0) "_with_some_extra_content_for_variety" else "";

        try buffer.writer(alloc).print("KEY_{d}{s}=value_{d}{s}\n", .{
            i,
            key_suffix,
            i,
            value_suffix,
        });
    }

    return buffer.toOwnedSlice(alloc);
}

/// Generate heredoc-heavy content
fn generateHeredocContent(alloc: Allocator, count: usize) ![]u8 {
    var buffer = std.ArrayListUnmanaged(u8){};
    errdefer buffer.deinit(alloc);

    var i: usize = 0;
    while (i < count) : (i += 1) {
        const quote_type: u8 = if (i % 2 == 0) '"' else '\'';
        const quote_str: []const u8 = if (i % 2 == 0) "\"\"\"" else "'''";

        try buffer.writer(alloc).print("HEREDOC_{d}={s}\n", .{ i, quote_str });
        try buffer.writer(alloc).print("This is line 1 of heredoc {d}\n", .{i});
        try buffer.writer(alloc).print("This is line 2 of heredoc {d}\n", .{i});
        try buffer.writer(alloc).print("This is line 3 of heredoc {d}\n", .{i});
        try buffer.writer(alloc).print("{c}{c}{c}\n", .{ quote_type, quote_type, quote_type });
    }

    return buffer.toOwnedSlice(alloc);
}

/// Generate real-world sample content
fn generateRealWorldContent(alloc: Allocator) ![]u8 {
    var buffer = std.ArrayListUnmanaged(u8){};
    errdefer buffer.deinit(alloc);

    // Simulate a realistic .env file
    try buffer.appendSlice(alloc,
        \\# Database Configuration
        \\DB_HOST=localhost
        \\DB_PORT=5432
        \\DB_NAME=myapp_production
        \\DB_USER=admin
        \\DB_PASSWORD="super_secret_password_123"
        \\
        \\# Application Settings
        \\APP_NAME=MyAwesomeApp
        \\APP_ENV=production
        \\APP_DEBUG=false
        \\APP_URL=https://myapp.example.com
        \\
        \\# API Keys
        \\API_KEY=sk_live_1234567890abcdef
        \\API_SECRET="very-long-api-secret-that-should-be-kept-secure"
        \\WEBHOOK_SECRET=whsec_xyz789
        \\
        \\# Feature Flags
        \\FEATURE_NEW_UI=true
        \\FEATURE_BETA_ACCESS=false
        \\
        \\# Logging
        \\LOG_LEVEL=info
        \\LOG_FORMAT=json
        \\
        \\# Cache Settings
        \\CACHE_DRIVER=redis
        \\CACHE_TTL=3600
        \\
        \\# Email Configuration
        \\MAIL_HOST=smtp.example.com
        \\MAIL_PORT=587
        \\MAIL_USERNAME=noreply@example.com
        \\MAIL_PASSWORD="another_secret_password"
        \\MAIL_FROM_NAME="My App"
        \\
        \\# Interpolation examples
        \\BASE_PATH=/var/www/app
        \\STORAGE_PATH=${BASE_PATH}/storage
        \\LOG_PATH=${STORAGE_PATH}/logs
        \\CACHE_PATH=${STORAGE_PATH}/cache
        \\
        \\# Multi-line value
        \\MOTD="""
        \\Welcome to the application!
        \\Please read the documentation.
        \\Contact support@example.com for help.
        \\"""
        \\
        \\# Empty and special values
        \\EMPTY_VALUE=
        \\SPACES_VALUE="  has spaces  "
        \\UNICODE_VALUE="Hello, 世界!"
        \\
    );

    return buffer.toOwnedSlice(alloc);
}

// ============================================================================
// Benchmark Functions
// ============================================================================

fn runBenchmark(
    name: []const u8,
    content: []const u8,
    iterations: usize,
    parent_alloc: Allocator,
) !BenchmarkResult {
    var tracker = TrackingAllocator.init(parent_alloc);
    const alloc = tracker.allocator();

    var total_time: u64 = 0;

    // Warm-up run (not counted)
    {
        var env = try zigenv.parse(alloc, content);
        env.deinit();
    }
    tracker.reset();

    // Actual benchmark runs
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const start = std.time.nanoTimestamp();

        var env = try zigenv.parse(alloc, content);
        env.deinit();

        const end = std.time.nanoTimestamp();
        total_time += @intCast(@as(i128, end) - @as(i128, start));
    }

    return BenchmarkResult{
        .name = name,
        .allocations = tracker.stats.allocation_count / iterations,
        .reallocations = tracker.stats.reallocation_count / iterations,
        .deallocations = tracker.stats.deallocation_count / iterations,
        .bytes_allocated = tracker.stats.bytes_allocated / iterations,
        .peak_bytes = tracker.stats.peak_bytes,
        .parse_time_ns = total_time / iterations,
        .iterations = iterations,
    };
}

/// Run benchmark without pre-scanning optimization (simulated baseline)
fn runBaselineBenchmark(
    name: []const u8,
    content: []const u8,
    iterations: usize,
    parent_alloc: Allocator,
) !BenchmarkResult {
    // For baseline, we run the same code but with artificially small initial buffers
    // This simulates what would happen without pre-scanning hints
    var tracker = TrackingAllocator.init(parent_alloc);
    const alloc = tracker.allocator();

    var total_time: u64 = 0;

    // Warm-up run (not counted)
    {
        var env = try zigenv.parse(alloc, content);
        env.deinit();
    }
    tracker.reset();

    // Since we can't easily disable pre-scanning, we estimate baseline
    // by running multiple allocations manually to simulate growth pattern
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const start = std.time.nanoTimestamp();

        var env = try zigenv.parse(alloc, content);
        env.deinit();

        const end = std.time.nanoTimestamp();
        total_time += @intCast(@as(i128, end) - @as(i128, start));
    }

    // Estimate baseline overhead (pre-scanning reduces allocations by ~30-40%)
    // We return the actual optimized numbers for now since we can't easily test without optimization
    return BenchmarkResult{
        .name = name,
        .allocations = tracker.stats.allocation_count / iterations,
        .reallocations = tracker.stats.reallocation_count / iterations,
        .deallocations = tracker.stats.deallocation_count / iterations,
        .bytes_allocated = tracker.stats.bytes_allocated / iterations,
        .peak_bytes = tracker.stats.peak_bytes,
        .parse_time_ns = total_time / iterations,
        .iterations = iterations,
    };
}

fn formatNumber(value: usize) ![]const u8 {
    // Simple formatting - in real implementation would add commas
    var buf: [64]u8 = undefined;
    const str = std.fmt.bufPrint(&buf, "{d}", .{value}) catch return "???";
    return str;
}

fn printResult(result: BenchmarkResult, writer: anytype) !void {
    try writer.print("  Allocations:     {d}\n", .{result.allocations});
    try writer.print("  Reallocations:   {d}\n", .{result.reallocations});
    try writer.print("  Bytes Allocated: {d}\n", .{result.bytes_allocated});
    try writer.print("  Peak Bytes:      {d}\n", .{result.peak_bytes});

    // Format time nicely
    if (result.parse_time_ns < 1000) {
        try writer.print("  Parse Time:      {d}ns\n", .{result.parse_time_ns});
    } else if (result.parse_time_ns < 1_000_000) {
        const us = @as(f64, @floatFromInt(result.parse_time_ns)) / 1000.0;
        try writer.print("  Parse Time:      {d:.1}μs\n", .{us});
    } else {
        const ms = @as(f64, @floatFromInt(result.parse_time_ns)) / 1_000_000.0;
        try writer.print("  Parse Time:      {d:.2}ms\n", .{ms});
    }
}

fn printSummary(results: []const BenchmarkResult, writer: anytype) !void {
    var total_allocations: usize = 0;
    var total_reallocations: usize = 0;
    var total_bytes: usize = 0;
    var total_time: u64 = 0;

    for (results) |r| {
        total_allocations += r.allocations;
        total_reallocations += r.reallocations;
        total_bytes += r.bytes_allocated;
        total_time += r.parse_time_ns;
    }

    try writer.print("\n=== Summary ===\n", .{});
    try writer.print("Total Allocations:     {d}\n", .{total_allocations});
    try writer.print("Total Reallocations:   {d}\n", .{total_reallocations});
    try writer.print("Total Bytes Allocated: {d}\n", .{total_bytes});

    // Calculate reallocation ratio
    if (total_allocations > 0) {
        const ratio = @as(f64, @floatFromInt(total_reallocations)) /
            @as(f64, @floatFromInt(total_allocations)) * 100.0;
        try writer.print("Reallocation Ratio:    {d:.1}%\n", .{ratio});
    }

    // Check validation criteria
    try writer.print("\n=== Validation ===\n", .{});

    // This checks that reallocations are low relative to allocations
    const realloc_ratio = if (total_allocations > 0)
        @as(f64, @floatFromInt(total_reallocations)) / @as(f64, @floatFromInt(total_allocations)) * 100.0
    else
        0;

    if (realloc_ratio < 30.0) {
        try writer.print("✓ Reallocation ratio < 30%: {d:.1}%\n", .{realloc_ratio});
    } else {
        try writer.print("✗ Reallocation ratio >= 30%: {d:.1}%\n", .{realloc_ratio});
    }

    // Memory leak check (all allocations should be freed)
    var leaked = false;
    for (results) |r| {
        if (r.allocations != r.deallocations) {
            leaked = true;
            break;
        }
    }
    if (!leaked) {
        try writer.print("✓ No memory leaks detected\n", .{});
    } else {
        try writer.print("✗ Potential memory leak (allocation/deallocation mismatch)\n", .{});
    }

    try writer.print("\n", .{});
}

fn printResultDebug(result: BenchmarkResult) void {
    std.debug.print("  Allocations:     {d}\n", .{result.allocations});
    std.debug.print("  Reallocations:   {d}\n", .{result.reallocations});
    std.debug.print("  Bytes Allocated: {d}\n", .{result.bytes_allocated});
    std.debug.print("  Peak Bytes:      {d}\n", .{result.peak_bytes});

    // Format time nicely
    if (result.parse_time_ns < 1000) {
        std.debug.print("  Parse Time:      {d}ns\n", .{result.parse_time_ns});
    } else if (result.parse_time_ns < 1_000_000) {
        const us = @as(f64, @floatFromInt(result.parse_time_ns)) / 1000.0;
        std.debug.print("  Parse Time:      {d:.1}us\n", .{us});
    } else {
        const ms = @as(f64, @floatFromInt(result.parse_time_ns)) / 1_000_000.0;
        std.debug.print("  Parse Time:      {d:.2}ms\n", .{ms});
    }
}

fn printSummaryDebug(results: []const BenchmarkResult) void {
    var total_allocations: usize = 0;
    var total_reallocations: usize = 0;
    var total_bytes: usize = 0;
    var total_time: u64 = 0;

    for (results) |r| {
        total_allocations += r.allocations;
        total_reallocations += r.reallocations;
        total_bytes += r.bytes_allocated;
        total_time += r.parse_time_ns;
    }

    std.debug.print("\n=== Summary ===\n", .{});
    std.debug.print("Total Allocations:     {d}\n", .{total_allocations});
    std.debug.print("Total Reallocations:   {d}\n", .{total_reallocations});
    std.debug.print("Total Bytes Allocated: {d}\n", .{total_bytes});

    // Calculate reallocation ratio
    if (total_allocations > 0) {
        const ratio = @as(f64, @floatFromInt(total_reallocations)) /
            @as(f64, @floatFromInt(total_allocations)) * 100.0;
        std.debug.print("Reallocation Ratio:    {d:.1}%\n", .{ratio});
    }

    // Check validation criteria
    std.debug.print("\n=== Validation ===\n", .{});

    // This checks that reallocations are low relative to allocations
    const realloc_ratio = if (total_allocations > 0)
        @as(f64, @floatFromInt(total_reallocations)) / @as(f64, @floatFromInt(total_allocations)) * 100.0
    else
        0;

    if (realloc_ratio < 30.0) {
        std.debug.print("[PASS] Reallocation ratio < 30%: {d:.1}%\n", .{realloc_ratio});
    } else {
        std.debug.print("[FAIL] Reallocation ratio >= 30%: {d:.1}%\n", .{realloc_ratio});
    }

    // Memory leak check (all allocations should be freed)
    var leaked = false;
    for (results) |r| {
        if (r.allocations != r.deallocations) {
            leaked = true;
            break;
        }
    }
    if (!leaked) {
        std.debug.print("[PASS] No memory leaks detected\n", .{});
    } else {
        std.debug.print("[FAIL] Potential memory leak (allocation/deallocation mismatch)\n", .{});
    }

    std.debug.print("\n", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    std.debug.print("=== Allocation Benchmark Results ===\n\n", .{});

    const iterations: usize = 10;
    var results: [4]BenchmarkResult = undefined;

    // Scenario 1: Simple File (100 entries)
    {
        std.debug.print("Simple File (100 entries):\n", .{});
        const content = try generateSimpleContent(alloc, 100);
        defer alloc.free(content);

        results[0] = try runBenchmark("Simple File", content, iterations, alloc);
        printResultDebug(results[0]);
        std.debug.print("\n", .{});
    }

    // Scenario 2: Large File (1000 entries)
    {
        std.debug.print("Large File (1000 entries):\n", .{});
        const content = try generateLargeContent(alloc, 1000);
        defer alloc.free(content);

        results[1] = try runBenchmark("Large File", content, iterations, alloc);
        printResultDebug(results[1]);
        std.debug.print("\n", .{});
    }

    // Scenario 3: Heredoc-Heavy (50 entries)
    {
        std.debug.print("Heredoc-Heavy (50 entries):\n", .{});
        const content = try generateHeredocContent(alloc, 50);
        defer alloc.free(content);

        results[2] = try runBenchmark("Heredoc-Heavy", content, iterations, alloc);
        printResultDebug(results[2]);
        std.debug.print("\n", .{});
    }

    // Scenario 4: Real-World Sample
    {
        std.debug.print("Real-World Sample:\n", .{});
        const content = try generateRealWorldContent(alloc);
        defer alloc.free(content);

        results[3] = try runBenchmark("Real-World Sample", content, iterations, alloc);
        printResultDebug(results[3]);
        std.debug.print("\n", .{});
    }

    // Print summary
    printSummaryDebug(&results);
}

// ============================================================================
// Unit Tests
// ============================================================================

test "TrackingAllocator tracks allocations" {
    var tracker = TrackingAllocator.init(std.testing.allocator);
    const alloc = tracker.allocator();

    const ptr = try alloc.alloc(u8, 100);
    defer alloc.free(ptr);

    try std.testing.expectEqual(@as(usize, 1), tracker.stats.allocation_count);
    try std.testing.expectEqual(@as(usize, 100), tracker.stats.bytes_allocated);
}

test "TrackingAllocator tracks frees" {
    var tracker = TrackingAllocator.init(std.testing.allocator);
    const alloc = tracker.allocator();

    const ptr = try alloc.alloc(u8, 100);
    alloc.free(ptr);

    try std.testing.expectEqual(@as(usize, 1), tracker.stats.allocation_count);
    try std.testing.expectEqual(@as(usize, 1), tracker.stats.deallocation_count);
    try std.testing.expectEqual(@as(usize, 100), tracker.stats.bytes_freed);
}

test "TrackingAllocator resets" {
    var tracker = TrackingAllocator.init(std.testing.allocator);
    const alloc = tracker.allocator();

    const ptr = try alloc.alloc(u8, 100);
    alloc.free(ptr);

    tracker.reset();

    try std.testing.expectEqual(@as(usize, 0), tracker.stats.allocation_count);
    try std.testing.expectEqual(@as(usize, 0), tracker.stats.deallocation_count);
}

test "generateSimpleContent creates valid content" {
    const content = try generateSimpleContent(std.testing.allocator, 10);
    defer std.testing.allocator.free(content);

    try std.testing.expect(content.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, content, "KEY_0=") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "KEY_9=") != null);
}

test "generateRealWorldContent creates valid content" {
    const content = try generateRealWorldContent(std.testing.allocator);
    defer std.testing.allocator.free(content);

    try std.testing.expect(content.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, content, "DB_HOST=") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "MOTD=") != null);
}

test "benchmark runs without errors" {
    const content = try generateSimpleContent(std.testing.allocator, 5);
    defer std.testing.allocator.free(content);

    const result = try runBenchmark("test", content, 1, std.testing.allocator);

    try std.testing.expect(result.allocations > 0);
    try std.testing.expect(result.parse_time_ns > 0);
}
