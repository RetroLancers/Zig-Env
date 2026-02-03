# Extensive Test Suite with File-Based Testing

## Objective
Create an extensive, comprehensive test suite that includes file-based tests, stress tests, edge cases, fuzzing, and property-based testing to ensure the parser is robust and production-ready.

## Prerequisites
- All existing basic and advanced tests must pass
- Tasks 18, 19, 20 (heredocs, braceless variables, Windows line endings) completed

## Requirements

### 1. File-Based Integration Tests

**Create `tests/file_based_tests.zig`:**

Test the parser against real `.env` files stored in the filesystem.

**Test Structure:**
```zig
const std = @import("std");
const zigenv = @import("zigenv");
const testing = std.testing;

// Helper to read and parse test .env files
fn testEnvFile(allocator: Allocator, path: []const u8) !zigenv.Env {
    return zigenv.parseFile(allocator, path);
}

test "real world .env file - Node.js project" {
    // tests/fixtures/nodejs_project.env
}

test "real world .env file - Python/Django project" {
    // tests/fixtures/django_project.env
}

test "real world .env file - Docker composition" {
    // tests/fixtures/docker_compose.env
}

test "real world .env file - CI/CD configuration" {
    // tests/fixtures/ci_cd_config.env
}

test "large file with 10,000+ entries" {
    // tests/fixtures/large_10k.env
}

test "file with complex interpolations" {
    // tests/fixtures/complex_interpolation.env
}

test "file with all feature types combined" {
    // tests/fixtures/kitchen_sink.env
}
```

**Create Test Fixtures Directory:**
- `tests/fixtures/` directory with various `.env` files representing real-world scenarios

**Fixture Examples:**

1. **`nodejs_project.env`** - Typical Node.js configuration
   ```
   NODE_ENV=production
   PORT=3000
   DATABASE_URL=postgresql://user:pass@localhost:5432/mydb
   REDIS_URL=redis://localhost:6379
   API_KEY="sk-1234567890abcdef"
   SECRET_KEY=${API_KEY}_${NODE_ENV}
   ```

2. **`django_project.env`** - Django settings
   ```
   DEBUG=False
   SECRET_KEY='django-insecure-...'
   DATABASE_URL=postgres://user:pass@postgres:5432/db
   ALLOWED_HOSTS=.example.com,.localhost
   ```

3. **`docker_compose.env`** - Docker environment
   ```
   POSTGRES_USER=admin
   POSTGRES_PASSWORD=secret123
   POSTGRES_DB=myapp
   COMPOSE_PROJECT_NAME=myproject
   ```

4. **`kitchen_sink.env`** - Everything combined
   ```
   # Comments
   SIMPLE=value
   EMPTY=
   QUOTED="quoted value"
   SINGLE='single quoted'
   HEREDOC="""
   multi
   line
   heredoc
   """
   INTERPOLATED=${SIMPLE}_extended
   BRACELESS=$SIMPLE
   WINDOWS_LINE_ENDINGS=value\r
   ESCAPED=\"quote\"
   ```

5. **`large_10k.env`** - Generated file with 10,000+ key-value pairs

### 2. Stress and Load Tests

**Create `tests/stress_tests.zig`:**

Test parser behavior under extreme conditions.

```zig
test "extremely long key (10KB)" {
    // KEY with 10,000 characters
}

test "extremely long value (1MB)" {
    // VALUE with 1,000,000 characters
}

test "deeply nested interpolation (100 levels)" {
    // VAR1=${VAR2}
    // VAR2=${VAR3}
    // ...
    // VAR100=final_value
}

test "1000 interpolations in single value" {
    // VALUE=${A}_${B}_${C}..._${ZZZ}
}

test "file with 100,000+ key-value pairs" {
    // Massive file, test memory efficiency
}

test "heredoc with 100MB content" {
    // Large heredoc value
}

test "1000 concurrent environment variable resolutions" {
    // Test parallelism/thread safety if applicable
}

test "rapid allocation/deallocation (1000 iterations)" {
    // Parse and free 1000 times to detect memory leaks
}

test "maximum line length (10MB single line)" {
    // Single key=value pair on 10MB line
}

test "unicode stress test - 10,000 emoji values" {
    // KEY1=🔥🎉💯...
    // Test UTF-8 handling
}
```

### 3. Edge Case and Error Handling Tests

**Create `tests/edge_cases_comprehensive.zig`:**

Test unusual inputs and error conditions.

