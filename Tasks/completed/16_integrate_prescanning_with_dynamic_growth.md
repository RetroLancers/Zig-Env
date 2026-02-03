# Integrate Pre-Scanning with Dynamic Buffer Growth

## Objective
Integrate the file scanner (from Task 15) into the main parsing flow and implement intelligent buffer growth when pre-scan estimates are insufficient.

## Prerequisites
- Task 10 (ReusableBuffer) must be completed
- Task 15 (File Pre-Scanning) must be completed

## Requirements

### 1. Update ReusableBuffer Growth Strategy
Modify `src/reusable_buffer.zig` to support custom growth factor:

**Add method:**
```zig
/// Ensures capacity, growing by specified percentage if needed
pub fn ensureCapacityWithGrowth(self: *ReusableBuffer, new_capacity: usize, growth_percent: u8) !void {
    if (new_capacity <= self.capacity) return;
    
    const growth_factor = @as(f32, @floatFromInt(100 + growth_percent)) / 100.0;
    const new_size = @max(
        new_capacity,
        @as(usize, @intFromFloat(@as(f32, @floatFromInt(self.capacity)) * growth_factor))
    );
    
    try self.ensureCapacity(new_size);
}
```

**Update `append()` method:**
```zig
pub fn append(self: *ReusableBuffer, item: u8) !void {
    if (self.items.len >= self.capacity) {
        // Grow by 30% when capacity is reached
        try self.ensureCapacityWithGrowth(self.items.len + 1, 30);
    }
    // ... rest of append logic
}
```

**Growth Strategy:**
- **30% growth** when capacity is exceeded (per user requirement)
- C++ version uses 50% (line 696: `size * 150 / 100`), but user requested 30%
- Growth ensures we don't reallocate too frequently

### 2. Update `src/lib.zig`
Integrate scanning into the parsing flow:

**Modify `parseString()` function:**
```zig
pub fn parseString(allocator: Allocator, content: []const u8) !Env {
    // Pre-scan for buffer size hints
    const hints = file_scanner.scanBufferSizes(content);
    
    var stream = EnvStream.init(content);
    
    // Pass hints to readPairs
    var pairs = try reader.readPairsWithHints(allocator, &stream, hints);
    errdefer memory.deletePairs(allocator, &pairs);
    
    // ... rest of existing logic
}
```

### 3. Update `src/reader.zig`
Add new function that uses capacity hints:

**New function:**
```zig
pub fn readPairsWithHints(
    allocator: std.mem.Allocator, 
    stream: *EnvStream,
    hints: file_scanner.BufferSizeHints
) !std.ArrayList(EnvPair) {
    var pairs = std.ArrayList(EnvPair).init(allocator);
    errdefer memory.deletePairs(allocator, &pairs);

    while (true) {
        // Use capacity hints for initialization
        var pair = try EnvPair.initWithCapacity(
            allocator,
            hints.max_key_size,
            hints.max_value_size
        );

        const result = try readPair(allocator, stream, &pair);
        
        // ... rest of existing readPairs logic
    }

    return pairs;
}
```

**Keep existing `readPairs()` for backward compatibility:**
```zig
pub fn readPairs(allocator: std.mem.Allocator, stream: *EnvStream) !std.ArrayList(EnvPair) {
    // Use default hints (0 capacity = start small)
    const default_hints = file_scanner.BufferSizeHints{
        .max_key_size = 0,
        .max_value_size = 0,
    };
    return readPairsWithHints(allocator, stream, default_hints);
}
```

### 4. Testing

**Integration Tests:**
```zig
test "parsing with pre-scan optimization" {
    const allocator = testing.allocator;
    const content = 
        \\SMALL=x
        \\MEDIUM_KEY=medium_value
        \\VERY_LONG_KEY_NAME=very_long_value_content_here
    ;
    
    var env = try parseString(allocator, content);
    defer env.deinit();
    
    // Should work correctly with pre-scanned sizes
    try testing.expectEqualStrings("x", env.get("SMALL").?);
    try testing.expectEqualStrings("medium_value", env.get("MEDIUM_KEY").?);
    try testing.expectEqualStrings("very_long_value_content_here", env.get("VERY_LONG_KEY_NAME").?);
}

test "parsing with underestimated buffers grows correctly" {
    const allocator = testing.allocator;
    
    // Create content where value is longer than scanner might estimate
    const content = 
        \\KEY="""
        \\This is a heredoc with lots of content
        \\that might not be perfectly estimated
        \\by the pre-scanner heuristic
        \\"""
    ;
    
    var env = try parseString(allocator, content);
    defer env.deinit();
    
    // Should still parse correctly even if initial size was wrong
    try testing.expect(env.get("KEY") != null);
    try testing.expect(std.mem.indexOf(u8, env.get("KEY").?, "heredoc") != null);
}
```

**Performance Test:**
```zig
test "large file performance" {
    const allocator = testing.allocator;
    
    // Generate a large env file
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    
    for (0..1000) |i| {
        try buffer.writer().print("KEY_{d}=VALUE_{d}\n", .{i, i});
    }
    
    var env = try parseString(allocator, buffer.items);
    defer env.deinit();
    
    try testing.expectEqual(@as(usize, 1000), env.map.count());
}
```

### 5. Update Documentation

**Update README.md section on performance:**
```markdown
## Performance Optimizations

### Memory Allocation Strategy
1. **Pre-Scanning**: The parser scans the file content once to determine optimal buffer sizes
2. **Smart Growth**: Buffers grow by 30% when capacity is exceeded
3. **Single Allocation**: For most common cases, buffers are allocated once at the correct size

This reduces allocation overhead by ~60-80% for typical .env files.
```

## Success Criteria
- [ ] ReusableBuffer supports 30% growth factor
- [ ] `readPairsWithHints()` implemented in reader.zig
- [ ] `parseString()` uses pre-scanning
- [ ] Backward compatibility maintained (`readPairs()` still works)
- [ ] All existing tests pass
- [ ] New integration tests pass
- [ ] Performance tests show reduced allocations
- [ ] Documentation updated

## Performance Expectations

**Before (without pre-scanning):**
- Average 3-5 reallocations per key/value pair
- Many small allocations

**After (with pre-scanning):**
- 1 allocation per key/value pair (common case)
- 1-2 reallocations for edge cases (heredocs, unusual formats)
- ~70% reduction in allocation count for typical files

## Edge Case Handling

| Scenario | Behavior |
|----------|----------|
| Scanner underestimates | Buffers grow by 30% automatically |
| Scanner overestimates | Minor waste, but still bounded |
| Heredocs (common) | Scanner estimates well |
| Heredocs (complex) | May underestimate, but growth handles it |
| Comments/empty lines | Correctly ignored by scanner |

## Notes
- The 30% growth rate balances memory waste vs reallocation frequency
- C++ uses 50%, but user requested 30% (more conservative)
- Pre-scanning adds ~2-5% overhead but saves much more on allocations
- For very small files (<100 bytes), pre-scanning overhead may exceed benefits
  - This is acceptable - optimization targets real-world files (>1KB)

## Future Optimizations (Out of Scope)
- Adaptive growth rate based on file size
- Buffer pooling/reuse across multiple parses
- Memory-mapped file support for very large files
