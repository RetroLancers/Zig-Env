# Fix Bun Integration Garbage Output

## Context
The previous task `29_bun_integration_memory_tests` was completed, but a persistent failure in `bun_integration_memory_test.zig` remains.
The failure shows garbage output in default values, e.g., "hello world" becoming weird characters.
This is likely a Use-After-Free or buffer management issue where `VariablePosition` or `Finalizer` accesses invalid memory after buffer reallocation.

## Objective
Fix the garbage output issue in `bun_integration_memory_test.zig` and ensure no memory leaks.

## Steps
- [ ] Analyze `VariablePosition` usage in parser to ensure string safety.
- [ ] Fix `VariablePosition` string storage (ensure ownership or safe offsets).
- [ ] Verify fix with `zig build test`.
- [ ] Ensure no memory leaks with `bun_integration_memory_test`.
