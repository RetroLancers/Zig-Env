# Task: Memory Leak Testing for Bun Integration Features

## Context
We have recently ported `Zig-Env` to support integration into the Bun codebase. This involved adding support for `export` keywords, colon separators, and enhanced variable interpolation (defaults and external lookups). While the features are implemented, we have not yet verified that these new additions are free of memory leaks.

## Objective
Create and run a comprehensive suite of tests explicitly designed to detect memory leaks in the newly added Bun integration features using Zig's testing allocator.

## Scope
The testing should focus on the following files and features which were modified or added during the port:

### Target Files and Features
1.  **`src/parser/read_key.zig`**
    *   **Feature**: `export` prefix support.
    *   **Feature**: Colon (`:`) separator support.
2.  **`src/data/variable_position.zig`**
    *   **Feature**: Storage and management of `default_value`.
3.  **`src/interpolation/finalizer.zig`**
    *   **Feature**: Handling of `${VAR:-DEFAULT}` syntax.
    *   **Feature**: Integration with external `LookupFn` and `context`.
4.  **`src/env.zig` (or equivalent main entry point)**
    *   **Feature**: API functions like `parseStringWithOptions` passing through new options.

## detailed Logic/Steps

### 1. Setup Test Infrastructure
*   Ensure we have a test file (e.g., `tests/bun_integration_memory_test.zig`) that imports the relevant modules.
*   Use `std.testing.allocator` for all allocations to ensure automatic leak detection.

### 2. Implement Test Cases

#### A. Parser Options Extensions (Export & Colon)
*   **Test**: Parse a string containing `export KEY=VALUE`.
*   **Test**: Parse a string containing `KEY: VALUE`.
*   **Test**: Parse mixed content with standard assignments and new extensions.
*   **Check**: Ensure `EnvMap` or `ManagedList` is freed correctly and `testing.allocator` reports no leaks.

#### B. Interpolation with Defaults
*   **Test**: Parse `${VAR:-default_value}` where `VAR` is missing.
*   **Test**: Parse `${VAR:-default_value}` where `VAR` is present.
*   **Check**: Verify `default_value` strings are allocated and freed correctly within `VariablePosition` and the final buffer.

#### C. External Lookup Function
*   **Test**: Provide a mock `LookupFn` that returns specific strings (allocated).
*   **Check**: Ensure that strings returned by the lookup function (if ownership is transferred or copied) are handled correctly without leaking.
*   *Note*: Verify ownership semantics of the `LookupFn` result.

### 3. Verify & Fix
*   Run `zig build test`.
*   If leaks are detected, use Valgrind or Zig's leak reporter trace to identify the source.
*   Fix any identified leaks in the implementation files.

## Definition of Done
*   [ ] A new test suite targeting Bun features is created.
*   [ ] Tests for `export` prefix pass with no leaks.
*   [ ] Tests for colon separator pass with no leaks.
*   [ ] Tests for `${VAR:-DEFAULT}` pass with no leaks.
*   [ ] Tests for external lookup callback pass with no leaks.
*   [ ] CI (if applicable) or local `zig build test` passes 100%.
