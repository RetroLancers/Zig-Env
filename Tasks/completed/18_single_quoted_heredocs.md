# Single Quote Heredocs Support

## Objective
Add an option to allow heredocs (multi-line strings) to be created using single quotes (`'`) and double quotes (`"`) without requiring the triple-quote (`"""` or `'''`) syntax.

## Background
Currently, heredocs require triple-quote syntax:
```
KEY="""
this is a
heredoc value
"""
```

This task adds support for standard single/double quote multi-line strings:
```
KEY="this
is a heredoc"

OTHER='this is a heredoc
as well'
```

This makes the parser more compatible with bash-style multi-line strings.

## Requirements

### 1. Update Quote Parser (`src/quote_parser.zig`)
Modify the quote tracking logic to allow newlines within quoted strings:

**Current behavior:**
- `"` starts double-quote mode, newline terminates the value (not allowed inside)

**New behavior (when option enabled):**
- `"` starts double-quote mode, newline is allowed inside the quoted string
- Closing `"` ends the quoted section
- Same logic applies for single quotes `'`

### 2. Add Configuration Option
Create a parser options struct to enable this behavior:

```zig
pub const ParserOptions = struct {
    allow_single_line_heredocs: bool = false,  // Default: false for backward compat
    // ... future options
};
```

### 3. Update Reader (`src/reader.zig`)
Modify `readValue` and `readNextChar` to handle newlines within quoted strings:
- When inside double quotes and option is enabled, `\n` should be added to buffer
- When inside single quotes and option is enabled, `\n` should be added to buffer
- Only terminate value when closing quote is found

### 4. Update EnvValue (`src/env_value.zig`)
May need additional state tracking for:
- Whether we're in a "simple heredoc" (quote-based) mode
- Track which quote character started the heredoc

## Files to Modify

| File | Changes |
|------|---------|
| `src/quote_parser.zig` | Allow newlines within quoted sections when option enabled |
| `src/reader.zig` | Pass options through, handle newlines in quotes |
| `src/env_value.zig` | Add state tracking if needed |
| `src/lib.zig` | Accept parser options in public API |
| `test/quotes.zig` | Add tests for single-quote heredocs |

## Clood Groups
- `quote-processing.json`
- `character-reading.json`
- `value-pair-reading.json`

## Test Cases

```zig
test "double quote heredoc" {
    const content = 
        \\KEY="this
        \\is a heredoc"
    ;
    var env = try parseStringWithOptions(allocator, content, .{ .allow_single_line_heredocs = true });
    defer env.deinit();
    
    try testing.expectEqualStrings("this\nis a heredoc", env.get("KEY").?);
}

test "single quote heredoc" {
    const content = 
        \\KEY='this is a heredoc
        \\as well'
    ;
    var env = try parseStringWithOptions(allocator, content, .{ .allow_single_line_heredocs = true });
    defer env.deinit();
    
    try testing.expectEqualStrings("this is a heredoc\nas well", env.get("KEY").?);
}

test "option disabled preserves old behavior" {
    // Without the option, newlines should still terminate values
    const content = 
        \\KEY="this
        \\OTHER=value
    ;
    var env = try parseString(allocator, content);
    defer env.deinit();
    
    // Should parse as two separate pairs (old behavior)
    try testing.expect(env.get("OTHER") != null);
}
```

## Success Criteria
- [x] Parser options struct created (`src/parser_options.zig`)
- [x] Quote parser allows newlines when option enabled (modified `src/reader.zig`)
- [x] Reader correctly handles newlines in quoted strings
- [x] Public API accepts options (`parseStringWithOptions`, `parseFileWithOptions`, `parseReaderWithOptions`)
- [x] New tests pass (`tests/single_quote_heredoc_test.zig`)
- [x] Existing tests still pass (backward compatibility)
- [ ] Documentation updated with new option

## Implementation Notes
- Created `src/parser_options.zig` with `ParserOptions` struct
- Modified `src/reader.zig` to accept and pass through `ParserOptions`
- Added `parseStringWithOptions`, `parseFileWithOptions`, `parseReaderWithOptions` to `src/lib.zig`
- Exported `ParserOptions` and new functions in `src/root.zig`
- Created comprehensive tests in `tests/single_quote_heredoc_test.zig`
- Updated clood groups: `quote-processing.json`, `character-reading.json`, `value-pair-reading.json`, `public-api.json`

## Notes
- This should be **opt-in** to maintain backward compatibility
- Consider interaction with escape sequences (e.g., `\"` inside heredoc)
- Consider interaction with variable interpolation inside quoted heredocs

