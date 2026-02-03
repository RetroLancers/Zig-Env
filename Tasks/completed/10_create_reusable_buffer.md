# Create Reusable Buffer Implementation

## Objective
Create a custom `ReusableBuffer` type to replace `std.ArrayList(u8)` usage throughout the codebase. This is needed because Zig 0.15 changed ArrayList to be unmanaged by default, and our usage pattern (similar to C++ `std::string` as a buffer) is better served by a custom type.

## Background
- Zig upgraded to 0.15.2
- `std.ArrayList` → `std.array_list.Managed` (will eventually be removed)
- In cppnv, we use `std::string` as a reusable buffer with operations like:
  - Dynamic resizing
  - Index tracking
  - Append operations
  - Owned memory management

## Requirements

### 1. Create `src/reusable_buffer.zig`
Implement a `ReusableBuffer` struct with the following:

**Fields:**
- `allocator: std.mem.Allocator` - The allocator for memory management
- `items: []u8` - The actual buffer contents
- `capacity: usize` - Allocated capacity

**Methods:**
- `init(allocator: std.mem.Allocator) ReusableBuffer` - Initialize empty buffer
- `initCapacity(allocator: std.mem.Allocator, capacity: usize) !ReusableBuffer` - Initialize with capacity
- `deinit(self: *ReusableBuffer) void` - Free memory
- `append(self: *ReusableBuffer, item: u8) !void` - Append a byte
- `appendSlice(self: *ReusableBuffer, items: []const u8) !void` - Append multiple bytes
- `resize(self: *ReusableBuffer, new_len: usize) !void` - Resize buffer
- `fromOwnedSlice(allocator: std.mem.Allocator, slice: []u8) ReusableBuffer` - Take ownership of slice
- `clearRetainingCapacity(self: *ReusableBuffer) void` - Clear content but keep capacity
- `clone(self: *const ReusableBuffer) !ReusableBuffer` - Create a copy

**Properties:**
- `len(self: *const ReusableBuffer) usize` - Return length (inline function)

### 2. Testing
Create comprehensive unit tests covering:
- Basic initialization and deinitialization
- Append operations (single and multiple)
- Resize operations
- Capacity management
- Memory ownership transfer
- Clear and reuse

### 3. Documentation
Add doc comments explaining:
- The purpose of this type (reusable buffer similar to C++ std::string)
- When to use it vs std.ArrayList
- Memory ownership semantics

## Success Criteria
- [x] `src/reusable_buffer.zig` created with all required methods
- [x] All tests pass
- [x] No memory leaks in tests
- [x] Documentation is complete and clear
- [x] Module is exported in `src/root.zig`

## Dependencies
None - this is the foundation for the migration

## Notes
- This buffer should be optimized for reuse (hence `clearRetainingCapacity`)
- Focus on the operations we actually use in EnvKey, EnvValue, etc.
- Consider adding a `toOwnedSlice()` method for transferring ownership out
