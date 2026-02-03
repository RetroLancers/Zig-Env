# Migrate EnvKey to ReusableBuffer

## Objective
Replace `std.ArrayList(u8)` usage in `EnvKey` with the new `ReusableBuffer` type.

## Prerequisites
- Task 10 (Create Reusable Buffer) must be completed

## Requirements

### 1. Update `src/env_key.zig`
Replace the `buffer` field and update all related code:

**Before:**
```zig
buffer: std.ArrayList(u8),
```

**After:**
```zig
buffer: ReusableBuffer,
```

### 2. Update Methods
Update the following methods to use ReusableBuffer API:
- `init()` - Use `ReusableBuffer.init()`
- `deinit()` - Use `buffer.deinit()`
- `setOwnBuffer()` - Use `ReusableBuffer.fromOwnedSlice()`
- `clipOwnBuffer()` - Use `buffer.resize()`

### 3. Update Related Code
Check and update any code that accesses the buffer:
- Replace `buffer.items` with `buffer.items` (should be compatible)
- Replace `buffer.items.len` with `buffer.len()` or `buffer.items.len`

### 4. Testing
- [x] All existing `env_key.zig` tests pass
- [x] No new memory leaks
- [x] Benchmark if performance is equivalent (optional)

## Files to Modify
- `src/env_key.zig`

## Success Criteria
- [x] EnvKey uses ReusableBuffer instead of ArrayList
- [x] All tests pass
- [x] No memory leaks
- [x] Code is cleaner/more readable

## Notes
- EnvKey is simpler than EnvValue, so this is a good starting point
- Watch for any places where ArrayList-specific APIs were used
