# Task: Optimize ReusableBuffer and Remove Redundancy in Data Structures

## Problem Statement
The current implementation of `ReusableBuffer` and its usage in `EnvKey` and `EnvValue` has several inefficiencies and redundancies:
1. `EnvKey` and `EnvValue` both maintain a redundant `key_index` / `value_index` that mirrors `buffer.items.len`.
2. They also maintain a `key` / `value` slice that must be manually synchronized with the underlying buffer.
3. `ReusableBuffer`'s `toOwnedSlice` method is destructive, making it difficult to "take" a value while keeping the buffer's allocation for the next pair.
4. The pattern of usage in `readPairsWithHints` allocates a new `EnvPair` for every line, rather than reusing a single "scratch" pair and only allocating permanent storage for finalized values.

## Objectives
- [ ] Refactor `ReusableBuffer` to explicitly manage an `index` (length) and a stable `capacity`.
- [ ] Ensure `clearRetainingCapacity()` only resets the `index` to 0 without freeing memory.
- [ ] Remove redundant `key_index` and `value_index` from `EnvKey` and `EnvValue`.
- [ ] Remove redundant or manually-synced `key` and `value` slices from `EnvKey` and `EnvValue`.
- [ ] Update all parsing logic to use the `ReusableBuffer` API directly for length tracking.
- [ ] Optimize `readPairs` to use a scratch `EnvPair` to minimize allocations during parsing.

## Proposed Changes

### 1. Refactor `ReusableBuffer` (src/buffer/reusable_buffer.zig)
Change the structure to be more explicit about the "index" and "capacity":
```zig
pub const ReusableBuffer = struct {
    allocator: std.mem.Allocator,
    ptr: [*]u8,
    len: usize,       // The "index" where items are added
    capacity: usize,  // Total allocated size

    pub fn usedSlice(self: *const ReusableBuffer) []u8 {
        return self.ptr[0..self.len];
    }
    
    pub fn clear(self: *ReusableBuffer) void {
        self.len = 0;
    }
    
    // ... update append to use self.len and check self.capacity
};
```

### 2. Update `EnvKey` and `EnvValue` (src/data/env_key.zig, src/data/env_value.zig)
Remove the redundant fields:
```zig
pub const EnvKey = struct {
    buffer: ReusableBuffer,
    // REMOVED: key: []const u8,
    // REMOVED: key_index: usize,
    
    pub fn key(self: *const EnvKey) []const u8 {
        return self.buffer.usedSlice();
    }
};
```

### 3. Update Buffer Utilities (src/buffer/buffer_utils.zig)
Simplify `addToBuffer` to remove manual sync:
```zig
pub fn addToBuffer(value: *EnvValue, char: u8) !void {
    try value.buffer.append(char);
}
```

### 4. Update Parser (src/parser/read_key.zig, read_value.zig, read_pair.zig)
Update all logic that modifies or reads the length to use `buffer.len()` or equivalent.

## Success Criteria
- [ ] All tests pass.
- [ ] No manual synchronization of `index` or `slice` fields is required in `EnvKey` / `EnvValue`.
- [ ] `ReusableBuffer` usage in a loop (clear -> append -> usedSlice) does not trigger reallocations if the capacity is sufficient.
