---
type: task
status: todo
title: Remove ArrayListUnmanaged Usage Completely
---

# Task: Remove ArrayListUnmanaged Usage Completely

## Objective
Remove all remaining instances of `std.ArrayListUnmanaged` from the codebase. The goal is to move towards a more predictable memory management model where we pre-allocate the required space for pairs and other collections based on early estimates from the parser or known constraints in tests.

## Files to Address
- `src/data/env_value.zig`: `interpolations: std.ArrayListUnmanaged(VariablePosition)`
- `src/parser/read_pair.zig`: `readPairs` and related functions returning `ArrayListUnmanaged(EnvPair)`
- `src/interpolation/finalizer.zig`: Functions like `finalizeAllValues` taking `*ArrayListUnmanaged(EnvPair)`
- `src/buffer/memory_utils.zig`: Functions like `deletePairs` taking `*ArrayListUnmanaged(EnvPair)`
- `benchmarks/framework.zig`: Usage of `ArrayListUnmanaged(u64)` for samples.
- `tests/fuzz_tests.zig`: General cleanup of `ArrayListUnmanaged`.
- `tests/performance_regression_tests.zig`: General cleanup.
- `tests/stress_tests.zig`: General cleanup.

## Implementation Details

### 1. New Type for Pairs
Create a new specialized type to hold `EnvPair` objects. This type should probably live in `src/data/env_pair_list.zig` (or similar).
- **Behavior**: It should allow for pre-allocation (initial capacity).
- **Growth**: If the initial estimate is wrong (e.g., due to complex structures like heredocs that the reader might miscalculate), it should support reallocation.
- **Internal Storage**: Likely a managed or unmanaged slice with capacity tracking, similar to `ReusableBuffer` but for `EnvPair` items.

### 2. Testing-Specific Collection Type
In testing scenarios, we often know exactly how many items we are dealing with. 
- Create a dedicated type for tests to hold collections of various things (pairs, strings, etc.) that can be initialized with a fixed size.
- This helps avoid the overhead and complexity of dynamic growth when not needed.

### 3. Interpolations in `EnvValue`
The `interpolations` field in `EnvValue` is currently an `ArrayListUnmanaged(VariablePosition)`.
- Replace this with a more efficient structure, possibly using the same logic as the new pair collection type or a specialized fixed-size buffer if the number of interpolations is small on average.

### 4. Refactoring Parser and Finalizer
- Update `src/parser/read_pair.zig` to use the new pair list type instead of returning `ArrayListUnmanaged`.
- Update `src/interpolation/finalizer.zig` signature to accept the new pair list type.
- Update `src/buffer/memory_utils.zig` to handle the new type.

## Success Criteria
- [ ] No occurrences of `std.ArrayListUnmanaged` or `std.ArrayList` remain in the `src/` directory.
- [ ] No occurrences remain in `benchmarks/` or `tests/`.
- [ ] All tests pass.
- [ ] Benchmarks show either parity or improvement in performance due to reduced dynamic reallocations.

## Verbose Context from User
> We want to remove arraylist completely. In most cases we should know how many pairs we will need. Lets create a new type to hold our pairs. If we need to reallocate more space (i.e. the reader is wrong about how many pairs which might happen with a heredoc) then that is fine.
> In the testing we know how many so create another type for testing to hold various things.
