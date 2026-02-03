# Task 09a: Port Basic Test Cases

## Objective
Port the fundamental C++ test cases to Zig's built-in test framework, focusing on basic parsing functionality.

## Estimated Time
2-3 hours

## Background
These tests validate the core parsing behavior without complex features like interpolation or heredocs. Get these passing first before moving to advanced tests.

## Test Cases to Port

### 1. ReadDotEnvFile (Basic file parsing)
- **C++ Test**: `DotEnvTest::ReadDotEnvFile`
- **What it tests**: Basic key=value parsing from a file
- **Sample .env content**:
  ```
  KEY1=value1
  KEY2=value2
  # comment
  KEY3=value3
  ```
- **Expected**: 3 pairs with correct keys and values

### 2. ImplicitDoubleQuote (Unquoted values)
- **C++ Test**: `DotEnvTest::ImplicitDoubleQuote`
- **What it tests**: Unquoted values with whitespace trimming
- **Sample**: `KEY=  value with spaces  `
- **Expected**: Value is trimmed of trailing spaces
- **Verifies**: Implicit double quote mode and right-trimming

### 3. DoubleQuotes (Double quote handling)
- **C++ Test**: `DotEnvTest::DoubleQuotes`
- **What it tests**: Basic double quote parsing
- **Sample**: `KEY="quoted value"`
- **Expected**: Value without quotes
- **Verifies**: Quote removal, escape processing enabled

### 4. SingleQuoted (Single quote behavior)
- **C++ Test**: `DotEnvTest::SingleQuoted`
- **What it tests**: Single quotes preserve everything literally
- **Sample**: `KEY='literal \n ${var}'`
- **Expected**: Exactly `literal \n ${var}` (no escapes, no interpolation)
- **Verifies**: No escape processing, no interpolation in single quotes

### 5. BackTickQuote (Backtick quotes)
- **C++ Test**: `DotEnvTest::BackTickQuote`
- **What it tests**: Backtick quote behavior
- **Sample**: `` KEY=`value` ``
- **Expected**: Backticks behave like double quotes
- **Verifies**: Escape processing and interpolation enabled

### 6. ControlCodes (Escape sequences)
- **C++ Test**: `DotEnvTest::ControlCodes`
- **What it tests**: All escape sequence conversions
- **Sample**: `KEY="line1\nline2\ttab"`
- **Expected**: Actual newline and tab characters in value
- **Verifies**: All control character mappings (`\n`, `\t`, `\r`, `\b`, `\f`, `\v`, `\a`, `\"`, `\'`, `\\`)

## Implementation Approach

### Zig Test Structure
```zig
const std = @import("std");
const testing = std.testing;
const parser = @import("root.zig");

test "basic file parsing" {
    const allocator = testing.allocator;
    
    const content = 
        \\KEY1=value1
        \\KEY2=value2
        \\# comment
        \\KEY3=value3
    ;
    
    var pairs = try parser.parseString(allocator, content);
    defer pairs.deinit();
    
    try testing.expectEqual(@as(usize, 3), pairs.items.len);
    try testing.expectEqualStrings("KEY1", pairs.items[0].key.key);
    try testing.expectEqualStrings("value1", pairs.items[0].value.value);
    // ... more assertions
}
```

### Test Organization
- Create `test/` directory at project root
- One file per test category:
  - `test/basic_parsing.zig` - ReadDotEnvFile, ImplicitDoubleQuote
  - `test/quotes.zig` - DoubleQuotes, SingleQuoted, BackTickQuote
  - `test/escapes.zig` - ControlCodes
- Or use inline tests in source files

## Checklist

- [ ] Create test file structure
- [ ] Port **ReadDotEnvFile** test
  - [ ] Multi-line content
  - [ ] Comments
  - [ ] Multiple pairs
- [ ] Port **ImplicitDoubleQuote** test
  - [ ] Unquoted values
  - [ ] Whitespace trimming
  - [ ] Right-trim behavior
- [ ] Port **DoubleQuotes** test
  - [ ] Basic double quotes
  - [ ] Empty double quotes
  - [ ] Quotes removed from value
- [ ] Port **SingleQuoted** test
  - [ ] Literal escapes
  - [ ] No interpolation
  - [ ] Literal ${var}
- [ ] Port **BackTickQuote** test
  - [ ] Backtick parsing
  - [ ] Escape processing enabled
- [ ] Port **ControlCodes** test
  - [ ] `\n` → newline
  - [ ] `\t` → tab
  - [ ] `\r` → carriage return
  - [ ] `\b` → backspace
  - [ ] `\f` → form feed
  - [ ] `\v` → vertical tab
  - [ ] `\a` → alert
  - [ ] `\"` → quote
  - [ ] `\'` → quote
  - [ ] `\\` → backslash
- [ ] Run all tests: `zig build test`
- [ ] Verify all tests pass

## Dependencies
- Task 08 (File I/O and Public API) - needs public parsing functions
- All implementation tasks (01-07)

## Test Files to Create
- `test/basic_parsing.zig` (or inline tests)
- `test/quotes.zig` (or inline tests)
- `test/escapes.zig` (or inline tests)

## Notes
- Use `std.testing.allocator` to catch memory leaks
- Each test should clean up all allocated memory
- Compare exact string content, not just length
- Windows line endings (`\r\n`) should be handled correctly
- These tests form the foundation - **must pass 100% before moving to 09b**

## Expected Output
```
Test [1/6] basic file parsing... OK
Test [2/6] implicit double quote... OK
Test [3/6] double quotes... OK
Test [4/6] single quoted... OK
Test [5/6] backtick quote... OK
Test [6/6] control codes... OK
All 6 tests passed.
```
