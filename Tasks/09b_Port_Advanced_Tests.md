# Task 09b: Port Advanced Test Cases

## Objective
Port the advanced C++ test cases including interpolation, heredocs, and edge cases.

## Estimated Time
2-3 hours

## Background
These tests validate the complex features: variable interpolation, circular dependency detection, heredoc parsing, and edge cases. Only tackle this after Task 09a passes 100%.

## Test Cases to Port

### Interpolation Tests

#### 1. InterpolateValues (Basic interpolation)
- **C++ Test**: `DotEnvTest::InterpolateValues`
- **What it tests**: Basic `${var}` substitution
- **Sample**:
  ```
  NAME=Alice
  GREETING=Hello ${NAME}
  ```
- **Expected**: `GREETING` = `"Hello Alice"`

#### 2. InterpolateValuesAdvanced (Chained interpolation)
- **C++ Test**: `DotEnvTest::InterpolateValuesAdvanced`
- **What it tests**: Variables referencing other variables
- **Sample**:
  ```
  A=x
  B=${A}
  C=${B}
  ```
- **Expected**: Recursive resolution, `C` = `"x"`

#### 3. InterpolateValuesCircular (Circular dependency)
- **C++ Test**: `DotEnvTest::InterpolateValuesCircular`
- **What it tests**: Circular reference detection
- **Sample**:
  ```
  A=${B}
  B=${A}
  ```
- **Expected**: Variables stay as literals `"${B}"` and `"${A}"`

#### 4. InterpolateValuesEscaped (Escaped interpolation)
- **C++ Test**: `DotEnvTest::InterpolateValuesEscaped`
- **What it tests**: `\${var}` should NOT interpolate
- **Sample**: `KEY=\${VAR}`
- **Expected**: Literal `"${VAR}"` text

#### 5. InterpolateUnClosed (Unclosed braces)
- **C++ Test**: `DotEnvTest::InterpolateUnClosed`
- **What it tests**: `${var` without closing `}` is ignored
- **Sample**: `KEY=${UNCLOSED`
- **Expected**: Literal `"${UNCLOSED"` (no interpolation)

### Heredoc Tests

#### 6. TripleSingleQuotedWithMoreGarbage
- **C++ Test**: `DotEnvTest::TripleSingleQuotedWithMoreGarbage`
- **What it tests**: Heredoc with trailing garbage on closing line
- **Sample**:
  ```
  KEY='''multi
  line
  value'''garbage here is ignored
  ```
- **Expected**: Multi-line value, garbage after `'''` is cleared

#### 7. DoubleQuotedHereDoc (Multi-line with escapes)
- **C++ Test**: `DotEnvTest::DoubleQuotedHereDoc`
- **What it tests**: Triple double quotes with escape processing
- **Sample**:
  ```
  KEY="""line1\nline2"""
  ```
- **Expected**: Actual newline character in multi-line value

#### 8. DoubleQuotedHereDoc2 (Heredoc with interpolation)
- **C++ Test**: `DotEnvTest::DoubleQuotedHereDoc2`
- **What it tests**: Heredoc with variable interpolation
- **Sample**:
  ```
  VAR=test
  KEY="""Value: ${VAR}"""
  ```
- **Expected**: Multi-line with interpolation resolved

### Edge Case Tests

#### 9. Empty Values
- **Test**: Empty quoted values
- **Sample**: `KEY=""`
- **Expected**: Empty string value

#### 10. Whitespace Trimming in Interpolation
- **Test**: `${ VAR }` with spaces
- **Sample**:
  ```
  VAR=value
  KEY=${ VAR }
  ```
- **Expected**: Spaces inside `${}` are trimmed

#### 11. Windows Line Endings
- **Test**: Files with `\r\n`
- **Sample**: `KEY=value\r\n`
- **Expected**: Works same as `\n`

## Checklist

- [ ] Create advanced test files
- [ ] Port **InterpolateValues** test
  - [ ] Basic substitution
  - [ ] Multiple interpolations
- [ ] Port **InterpolateValuesAdvanced** test
  - [ ] Chained references
  - [ ] Order independence
- [ ] Port **InterpolateValuesCircular** test
  - [ ] Direct circular
  - [ ] Indirect circular
  - [ ] Verify literals preserved
- [ ] Port **InterpolateValuesEscaped** test
  - [ ] Escaped dollar sign
  - [ ] No interpolation
- [ ] Port **InterpolateUnClosed** test
  - [ ] Unclosed brace handling
  - [ ] No crash
- [ ] Port **TripleSingleQuotedWithMoreGarbage** test
  - [ ] Heredoc parsing
  - [ ] Garbage clearing
- [ ] Port **DoubleQuotedHereDoc** test
  - [ ] Multi-line values
  - [ ] Escape processing
- [ ] Port **DoubleQuotedHereDoc2** test
  - [ ] Heredoc with interpolation
  - [ ] Multiple interpolations
- [ ] Port additional edge case tests
  - [ ] Empty values
  - [ ] Whitespace in `${}`
  - [ ] Windows line endings
- [ ] Run all tests: `zig build test`
- [ ] Verify 100% pass rate

## Dependencies
- Task 09a (Basic Tests) - **must be 100% passing first**
- All implementation tasks complete

## Test Files to Create
- `test/interpolation.zig` (or inline)
- `test/heredoc.zig` (or inline)
- `test/edge_cases.zig` (or inline)

## Notes
- These tests are integration tests - they exercise multiple subsystems
- Circular dependency tests are critical for correctness
- Heredoc tests validate multi-line parsing
- **Do not proceed until Task 09a is 100% passing**
- Use `std.testing.allocator` to catch leaks
- Some tests may involve multiple .env file scenarios

## Expected Output
```
Test [1/11] interpolate values... OK
Test [2/11] interpolate values advanced... OK
Test [3/11] interpolate values circular... OK
Test [4/11] interpolate values escaped... OK
Test [5/11] interpolate unclosed... OK
Test [6/11] triple single quoted with garbage... OK
Test [7/11] double quoted heredoc... OK
Test [8/11] double quoted heredoc2... OK
Test [9/11] empty values... OK
Test [10/11] whitespace in interpolation... OK
Test [11/11] windows line endings... OK
All 11 tests passed.
```

## Success Criteria
- All 11+ advanced tests passing
- No memory leaks detected
- Combined with Task 09a: 17+ total tests passing
- Ready for final build configuration (Task 10)
