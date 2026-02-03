# Windows Carriage Return Handling

## Objective
When reading .env files on Windows, automatically strip `\r` (carriage return) characters before `\n` (newline) to handle Windows-style line endings (CRLF) gracefully.

## Background
Windows uses `\r\n` (CRLF) for line endings, while Unix uses `\n` (LF). When parsing .env files created on Windows, the `\r` characters can end up in values, causing issues:

```
KEY=value\r\n  # Windows format
```

Without handling, the value would be `value\r` instead of `value`.

## Requirements

### 1. Detect Windows Platform
Use Zig's built-in target detection:

```zig
const builtin = @import("builtin");
const is_windows = builtin.os.tag == .windows;
```

### 2. Update EnvStream (`src/env_stream.zig`)
Modify the `get()` function to filter `\r` on Windows:

```zig
pub fn get(self: *EnvStream) ?u8 {
    if (!self.is_good or self.index >= self.length) {
        self.is_good = false;
        return null;
    }

    const char = self.data[self.index];
    self.index += 1;
    
    // On Windows, skip \r before \n
    if (comptime is_windows) {
        if (char == '\r') {
            // Peek at next char
            if (self.index < self.length and self.data[self.index] == '\n') {
                // Skip the \r, return the \n
                return self.get();
            }
        }
    }
    
    return char;
}
```

### 3. Compile-Time Check
The Windows check should be at **compile-time** using `comptime`, so there's zero runtime overhead on non-Windows platforms:

```zig
if (comptime is_windows) {
    // This code is only compiled on Windows
}
```

This means:
- On Linux/macOS: No extra comparison at all
- On Windows: Only check `\r` when we encounter it (nested check)

### 4. Alternative: Handle at Read Time
If modifying `EnvStream.get()` is complex, could alternatively handle in `readValue`:

```zig
// In readValue, when adding to buffer:
if (comptime is_windows) {
    if (char == '\r') {
        // Don't add \r to buffer if next char is \n
        continue;
    }
}
```

**Recommended approach:** Handle in `EnvStream.get()` for consistency.

## Files to Modify

| File | Changes |
|------|---------|
| `src/env_stream.zig` | Filter `\r\n` → `\n` on Windows in `get()` |

## Clood Groups
- `basic-reading.json`

## Test Cases

```zig
test "CRLF handling" {
    // Simulate Windows-style content
    const content = "KEY=value\r\nOTHER=test\r\n";
    var stream = EnvStream.init(content);
    
    // Read characters
    var result: [20]u8 = undefined;
    var i: usize = 0;
    while (stream.get()) |c| {
        result[i] = c;
        i += 1;
    }
    
    // On Windows, \r should be stripped
    // On Unix, behavior depends on implementation choice
    if (comptime builtin.os.tag == .windows) {
        try testing.expectEqualStrings("KEY=value\nOTHER=test\n", result[0..i]);
    }
}

test "standalone CR not stripped" {
    // Only \r\n pairs should be collapsed, not standalone \r
    const content = "KEY=val\rue\n";  // CR in middle of value
    var stream = EnvStream.init(content);
    
    // Should preserve standalone \r
    // ... test logic
}
```

## Success Criteria
- [x] `\r\n` is converted to `\n` on Windows
- [x] Standalone `\r` (not followed by `\n`) is preserved
- [x] Zero runtime overhead on non-Windows platforms (comptime check)
- [x] Existing tests pass
- [x] New CRLF tests pass on Windows
- [x] No memory leaks introduced

## Implementation Notes

### Why Compile-Time Check?
```zig
if (comptime is_windows) {
    // Entire block is eliminated by compiler on non-Windows
}
```

This is better than:
```zig
if (is_windows) {
    // Runtime check on every character - wasteful
}
```

### Nested Check Pattern
Per user request, nest the `\r` check under the Windows check:

```zig
if (comptime is_windows) {
    if (char == '\r') {
        // Handle...
    }
}
```

This ensures:
1. Non-Windows: Zero overhead
2. Windows: Only one check per character (for `\r`)
3. Windows + found `\r`: Additional peek for `\n`

### Edge Cases

| Scenario | Behavior |
|----------|----------|
| `\r\n` | Convert to `\n` |
| `\r` (standalone) | Preserve as-is |
| `\n\r` | Preserve both (unusual but valid) |
| `\r\r\n` | Convert to `\r\n` (only last `\r` stripped) |

## Future Considerations
- Could add option to force CRLF handling on all platforms (for cross-platform consistency)
- Could add option to preserve all line endings exactly (for linting/validation tools)
