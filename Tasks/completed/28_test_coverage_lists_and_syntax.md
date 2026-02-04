---
type: task
status: completed
title: Test Coverage for Custom Lists and Syntax Extensions
---

# Task: Test Coverage for Custom Lists and Syntax Extensions

## Objective
We recently replaced `std.ArrayListUnmanaged` with custom managed types (`EnvPairList`, `VariablePositionList`, `ManagedList`) to improve performance and memory control. We need to ensure these new structures have comprehensive unit tests handling edge cases.
Additionally, we need to verify and ensure support for `export` keyword prefixes and `:` separators in .env files, adding tests to confirm compliance.

## Subtasks

### 1. Custom List Unit Tests
Create a new test file `tests/custom_lists_test.zig` (or expand existing ones) to cover:
- [x] **EnvPairList**:
    - Initialization and Deinitialization.
    - Capacity growth (ensureTotalCapacity).
    - Appending items (forcing growth).
    - `clearRetainingCapacity` behavior.
    - `deletePairs` integration (memory cleanup).
- [x] **VariablePositionList**:
    - Similar lifecycle tests (init, deinit, append, clear).
    - **Crucial**: Test `orderedRemove` logic thoroughly (used in finalizer). Ensure shifting logic is correct.
- [x] **ManagedList**:
    - General usage tests.

### 2. Syntax Feature Tests
- [x] **Export Keyword**:
    - Create/Update tests to ensure lines like `export KEY=VALUE` are parsed correctly as `KEY=VALUE`.
    - If support is missing, implement the parsing logic to strip `export ` prefix.
- [x] **Colon Separator**:
    - Create/Update tests for `KEY: VALUE` syntax.
    - Verify behavior for `KEY:VALUE` (no space) vs `KEY: VALUE` (space).
    - Ensure it works alongside `=` usage.

### 3. Verify Compatibility
- [x] Run `tests/compatibility_tests.zig` and ensure the `export` and other relevant tests pass.

## Success Criteria
- [x] All new list types have dedicated test suites passing.
- [x] `export KEY=VAL` syntax is supported and tested.
- [x] `KEY: VAL` syntax is supported (if desirable) and tested.
- [x] Zero memory leaks in new tests.