```zig
test "empty file" {
    const content = "";
}

test "file with only comments" {
    const content = 
        \\# Comment 1
        \\# Comment 2
        \\# Comment 3
    ;
}

test "file with only whitespace" {
    const content = "   \n\t\r\n   ";
}

test "malformed heredoc - never closed" {
    const content = 
        \\KEY="""
        \\this heredoc never closes
    ;
    // Should error or handle gracefully
}

test "malformed quote - never closed" {
    const content = "KEY=\"unclosed";
    // Should error or handle gracefully
}

test "circular interpolation" {
    const content = 
        \\A=${B}
        \\B=${A}
    ;
    // Should detect and handle
}

test "interpolation referencing non-existent variable" {
    const content = "KEY=${DOES_NOT_EXIST}";
    // Should handle gracefully
}

test "duplicate keys - last one wins" {
    const content = 
        \\KEY=first
        \\KEY=second
        \\KEY=third
    ;
    // Verify "third" is the final value
}

test "key with special characters" {
    const content = "MY-KEY.NAME_123=value";
}

test "value with null bytes" {
    // Binary data or null terminators
}

test "mixed line endings (\\n, \\r\\n, \\r)" {
    // File with inconsistent line endings
}

test "BOM (Byte Order Mark) at start of file" {
    // UTF-8 BOM: EF BB BF
}

test "extremely nested quotes" {
    const content = "KEY=\"outer 'middle \"inner\" middle' outer\"";
}

test "backslash at end of line (continuation)" {
    const content = 
        \\KEY=value1\
        \\value2
    ;
    // Should this be supported?
}

test "equals sign in value without quotes" {
    const content = "KEY=value=with=equals";
}

test "leading/trailing whitespace handling" {
    const content = "  KEY  =  value  ";
}

test "tab characters in various positions" {
    const content = "\tKEY\t=\tvalue\t";
}
```

### 4. Fuzzing Tests

**Create `tests/fuzz_tests.zig`:**

Generate random/malformed input to find crashes.

```zig
test "fuzz - random byte sequences (1000 iterations)" {
    var prng = std.rand.DefaultPrng.init(0);
    const random = prng.random();
    
    for (0..1000) |_| {
        var buffer: [1024]u8 = undefined;
        random.bytes(&buffer);
        
        // Should not crash, even on garbage input
        _ = zigenv.parseString(allocator, &buffer) catch |err| {
            // Error is acceptable, crash is not
        };
    }
}

test "fuzz - random structure-aware input" {
    // Generate valid-looking but random .env content
    // Examples:
    // - Random key lengths
    // - Random value types (quoted, unquoted, heredoc)
    // - Random interpolations
    // - Random comments
}

test "fuzz - mutation-based (from valid files)" {
    // Take valid .env content and randomly mutate it
    // Flip bits, insert/delete characters, etc.
}
```

### 5. Property-Based Tests

**Create `tests/property_tests.zig`:**

Test invariant properties that should always hold.

```zig
test "property: parse(serialize(env)) == env" {
    // Round-trip test
    // Generate env, serialize to string, parse again
    // Should get same result
}

test "property: key count matches pairs parsed" {
    // Number of keys returned should equal pairs in file
}

test "property: all keys are unique (if configured)" {
    // Duplicate handling is consistent
}

test "property: interpolation is idempotent" {
    // Resolve once, resolve again = same result
}

test "property: memory is fully freed on deinit" {
    // No leaks after cleanup
}

test "property: parse order does not affect final values" {
    // (Except for dependencies/interpolations)
}

test "property: comments are always ignored" {
    // Content after # is never in values
}
```

### 6. Compatibility Tests

**Create `tests/compatibility_tests.zig`:**

Test compatibility with other .env parsers.

```zig
test "compatibility: dotenv (Ruby)" {
    // Test cases from Ruby dotenv library
}

test "compatibility: python-dotenv" {
    // Test cases from Python dotenv library
}

test "compatibility: dotenv (Node.js)" {
    // Test cases from Node.js dotenv library
}

test "compatibility: godotenv (Go)" {
    // Test cases from Go dotenv library
}

test "compatibility: cppnv (C++ - original source)" {
    // Port all C++ test cases (if not already done)
}
```

### 7. Unicode and Encoding Tests

**Create `tests/unicode_tests.zig`:**

```zig
test "UTF-8: emoji in keys and values" {
    const content = "🔑=🎉";
}

test "UTF-8: multi-byte characters" {
    const content = "日本語=こんにちは";
}

test "UTF-8: combining characters" {
    // é (e + combining acute accent)
}

test "UTF-8: right-to-left text (Arabic, Hebrew)" {
    const content = "مفتاح=قيمة";
}

test "UTF-8: zero-width characters" {
    // Zero-width space, joiner, etc.
}

test "invalid UTF-8 sequences" {
    // Should error or handle gracefully
}
```

### 8. Performance Regression Tests

**Create `tests/performance_regression_tests.zig`:**

```zig
test "regression: simple file parse time < 100μs" {
    // 100 key-value pairs should parse quickly
}

test "regression: large file (10k entries) < 10ms" {
    // Performance baseline
}

test "regression: allocation count for simple file" {
    // Should not increase over time
}

test "regression: memory usage for 1MB file" {
    // Should be predictable
}
```

### 9. Windows-Specific Tests

**Create `tests/windows_tests.zig`:**

```zig
test "Windows: CRLF line endings" {
    const content = "KEY=value\r\nOTHER=data\r\n";
}

test "Windows: mixed CRLF and LF" {
    const content = "KEY=value\r\nOTHER=data\n";
}

test "Windows: file paths with backslashes" {
    const content = "PATH=C:\\\\Users\\\\Admin\\\\file.txt";
}

test "Windows: UNC paths" {
    const content = "SHARE=\\\\\\\\server\\\\share\\\\file";
}
```

