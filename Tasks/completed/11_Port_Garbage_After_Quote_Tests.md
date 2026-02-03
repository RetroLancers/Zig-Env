# Task 11: Port "Garbage After Quote" Test Cases

## Objective
Port the C++ test cases that validate proper handling of trailing content (garbage) after closing quotes. These tests ensure that content after a closing quote is correctly ignored.

## Estimated Time
1-2 hours

## Background
The C++ codebase includes several tests that verify the parser ignores content that appears after closing quotes (single quotes, heredocs, etc.). This is important behavior for compatibility and robustness. Our current test suite doesn't explicitly cover these cases.

## Test Cases to Port

### 1. SingleQuotedWithGarbage
- **C++ Test**: `DotEnvTest::SingleQuotedWithGarbage` (line 132-151)
- **What it tests**: Content after single quote closing is ignored
- **Sample**:
  ```
  a='\\t ${b}' asdfasdf
  b='' asdfasdf
  ```
- **Expected**: 
  - `a` = `"\\t ${b}"` (escapes and vars are literal in single quotes)
  - Garbage `asdfasdf` after the closing quote is discarded
  - `b` = `""` (empty string, garbage ignored)

### 2. SingleQuotedWithMoreGarbage
- **C++ Test**: `DotEnvTest::SingleQuotedWithMoreGarbage` (line 103-130)
- **What it tests**: More complex single quote scenarios with garbage and comments
- **Sample**:
  ```
  a='\\t ${b}' asdfasdf
  b='' asdfasdf
  c='a' asdfasdf
  # blah
  
  f='# fek' garfa
  ```
- **Expected**:
  - All values are literal (no escape processing, no interpolation)
  - All trailing garbage after closing quotes is cleared
  - Comments and blank lines work correctly
  - `f` = `"# fek"` (hash is literal inside quotes, `garfa` garbage ignored)

### 3. DoubleQuotedHereDocWithGarbage
- **C++ Test**: `DotEnvTest::DoubleQuotedHereDocWithGarbage` (line 237-266)
- **What it tests**: Heredoc closing markers with trailing garbage
- **Sample**:
  ```
  b=1
  a="""
  \\t
  ${b}
  """ abc
  c="""def""" asldkljasdfl;kj
  ```
- **Expected**:
  - `a` should have multi-line value with interpolation and escape processing
  - Garbage `abc` after closing `"""` is cleared
  - `c` = `"def"` with garbage `asldkljasdfl;kj` cleared

### 4. HEREDOCDoubleQuote (Unclosed Heredoc)
- **C++ Test**: `DotEnvTest::HEREDOCDoubleQuote` (line 563-584)
- **What it tests**: Unclosed heredoc handling
- **Sample**:
  ```
  a="""
  heredoc
  """
  b=${a}
  c=""" $ {b }
  ```
- **Expected**:
  - `a` = `"\nheredoc\n"` (complete heredoc)
  - `b` = `"\nheredoc\n"` (interpolated from `a`)
  - `c` should handle unclosed heredoc scenario (EOF while in heredoc)

## Implementation Approach

### New Test File
Create `test/garbage_after_quote.zig`:

```zig
const std = @import("std");
const testing = std.testing;
const lib = @import("lib");

test "single quoted with garbage" {
    const allocator = testing.allocator;
    
    const content =
        \\a='\\t ${b}' asdfasdf
        \\b='' asdfasdf
    ;
    
    const env = try lib.parseString(allocator, content);
    defer lib.freeEnv(env, allocator);
    
    try testing.expectEqual(@as(usize, 2), env.len);
    try testing.expectEqualStrings("\\t ${b}", lib.get(env, "a").?);
    try testing.expectEqualStrings("", lib.get(env, "b").?);
}

test "single quoted with more garbage" {
    // ... test implementation
}

test "double quoted heredoc with garbage" {
    // ... test implementation  
}

test "heredoc double quote unclosed" {
    // ... test implementation
}
```

## Checklist

- [x] Create `test/garbage_after_quote.zig`
- [x] Port **SingleQuotedWithGarbage** test
  - [x] Single quote parsing
  - [x] Garbage after closing quote
  - [x] Empty single quotes with garbage
- [x] Port **SingleQuotedWithMoreGarbage** test
  - [x] Multiple cases
  - [x] Comments work with garbage
  - [x] Hash inside quotes is literal
- [x] Port **DoubleQuotedHereDocWithGarbage** test
  - [x] Heredoc with garbage on closing line
  - [x] Short heredoc with inline garbage
  - [x] Interpolation still works
- [x] Port **HEREDOCDoubleQuote** test
  - [x] Complete heredoc
  - [x] Interpolate heredoc value
  - [x] Unclosed heredoc at EOF
- [x] Update `build.zig` to include new test file
- [x] Run all tests: `zig build test`
- [x] Verify all new tests pass
- [x] Create or update clood group for garbage tests

## Dependencies
- Tasks 09a and 09b must be completed
- All implementation code must support garbage clearing

## Files to Create/Modify
- **Create**: `test/garbage_after_quote.zig`
- **Update**: `build.zig` (add new test file)
- **Update**: `clood-groups/garbage-tests.json` (new clood group)

## Notes
- These tests validate a subtle but important parsing behavior
- The parser should consume content after a closing quote until newline/EOF
- This is different from comment handling (which starts with `#`)
- Proper garbage handling prevents data leakage between values
- The C++ code clears the buffer after quote closing - our Zig code should do the same
- Edge case: What if garbage contains another quote? Should still be ignored.

## Expected Output
```
Test [1/4] single quoted with garbage... OK
Test [2/4] single quoted with more garbage... OK
Test [3/4] double quoted heredoc with garbage... OK
Test [4/4] heredoc double quote unclosed... OK
All 4 tests passed.
```

## Success Criteria
- All 4 new tests passing
- No memory leaks detected
- Combined with previous tests: 21+ total tests passing
- 100% parity with C++ test suite in `test_dotenv.cc`

## Additional Observations
After this task, we should verify we have full coverage by creating a test matrix that maps:
- All C++ tests in `test_dotenv.cc` → Corresponding Zig test
- This ensures no test case is missed in the port
