# Pre-Scanner Pair Count Estimation

## Objective
Extend the file pre-scanner to also estimate the number of environment key-value pairs in the file. This allows pre-allocation of the pairs array (e.g., `std.ArrayList(EnvPair)`), reducing dynamic growth/reallocation during parsing.

## Background
The current pre-scanner (Task 15) estimates buffer sizes for keys and values, but we still allocate the pairs array with a default size and grow it dynamically. Since the scanner already iterates over all lines looking for `=` signs, we can count them as a heuristic for the number of pairs with minimal additional overhead.

**Note:** Heredocs and multiline values will cause slight over-counting (we count each `=` even if it's inside a value), but over-estimation is acceptable—it just means we might allocate a bit more than needed, which is better than under-allocating and needing to reallocate.

## Requirements

### 1. Update `BufferSizeHints` struct in `src/file_scanner.zig`

Add a new field for pair count estimation:

```zig
pub const BufferSizeHints = struct {
    max_key_size: usize,
    max_value_size: usize,
    estimated_pair_count: usize,  // NEW
};
```

### 2. Update `scanBufferSizes()` function

Modify the scanning logic to count the number of key-value pairs:

**Counting Strategy:**
- Increment `estimated_pair_count` each time we encounter a new `key=value` line (i.e., a line with an `=` that isn't a comment)
- This naturally happens at the same point where we already detect `std.mem.indexOfScalar(u8, line, '=')`
- Skip counting for comment lines (already handled)

**Implementation hint:**
```zig
if (std.mem.indexOfScalar(u8, line, '=')) |equal_idx| {
    // Only count if the line isn't a comment (already filtered above)
    hints.estimated_pair_count += 1;  // ADD THIS LINE
    
    // ... existing logic ...
}
```

### 3. Update callers of `scanBufferSizes()`

Update any existing code that uses `BufferSizeHints` to handle the new field. This likely includes:
- `src/lib.zig` (if already integrated from Task 16)
- Any test code

### 4. Add pre-allocation support for pairs

Update the parsing entry points to use the pair count estimate:

**In `src/lib.zig` (or wherever pairs are collected):**
```zig
// Before parsing, pre-allocate pairs array
const hints = file_scanner.scanBufferSizes(content);
var pairs = try std.ArrayList(EnvPair).initCapacity(allocator, hints.estimated_pair_count);
```

### 5. Testing

**Add unit tests for pair counting:**

```zig
test "scan counts single pair" {
    const content = "KEY=value";
    const hints = scanBufferSizes(content);
    try testing.expectEqual(@as(usize, 1), hints.estimated_pair_count);
}

test "scan counts multiple pairs" {
    const content = "A=1\nB=2\nC=3";
    const hints = scanBufferSizes(content);
    try testing.expectEqual(@as(usize, 3), hints.estimated_pair_count);
}

test "scan counts pairs with heredocs (may overcount)" {
    const content = 
        \\KEY="""
        \\multiline with = sign inside
        \\"""
        \\ANOTHER=value
    ;
    const hints = scanBufferSizes(content);
    // May count 2 or 3 depending on heuristic (= inside heredoc)
    // The important thing is it's >= 2 (actual pair count)
    try testing.expect(hints.estimated_pair_count >= 2);
}

test "scan ignores comments for pair count" {
    const content = "#COMMENT=ignored\nREAL=value";
    const hints = scanBufferSizes(content);
    try testing.expectEqual(@as(usize, 1), hints.estimated_pair_count);
}

test "scan counts pairs with empty lines" {
    const content = "A=1\n\nB=2\n\nC=3";
    const hints = scanBufferSizes(content);
    try testing.expectEqual(@as(usize, 3), hints.estimated_pair_count);
}
```

## Success Criteria
- [x] `BufferSizeHints` struct updated with `estimated_pair_count` field
- [x] `scanBufferSizes()` counts pairs during scanning
- [x] Pair count is reasonably accurate for simple files
- [x] Heredocs cause acceptable over-counting (not under-counting)
- [x] All existing tests still pass
- [x] New pair count tests added and passing
- [x] Callers updated to use the new field (if applicable)
- [x] Pre-allocation of pairs array implemented where feasible

## Dependencies
- Task 15 (file_scanner.zig must exist) ✓
- Task 16 (integration with parsing flow) ✓

## Notes
- **Over-counting is acceptable**, under-counting is not. We're optimizing for the common case.
- The count is a **heuristic** - it doesn't need to be perfect.
- This should add **zero additional overhead** since we're already iterating over all lines.
- For files without heredocs, the count should be exact.
- For files with heredocs containing `=` signs, we'll over-allocate slightly (harmless).

## Performance Considerations
- No additional iteration—counting happens in the same pass
- One additional counter increment per pair (negligible)
- Memory benefit: fewer reallocations when building the pairs array
- Especially beneficial for large .env files with many entries
