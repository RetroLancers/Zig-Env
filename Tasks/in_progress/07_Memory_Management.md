# Task 07: Memory Management

## Objective
Implement proper memory cleanup functions and ensure the library is leak-free.

## Functions to Implement

### 1. delete_pair (`src/memory.zig`)
- **C++ Reference**: `EnvReader::delete_pair` (lines 324-328)
- **Purpose**: Clean up all memory for a single EnvPair
- **Signature**: `fn deletePair(allocator: Allocator, pair: *EnvPair) void`

### 2. delete_pairs (`src/memory.zig`)
- **C++ Reference**: `EnvReader::delete_pairs` (lines 330-334)
- **Purpose**: Clean up all pairs in the list
- **Signature**: `fn deletePairs(allocator: Allocator, pairs: *ArrayList(EnvPair)) void`

### 3. Struct deinit methods
Add proper `deinit` to: EnvStream, VariablePosition, EnvKey, EnvValue, EnvPair

## Memory Ownership Rules

1. **EnvStream**: Does NOT own data (just a view)
2. **EnvKey**: Owns `own_buffer` if set
3. **EnvValue**: Owns `own_buffer` and all `interpolations`
4. **VariablePosition**: Owns `variable_str` slice
5. **EnvPair**: Owns embedded EnvKey and EnvValue

## Testing Strategy

Use `std.testing.allocator` for automatic leak detection in tests.

## Checklist

- [x] Create `src/memory.zig`
- [x] Implement `deletePair` and `deletePairs`
- [x] Add `deinit` to all structs
- [x] Add proper `errdefer` in allocation paths
- [x] Create memory leak tests
- [x] Update `src/root.zig`

## Dependencies
- Task 01 (Core Data Structures)
- All previous tasks (audit allocation patterns)
