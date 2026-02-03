# Migrate Remaining ArrayList Usage

## Objective
Update all remaining ArrayList usages in the codebase to use the appropriate types based on Zig 0.15 best practices.

## Prerequisites
- Task 10, 11, 12 must be completed (ReusableBuffer implementation and EnvKey/EnvValue migration)

## Requirements

### 1. Collection ArrayLists (Keep but Update Syntax)
These are actual collections, not reusable buffers. Update to Zig 0.15 syntax:

#### `src/reader.zig`
- `std.ArrayList(EnvPair)` in `readPairs()` - Keep as is or migrate to unmanaged
  - Return type: `!std.ArrayList(EnvPair)`
  - Initialization: `std.ArrayList(EnvPair).init(allocator)`

#### `src/memory.zig`
- `ArrayList(EnvPair)` in `deletePairs()` parameter
- Test code: `ArrayList(EnvPair).init(allocator)`

#### `src/finalizer.zig`
- `*std.ArrayList(EnvPair)` parameters in:
  - `finalizeAllValues()`
  - `finalizeValue()`
  - `findPairByKey()`
- Test code: Multiple `std.ArrayList(EnvPair).init(allocator)` instances

### 2. Decisions for Collections
For each ArrayList of collections, decide:

**Option A: Keep as Managed (current approach)**
```zig
var pairs = std.ArrayList(EnvPair).init(allocator);
```

**Option B: Migrate to Unmanaged**
```zig
var pairs = std.ArrayListUnmanaged(EnvPair){};
// Pass allocator to each operation
try pairs.append(allocator, item);
```

**Recommendation:** 
- Keep managed for now since we frequently pass allocator around anyway
- Unmanaged migration can be a future optimization task
- Focus on removing the buffer-style ArrayList usage (already done in tasks 11-12)

### 3. Update Documentation
- Update comments explaining ArrayList usage
- Document why we use managed vs unmanaged in different contexts

### 4. Testing
For each file modified:
- [ ] All existing tests pass
- [ ] No new memory leaks
- [ ] Build succeeds with Zig 0.15.2

## Files to Review and Possibly Modify
- `src/reader.zig` - Collection of EnvPairs
- `src/memory.zig` - Collection operations
- `src/finalizer.zig` - Collection operations
- `src/env_value.zig` - Collection of VariablePosition
- `temp_zig_test/src/main.zig` - Test file (low priority)

## Success Criteria
- [ ] Code compiles with Zig 0.15.2
- [ ] No deprecation warnings about ArrayList
- [ ] All tests pass
- [ ] Clear documentation on ArrayList usage patterns
- [ ] Memory management is sound

## Notes
- This is more about ensuring compatibility with Zig 0.15 than a major refactor
- The main "reusable buffer" concern was already addressed in tasks 11-12
- Collections of structs (EnvPair, VariablePosition) are legitimate ArrayList use cases
- Consider adding workflow documentation for Zig 0.15 migration patterns

## Future Considerations
- Consider migrating collections to ArrayListUnmanaged for consistency
- Evaluate if some collections could use different data structures (e.g., SegmentedList)
- Create benchmarks to compare managed vs unmanaged performance
