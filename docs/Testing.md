# Testing Strategy

Zig-Env uses a comprehensive testing strategy ensuring robustness, performance, and compatibility.

## Test Categories

### 1. Integration Tests
- **File-based Tests**: Tests parsing of real `.env` files located in `tests/fixtures/`.
- **Interpolation Tests**: Covers variable expansion, including nested and circular references.
- **Whitespace Tests**: Ensures correct handling of whitespace around keys, values, and interpolation logic.

### 2. Edge Cases & Fuzzing
- **Edge Cases**: Tests extreme scenarios like empty files, special characters, and weird formatting.
- **Fuzz Tests**: Uses random input generation to ensure the parser doesn't crash on garbage data.
- **Stress Tests**: Validates behavior under high load (large files, deep nesting).

### 3. Compatibility & Properties
- **Compatibility**: Tests verifying behavior matches other `.env` parsers (Node.js, Python, Ruby, Go).
- **Property Tests**: Verifies invariant properties (e.g. `parse(print(env)) == env`).

### 4. Platform Specifics
- **Windows Tests**: Ensures correct handling of CRLF line endings and Windows file paths.
- **Unicode Support**: Verifies correct parsing of Emoji, CJK, and RTL scripts.

## Running Tests

To run the full test suite:
```bash
zig build test
```

## Adding New Tests

Add new test files to `tests/` and register them in `build.zig` under the `test_files` array.
Ensure new tests follow the pattern of creating an `allocator` and properly cleaning up resources to detect memory leaks.
