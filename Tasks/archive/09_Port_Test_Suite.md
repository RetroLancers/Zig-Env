# Task 09: Port Test Suite

## Objective
Port all test cases from `test_dotenv.cc` to Zig's built-in test framework.

## Background
The C++ implementation has comprehensive tests using Google Test. These need to be ported to Zig's `test` blocks to ensure feature parity.

## Test Categories to Port

### Basic Parsing Tests
- `DotEnvTest::ReadDotEnvFile` - Basic key-value parsing with various formats

### Quote Type Tests
- `DotEnvTest::DoubleQuotes` - Double quoted values
- `DotEnvTest::SingleQuoted` - Single quoted values (no escapes/interpolation)
- `DotEnvTest::SingleQuotedWithGarbage` - Trailing garbage after quotes
- `DotEnvTest::SingleQuotedWithMoreGarbage` - More edge cases
- `DotEnvTest::BackTickQuote` - Backtick quoted values

### Heredoc Tests
- `DotEnvTest::SingleQuotedHereDoc` - Triple single quotes
- `DotEnvTest::DoubleQuotedHereDoc` - Triple double quotes
- `DotEnvTest::DoubleQuotedHereDocWithGarbage` - Heredoc with trailing content
- `DotEnvTest::DoubleQuotedHereDoc2` - Complex heredoc with interpolation
- `DotEnvTest::DoubleQuotedHereDoc3` - Heredoc with comments
- `DotEnvTest::TripleSingleQuotedWithMoreGarbage` - More heredoc edge cases

### Implicit Quote Tests
- `DotEnvTest::ImplicitDoubleQuote` - Unquoted values treated as double-quoted

### Escape Sequence Tests
- `DotEnvTest::ControlCodes` - `\t`, `\n`, `\r`, `\b`, `\\`, etc.

### Interpolation Tests
- `DotEnvTest::InterpolateValues` - Basic `${var}` substitution
- `DotEnvTest::InterpolateValuesAdvanced` - Chained interpolation
- `DotEnvTest::InterpolateValuesCircular` - Circular dependency detection
- `DotEnvTest::InterpolateValuesEscaped` - Escaped `\${var}` syntax
- `DotEnvTest::InterpolateUnClosed` - Unclosed `${var` syntax
- `DotEnvTest::HEREDOCDoubleQuote` - Heredoc with interpolation

## Test Structure in Zig

```zig
const std = @import("std");
const lib = @import("../lib.zig");

test "basic key value parsing" {
    const allocator = std.testing.allocator;
    const input = "a=bc\nb=cdd\n";
    
    var env = try lib.parseString(allocator, input);
    defer env.deinit();
    
    try std.testing.expectEqualStrings("bc", env.get("a").?);
    try std.testing.expectEqualStrings("cdd", env.get("b").?);
}
```

## Checklist

- [ ] Create `src/tests/` directory
- [ ] Create `src/tests/basic_test.zig`
- [ ] Create `src/tests/quote_test.zig`
- [ ] Create `src/tests/heredoc_test.zig`
- [ ] Create `src/tests/escape_test.zig`
- [ ] Create `src/tests/interpolation_test.zig`
- [ ] Port all 16+ test cases from C++
- [ ] Add additional Zig-specific edge case tests
- [ ] Ensure all tests pass with `zig build test`

## Dependencies
- All previous tasks (complete library implementation)
