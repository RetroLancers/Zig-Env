# Variables Without Braces Support

## Objective
Add an option to support variable interpolation without requiring curly braces, similar to bash/dotenv syntax:

```bash
somevalue=1
someotherval=$somevalue somewhere
```

Currently, only `${VAR}` syntax is supported. This task adds support for `$VAR` syntax.

## Background
Bash and dotenv support multiple variable reference syntaxes:
- `${VAR}` - explicit braces (already supported)
- `$VAR` - no braces, variable name ends at first non-identifier character

This makes the parser more compatible with standard shell/dotenv files.

## Requirements

### 1. Add Configuration Option
Extend parser options to enable brace-less variables:

```zig
pub const ParserOptions = struct {
    allow_single_line_heredocs: bool = false,
    allow_braceless_variables: bool = false,  // Default: false for backward compat
};
```

### 2. Update Interpolation Logic (`src/interpolation.zig`)
Modify variable detection to support `$VAR` syntax:

**Current behavior:**
- `${` triggers `openVariable()`
- `}` triggers `closeVariable()`

**New behavior (when option enabled):**
- `$` followed by valid identifier char triggers variable start
- Variable ends when:
  - Non-identifier character encountered (space, newline, special chars)
  - End of value reached
  - Another `$` encountered (start of next variable)

**Valid identifier characters:** `a-z`, `A-Z`, `0-9`, `_`

### 3. Update Reader (`src/reader.zig`)
Modify `readNextChar` to handle `$VAR` syntax:

```zig
'$' => {
    if (options.allow_braceless_variables) {
        // Peek next char to determine if it's ${...} or $VAR
        // If next char is '{', use existing logic
        // If next char is valid identifier start, start braceless variable
    }
    // ... existing logic
}
```

### 4. Variable Termination Logic
Need to track when a braceless variable ends:

```zig
fn isValidIdentifierChar(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_';
}

// In readNextChar, after processing each character:
if (value.is_parsing_braceless_variable) {
    if (!isValidIdentifierChar(char)) {
        // Close the variable and process this char normally
        try interpolation.closeVariable(allocator, value);
    }
}
```

### 5. Update EnvValue (`src/env_value.zig`)
Add state for braceless variable tracking:

```zig
is_parsing_braceless_variable: bool = false,
```

## Files to Modify

| File | Changes |
|------|---------|
| `src/interpolation.zig` | Add braceless variable open/close logic |
| `src/reader.zig` | Detect `$VAR` syntax, handle termination |
| `src/env_value.zig` | Add braceless variable state flag |
| `src/lib.zig` | Accept parser options in public API |
| `test/interpolation.zig` | Add tests for braceless variables |

## Clood Groups
- `variable-interpolation.json`
- `character-reading.json`
- `value-pair-reading.json`

## Test Cases

```zig
test "braceless variable basic" {
    const content = 
        \\BASE=hello
        \\RESULT=$BASE world
    ;
    var env = try parseStringWithOptions(allocator, content, .{ .allow_braceless_variables = true });
    defer env.deinit();
    
    try testing.expectEqualStrings("hello world", env.get("RESULT").?);
}

test "braceless variable at end of value" {
    const content = 
        \\BASE=hello
        \\RESULT=say $BASE
    ;
    var env = try parseStringWithOptions(allocator, content, .{ .allow_braceless_variables = true });
    defer env.deinit();
    
    try testing.expectEqualStrings("say hello", env.get("RESULT").?);
}

test "mixed brace and braceless" {
    const content = 
        \\A=1
        \\B=2
        \\RESULT=$A and ${B}
    ;
    var env = try parseStringWithOptions(allocator, content, .{ .allow_braceless_variables = true });
    defer env.deinit();
    
    try testing.expectEqualStrings("1 and 2", env.get("RESULT").?);
}

test "braceless variable with special chars" {
    const content = 
        \\PATH=/usr/bin
        \\FULL=$PATH:/local/bin
    ;
    var env = try parseStringWithOptions(allocator, content, .{ .allow_braceless_variables = true });
    defer env.deinit();
    
    try testing.expectEqualStrings("/usr/bin:/local/bin", env.get("FULL").?);
}

test "option disabled ignores $VAR" {
    const content = 
        \\RESULT=$VAR literal
    ;
    var env = try parseString(allocator, content);
    defer env.deinit();
    
    // Without option, $VAR is treated literally
    try testing.expectEqualStrings("$VAR literal", env.get("RESULT").?);
}
```

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| `$VAR` at end of line | Variable closes at newline |
| `$VAR$OTHER` | Two variables back-to-back |
| `$123` | Not a variable (starts with digit) |
| `$_VALID` | Valid (underscore is allowed) |
| `$VAR.txt` | Variable is `VAR`, `.txt` is literal |
| `$$VAR` | Escaped `$`, then literal `VAR` |
| `${}` | Empty brace syntax (existing behavior) |

## Success Criteria
- [ ] Parser options extended with `allow_braceless_variables`
- [ ] Interpolation logic handles `$VAR` syntax
- [ ] Variable termination works correctly at word boundaries
- [ ] Mixed `${VAR}` and `$VAR` syntax works
- [ ] New tests pass
- [ ] Existing tests still pass (backward compatibility)
- [ ] Edge cases handled correctly
- [ ] Documentation updated

## Notes
- This should be **opt-in** to maintain backward compatibility
- Consider performance: we need to peek ahead or track state for variable termination
- The `${VAR}` syntax should still work regardless of option
- Variable names follow same rules as keys: alphanumeric + underscore
