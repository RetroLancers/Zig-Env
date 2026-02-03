# C++ to Zig Test Coverage Matrix

This document maps every test case from `cppnv/cppnv/test_dotenv.cc` to our Zig test implementation to ensure complete test parity.

## Test Coverage Matrix

| # | C++ Test Name | Lines | Status | Zig Test Location | Task |
|---|---------------|-------|--------|-------------------|------|
| 1 | `ReadDotEnvFile` | 14-46 | ✅ Covered | `tests/basic_test.zig` | Task 09a |
| 2 | `DoubleQuotes` | 48-72 | ✅ Covered | `tests/quote_test.zig` | Task 09a |
| 3 | `TripleSingleQuotedWithMoreGarbage` | 74-101 | ✅ Covered | `tests/heredoc_test.zig` | Task 09b |
| 4 | `SingleQuotedWithMoreGarbage` | 103-130 | ❌ **MISSING** | N/A | **Task 11** |
| 5 | `SingleQuotedWithGarbage` | 132-151 | ❌ **MISSING** | N/A | **Task 11** |
| 6 | `BackTickQuote` | 153-187 | ✅ Covered | `tests/quote_test.zig` | Task 09a |
| 7 | `ImplicitDoubleQuote` | 189-214 | ✅ Covered | `tests/basic_test.zig` | Task 09a |
| 8 | `SingleQuoted` | 216-235 | ✅ Covered | `tests/quote_test.zig` | Task 09a |
| 9 | `DoubleQuotedHereDocWithGarbage` | 237-266 | ❌ **MISSING** | N/A | **Task 11** |
| 10 | `DoubleQuotedHereDoc2` | 268-335 | ✅ Covered | `tests/heredoc_test.zig` | Task 09b |
| 11 | `DoubleQuotedHereDoc3` | 338-410 | ✅ Covered | `tests/heredoc_test.zig` | Task 09b |
| 12 | `DoubleQuotedHereDoc` | 412-439 | ✅ Covered | `tests/heredoc_test.zig` | Task 09b |
| 13 | `SingleQuotedHereDoc` | 441-465 | ✅ Covered | `tests/heredoc_test.zig` | Task 09b |
| 14 | `ControlCodes` | 467-501 | ✅ Covered | `tests/escape_test.zig` | Task 09a |
| 15 | `InterpolateValues` | 503-534 | ✅ Covered | `tests/interpolation_test.zig` | Task 09b |
| 16 | `InterpolateValuesCircular` | 536-560 | ✅ Covered | `tests/interpolation_test.zig` | Task 09b |
| 17 | `HEREDOCDoubleQuote` | 563-584 | ❌ **MISSING** | N/A | **Task 11** |
| 18 | `InterpolateValuesAdvanced` | 586-616 | ✅ Covered | `tests/interpolation_test.zig` | Task 09b |
| 19 | `InterpolateUnClosed` | 618-638 | ✅ Covered | `tests/interpolation_test.zig` | Task 09b |
| 20 | `InterpolateValuesEscaped` | 641-672 | ✅ Covered | `tests/interpolation_test.zig` | Task 09b |

## Summary

- **Total C++ Tests**: 20
- **Covered**: 16 (80%)
- **Missing**: 4 (20%)

## Missing Tests (Task 11)

The following 4 tests are **NOT YET COVERED** in our Zig implementation:

1. **SingleQuotedWithMoreGarbage** (line 103)
   - Tests single quotes with extensive trailing garbage
   - Tests comments mixed with garbage cases
   - Tests hash characters inside single quotes (should be literal)

2. **SingleQuotedWithGarbage** (line 132)
   - Tests basic single quote garbage handling
   - Tests empty single quotes with garbage

3. **DoubleQuotedHereDocWithGarbage** (line 237)
   - Tests heredoc closing markers with trailing garbage
   - Tests both multi-line and inline heredocs
   - Ensures interpolation still works with garbage present

4. **HEREDOCDoubleQuote** (line 563)
   - Tests unclosed heredoc at EOF
   - Tests interpolation of heredoc values
   - Tests whitespace in interpolation syntax `$ {var }`

## Common Themes in Missing Tests

All 4 missing tests focus on **garbage handling** - ensuring that content appearing after closing quotes is properly discarded:

- After single quote: `'value' garbage`
- After heredoc closing: `'''value''' garbage`
- Unclosed heredoc edge cases

This is a critical behavior for parser robustness and data integrity.

## Test File Organization

### Current Zig Test Files
- `tests/basic_test.zig` - Basic parsing, implicit quotes
- `tests/quote_test.zig` - Single, double, backtick quotes
- `tests/escape_test.zig` - Escape sequences, control codes
- `tests/heredoc_test.zig` - Heredoc (triple quotes)
- `tests/interpolation_test.zig` - Variable interpolation
- `tests/edge_cases.zig` - Edge cases and boundary conditions

### Recommended Addition
- `tests/garbage_after_quote.zig` - All garbage handling tests (Task 11)

## Action Items

- [x] Identify missing tests by comparing C++ test file to task documentation
- [x] Create comprehensive test coverage matrix
- [ ] Complete Task 11 to achieve 100% test parity
- [ ] Verify all 20 C++ tests have corresponding Zig tests
- [ ] Run complete test suite to ensure 100% pass rate

## Notes

- This matrix should be updated whenever new tests are added
- Any new C++ tests should be ported to Zig for parity
- Consider adding this matrix to CI/CD documentation
- The missing tests are all related to a single parsing behavior (garbage clearing)
- Once Task 11 is complete, we'll have full feature parity with the C++ implementation
