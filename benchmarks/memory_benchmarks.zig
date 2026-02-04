const std = @import("std");
const zigenv = @import("zigenv");

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
    parent: std.mem.Allocator,
    stats: AllocationStats = .{},

    const vtable: std.mem.Allocator.VTable = .{
        .alloc = alloc,
        .resize = resize,
        .remap = remap,
        .free = free,
    };

    pub fn init(parent: std.mem.Allocator) TrackingAllocator {
        return .{ .parent = parent };
    }

    pub fn allocator(self: *TrackingAllocator) std.mem.Allocator {
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

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    std.debug.print("=== Memory Benchmarks ===\n", .{});

    const count = 1000;
    var tracker = TrackingAllocator.init(gpa.allocator());
    const alloc = tracker.allocator();

    // Create content
    var content_buf = zigenv.ReusableBuffer.init(gpa.allocator());
    defer content_buf.deinit();
    var i: usize = 0;
    while (i < count) : (i += 1) {
        try content_buf.writer().print("KEY_{d}=VALUE_{d}\n", .{ i, i });
    }
    const content = content_buf.items();

    // Benchmark parse
    {
        tracker.stats.reset();

        var env = try zigenv.parse(alloc, content);

        std.debug.print("Memory Usage (during parse of {d} entries):\n", .{count});
        std.debug.print("  Peak bytes:   {d} bytes\n", .{tracker.stats.peak_bytes});
        std.debug.print("  Allocs:       {d}\n", .{tracker.stats.allocation_count});
        std.debug.print("  Reallocs:     {d}\n", .{tracker.stats.reallocation_count});

        env.deinit();

        std.debug.print("  Final Allocs balance: {d} (should be equal to frees)\n", .{tracker.stats.allocation_count - tracker.stats.deallocation_count});
        std.debug.print("  Final Bytes balance:  {d} (should be 0)\n", .{tracker.stats.current_bytes});
    }
}
