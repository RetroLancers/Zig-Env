---
type: task
status: completed
title: Expand Test Coverage to Match C++ Implementation
---

# Expand Test Coverage to Match C++ Implementation

## Objective
Expand the Zig-Env test suite to fully cover all edge cases found in the original C++ `test_dotenv.cc` implementation. While most features are covered, we need to ensure exact parity for complex quoting and spacing scenarios.

## Completed Tasks

### 1. Complex Backtick Usage
The current `backtick quote` test is simple (`KEY=`value``). We need to verify that backticks can contain other quote types and vice-versa, as tested in C++.

- [x] Add backticks containing double and single quotes to `tests/quote_test.zig`:
  `KEY=`double "quotes" and single 'quotes' work inside backticks``
  -> Expect: `double "quotes" and single 'quotes' work inside backticks`
- [x] Add backticks inside single quotes (should be literal) to `tests/quote_test.zig`:
  `KEY='`backticks` work inside single quotes'`
  -> Expect: ``backticks` work inside single quotes`
- [x] Add backticks inside double quotes (should be literal) to `tests/quote_test.zig`:
  `KEY="`backticks` work inside double quotes"`
  -> Expect: ``backticks` work inside double quotes`

### 2. Implicit Double Quote Spacing
Verify that unquoted values with leading/trailing spaces are trimmed correctly, but internal spaces are preserved.

- [x] Add padding test to `tests/quote_test.zig`:
  `key=    some spaced out string    `
  -> Expect: `some spaced out string` (verify leading/trailing spaces are trimmed)

### 3. Complex Heredoc Scenarios
Ensure comments and garbage immediately following a heredoc closing delimiter are correctly ignored.

- [x] Add "Heredoc with Comment" test to `tests/garbage_after_quote.zig`:
  ```properties
  message="""Greetings
  ...
  """ #k
  cc_message="${message}"
  ```
  Verify that `#k` is ignored and does not affect the next key `cc_message`.
- [x] Port `DoubleQuotedHereDoc3` variations from C++ to `tests/garbage_after_quote.zig`.

### 4. Control Codes Parity
Port the exact `ControlCodes` test from C++ to ensure all escape sequence combinations are handled identically.

- [x] Port `ControlCodes` array to `tests/escape_test.zig`:
  - Input:
    ```properties
    a=\tb\n
    b=\\\\
    c=\\\\t
    d="\\\\\t"
    e=" \\ \\ \ \\ \\\\t"
    f=" \\ \\ \b \\ \\\\t"
    g=" \\ \\ \r \\ \\\\b\n"
    ```
  - Verify exact output matches C++ expectations.

## Implementation Details
- Created new test cases in `tests/quote_test.zig`, `tests/garbage_after_quote.zig`, and `tests/escape_test.zig`.
- Verified all new tests pass with `zig build test`.
