# Implement File Pre-Scanning for Buffer Optimization

## Objective
Implement a pre-scanning pass over `.env` file content to determine optimal initial buffer sizes for keys and values, reducing allocations during actual parsing.

## Background
Currently, buffers are allocated with default sizes and grow dynamically. To optimize memory allocation performance:
1. Read entire file into memory first (already done in `parseFile`)
2. Scan the content to find the largest key and largest value
3. Pre-allocate buffers based on this scan
4. Handle heredocs as edge cases (they're uncommon but can be large)

## Requirements

### 1. Create `src/file_scanner.zig`
Implement a file content scanner with the following:

**Primary Function:**
```zig
pub fn scanBufferSizes(content: []const u8) BufferSizeHints {
    // Returns suggested buffer sizes
}
```

**BufferSizeHints Struct:**
```zig
pub const BufferSizeHints = struct {
    max_key_size: usize,
    max_value_size: usize,
};
```

**Scanning Strategy:**
- Scan for `=` characters (key/value separator)
- Calculate distance from line start to `=` for key size
- Calculate distance from `=` to next newline for value size
- **Heredoc Detection Heuristic:**
  - If line contains `=` followed eventually by newline
  - AND next line has NO `=` on it
  - Consider it might be a heredoc value continuation
  - Add that line's length to the current value estimate
  - Continue until a line with `=` is found

**Edge Cases to Handle:**
- Comments (lines starting with `#`)
- Empty lines
- Lines with multiple `=` signs (take first as key/value separator)
- Quoted values that span multiple lines (heredocs)
- Windows line endings (`\r\n`)

### 2. Update `src/env_pair.zig`
Add initialization with capacity hints:

```zig
pub fn initWithCapacity(allocator: std.mem.Allocator, key_capacity: usize, value_capacity: usize) !EnvPair {
    return EnvPair{
        .key = try EnvKey.initCapacity(allocator, key_capacity),
        .value = try EnvValue.initCapacity(allocator, value_capacity),
    };
}
```

### 3. Update `src/env_key.zig` and `src/env_value.zig`
Add capacity initialization methods (assuming ReusableBuffer exists from Task 10):

**EnvKey:**
```zig
pub fn initCapacity(allocator: std.mem.Allocator, capacity: usize) !EnvKey {
    return EnvKey{
        .key = "",
        .buffer = try ReusableBuffer.initCapacity(allocator, capacity),
        .key_index = 0,
    };
}
```

**EnvValue:** (similar pattern)

### 4. Testing

**Unit Tests for Scanner:**
```zig
test "scan simple key=value" {
    const content = "KEY=value";
    const hints = scanBufferSizes(content);
    try testing.expectEqual(@as(usize, 3), hints.max_key_size);  // "KEY"
    try testing.expectEqual(@as(usize, 5), hints.max_value_size); // "value"
}

test "scan multiple lines" {
    const content = "SHORT=x\nLONGER_KEY=longer_value";
    const hints = scanBufferSizes(content);
    try testing.expectEqual(@as(usize, 10), hints.max_key_size);  // "LONGER_KEY"
    try testing.expectEqual(@as(usize, 12), hints.max_value_size); // "longer_value"
}

test "scan with heredoc" {
    const content = 
        \\KEY="""
        \\This is a long heredoc value
        \\"""
    ;
    const hints = scanBufferSizes(content);
   // Should detect multi-line value
    try testing.expect(hints.max_value_size > 25);
}

test "scan ignores comments" {
    const content = "#KEY=comment\nREAL=value";
    const hints = scanBufferSizes(content);
    try testing.expectEqual(@as(usize, 4), hints.max_key_size); // "REAL"
}
```

### 5. Integration

Do NOT integrate into the main parsing flow yet. This task is just about:
- Creating the scanner
- Adding the capacity initialization methods
- Proving the concept works with tests

**Note:** Integration will happen in Task 16.

## Success Criteria
- [x] `src/file_scanner.zig` created with `scanBufferSizes()` function
- [x] `BufferSizeHints` struct defined
- [x] Heredoc detection heuristic implemented
- [x] `initCapacity()` methods added to EnvKey and EnvValue
- [x] `initWithCapacity()` added to EnvPair
- [x] All unit tests pass
- [x] Scanner handles edge cases (comments, empty lines, Windows endings)
- [x] Module exported in `src/root.zig`

## Dependencies
- Task 10 (ReusableBuffer must exist for capacity initialization)

## Notes
- This is a **heuristic approach** - it won't be perfect, especially with complex heredocs
- The goal is to reduce allocations for the common case (90%+ of env files)
- If the scanner underestimates, buffers will still grow dynamically (handled in Task 16)
- Keep the scanner simple - don't implement full parsing logic
- Performance target: scanning should be fast (single pass, minimal allocations)

## Performance Considerations
- Single pass over the content
- No allocations during scanning (just counting/measuring)
- O(n) where n is the file size
- Should add minimal overhead (<1% of total parse time)