### 10. Error Message Quality Tests

**Create `tests/error_messages_tests.zig`:**

Verify error messages are helpful.

```zig
test "error message: unclosed quote shows line number" {
    // Error should indicate which line
}

test "error message: invalid interpolation syntax" {
    // Clear message about what's wrong
}

test "error message: file not found" {
    // Helpful message with file path
}

test "error message: permission denied" {
    // Clear indication of access issue
}
```

## Test Organization

```
tests/
├── basic_test.zig                    # Existing
├── quote_test.zig                    # Existing
├── escape_test.zig                   # Existing
├── interpolation_test.zig            # Existing
├── heredoc_test.zig                  # Existing
├── edge_cases.zig                    # Existing
├── garbage_after_quote.zig           # Existing
├── braceless_variable_test.zig       # Existing
├── single_quote_heredoc_test.zig     # Existing
├── file_based_tests.zig              # NEW
├── stress_tests.zig                  # NEW
├── edge_cases_comprehensive.zig      # NEW
├── fuzz_tests.zig                    # NEW
├── property_tests.zig                # NEW
├── compatibility_tests.zig           # NEW
├── unicode_tests.zig                 # NEW
├── performance_regression_tests.zig  # NEW
├── windows_tests.zig                 # NEW
├── error_messages_tests.zig          # NEW
└── fixtures/                         # NEW
    ├── nodejs_project.env
    ├── django_project.env
    ├── docker_compose.env
    ├── ci_cd_config.env
    ├── kitchen_sink.env
    ├── large_10k.env
    ├── complex_interpolation.env
    └── ... (more real-world examples)
```

## Success Criteria

- [ ] All 10 new test file categories created
- [ ] Minimum 20 real-world fixture files in `tests/fixtures/`
- [ ] At least 200+ total test cases across all files
- [ ] All tests pass
- [ ] No memory leaks detected (run with leak detection)
- [ ] Fuzz tests run for extended period without crashes
- [ ] Performance regression tests establish baselines
- [ ] Test coverage > 95% (if coverage tools available)
- [ ] Documentation updated with test strategy
- [ ] CI/CD pipeline updated to run all tests

## Clood Groups to Update/Create

- `file-based-testing.json` (new)
- `stress-testing.json` (new)
- `test-infrastructure.json` (update)

## Documentation

**Create `docs/Testing.md`:**

```markdown
# Testing Strategy

## Overview
Extensive test suite covering:
- Unit tests
- Integration tests
- File-based tests
- Stress tests
- Fuzzing
- Property-based tests
- Compatibility tests

## Running Tests

```bash
# All tests
zig build test

# Specific test file
zig build test -- file_based_tests

# With memory leak detection
zig build test --summary all

# Stress tests (may take time)
zig build test -- stress_tests

# Fuzz tests
zig build test -- fuzz_tests
```

## Test Coverage
[Include coverage metrics]

## Adding New Tests
[Guidelines for contributors]
```

## Files to Create/Modify

| File | Purpose |
|------|---------|
| `tests/file_based_tests.zig` | Test against real .env files |
| `tests/stress_tests.zig` | Extreme load and stress scenarios |
| `tests/edge_cases_comprehensive.zig` | Unusual inputs and error handling |
| `tests/fuzz_tests.zig` | Random input fuzzing |
| `tests/property_tests.zig` | Invariant property testing |
| `tests/compatibility_tests.zig` | Cross-parser compatibility |
| `tests/unicode_tests.zig` | Encoding and Unicode handling |
| `tests/performance_regression_tests.zig` | Performance baselines |
| `tests/windows_tests.zig` | Windows-specific scenarios |
| `tests/error_messages_tests.zig` | Error message quality |
| `tests/fixtures/*.env` | Real-world test data files |
| `build.zig` | Add all new test files |
| `docs/Testing.md` | Test documentation |

## Deliverables

3. **200+ new test cases** total
4. **Test documentation** in `docs/Testing.md`
5. **Updated build configuration** to run all tests
6. **CI/CD integration** (if applicable)
7. **Coverage report** (if tooling available)

## Notes

- **File Generation**: Use scripts to generate large test files (e.g., `large_10k.env`)
- **Real-World Examples**: Collect actual `.env` files from open-source projects
- **Fuzzing Duration**: Run fuzz tests for extended periods (hours) to catch edge cases
- **Memory Profiling**: Use Zig's built-in leak detection and consider external tools
- **Cross-Platform**: Test on Windows, Linux, and macOS if possible
- **Benchmark Comparison**: Compare against C++ cppnv implementation
- **Test Isolation**: Ensure tests don't interfere with each other
- **Deterministic**: All tests should be deterministic (same input = same output)

## Future Enhancements (Out of Scope)

- Automated test generation based on grammar
- Mutation testing
- Code coverage visualization
- Performance trend tracking over time
- Integration with property-based testing frameworks
- Automated comparison with other parsers
- Security-focused fuzzing (AFL, libFuzzer)
