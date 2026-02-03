const std = @import("std");

pub fn calculateMean(samples: []const u64) f64 {
    var sum: u64 = 0;
    for (samples) |s| {
        sum += s;
    }
    return @as(f64, @floatFromInt(sum)) / @as(f64, @floatFromInt(samples.len));
}

pub fn calculateStdDev(samples: []const u64, mean: f64) f64 {
    var sum_sq_diff: f64 = 0;
    for (samples) |s| {
        const diff = @as(f64, @floatFromInt(s)) - mean;
        sum_sq_diff += diff * diff;
    }
    return std.math.sqrt(sum_sq_diff / @as(f64, @floatFromInt(samples.len)));
}

pub fn calculatePercentile(sorted_samples: []const u64, percentile: f64) u64 {
    if (sorted_samples.len == 0) return 0;
    const idx = @as(usize, @intFromFloat(@ceil(percentile / 100.0 * @as(f64, @floatFromInt(sorted_samples.len))))) -| 1;
    return sorted_samples[idx];
}

pub fn detectOutliers(allocator: std.mem.Allocator, sorted_samples: []const u64) ![]usize {
    // Simple IQR method
    if (sorted_samples.len < 4) return &[_]usize{};

    const q1 = calculatePercentile(sorted_samples, 25.0);
    const q3 = calculatePercentile(sorted_samples, 75.0);
    const iqr = if (q3 > q1) q3 - q1 else 0;

    // Bounds
    const iqr_f = @as(f64, @floatFromInt(iqr));
    const lower_bound_f = @as(f64, @floatFromInt(q1)) - 1.5 * iqr_f;
    const upper_bound_val = q3 + @as(u64, @intFromFloat(1.5 * iqr_f));
    const lower_bound_val = if (lower_bound_f < 0) 0 else @as(u64, @intFromFloat(lower_bound_f));

    var outliers = std.ArrayList(usize).init(allocator);
    errdefer outliers.deinit();

    for (sorted_samples, 0..) |s, i| {
        if (s < lower_bound_val or s > upper_bound_val) {
            try outliers.append(i);
        }
    }
    return outliers.toOwnedSlice();
}
