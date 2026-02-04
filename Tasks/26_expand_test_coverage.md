---
type: task
status: todo
title: Expand Test Coverage to Match C++ Implementation
---

## Objective
Expand the Zig-Env test suite to fully cover all edge cases found in the original C++ `test_dotenv.cc` implementation. While most features are covered, we need to ensure exact parity for complex quoting and spacing scenarios.

## Missing Test Cases

### 1. Complex Backtick Usage
The current `backtick quote` test is simple (`KEY=`value``). We need to verify that backticks can contain other quote types and vice-versa, as tested in C++.

**Add the following cases to `tests/quote_test.zig`:**
- Backticks containing double and single quotes:
  `KEY=`double "quotes" and single 'quotes' work inside backticks``
  -> Expect: `double "quotes" and single 'quotes' work inside backticks`
- Backticks inside single quotes (should be literal):
  `KEY='`backticks` work inside single quotes'`
  -> Expect: ``backticks` work inside single quotes`
- Backticks inside double quotes (should be literal):
  `KEY="`backticks` work inside double quotes"`
  -> Expect: ``backticks` work inside double quotes`

### 2. Implicit Double Quote Spacing
Verify that unquoted values with leading/trailing spaces are trimmed correctly, but internal spaces are preserved.

**Add to `tests/file_based_tests.zig` or `tests/quote_test.zig`:**
- `key=    some spaced out string    `
  -> Expect: `some spaced out string` (verify leading/trailing spaces are trimmed)

### 3. Complex Heredoc Scenarios
Ensure comments and garbage immediately following a heredoc closing delimiter are correctly ignored.

**Add to `tests/garbage_after_quote.zig`:**
- **Double Quoted Heredoc with Comment**:
  ```properties
  message="""Greetings
  ...
  """ #k
  cc_message="${message}"
  ```
  Verify that `#k` is ignored and does not affect the next key `cc_message`.
- **Heredoc with specific whitespace variations** matching `DoubleQuotedHereDoc3` in C++.

### 4. Control Codes Parity
Port the exact `ControlCodes` test from C++ to ensure all escape sequence combinations are handled identically.

**Add to `tests/escape_test.zig`:**
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
- Verify exact output matches C++ expectations (e.g., `\\` becoming `\`, `\t` becoming tab, etc.).

## Implementation Details
- Create a new test file or append to existing files as appropriate.
- Ensure all new tests pass with `zig build test`.
