# Migrate EnvValue to ReusableBuffer

## Objective
Replace `std.ArrayList(u8)` usage in `EnvValue` with the new `ReusableBuffer` type.

## Prerequisites
- Task 10 (Create Reusable Buffer) must be completed
- Task 11 (Migrate EnvKey) should be completed (for reference)

## Requirements

### 1. Update `src/env_value.zig`
Replace the `buffer` field and update interpolations:

**For buffer:**
```zig
buffer: std.ArrayList(u8),  // OLD
buffer: ReusableBuffer,     // NEW
```

**For interpolations - IMPORTANT:**
Keep as `std.ArrayList(VariablePosition)` for now since:
- It's not used as a reusable buffer
- It's a collection of structs, not bytes
- Migration to unmanaged ArrayList is a separate concern

### 2. Update Methods
Update the following methods to use ReusableBuffer API:
- `init()` - Use `ReusableBuffer.init()`
- `deinit()` - Use `buffer.deinit()` for buffer
- `setOwnBuffer()` - Use `ReusableBuffer.fromOwnedSlice()`
- `clipOwnBuffer()` - Use `buffer.resize()`

### 3. Update `src/buffer_utils.zig`
Update the `addToBuffer()` function:
- Change to work with `ReusableBuffer` instead of ArrayList
- Update the sync logic for `value.value` and `value.value_index`
- Update `isPreviousCharAnEscape()` if needed

### 4. Testing
- [ ] All existing `env_value.zig` tests pass
- [ ] All `buffer_utils.zig` tests pass
- [ ] No new memory leaks
- [ ] Integration tests still work

## Files to Modify
- `src/env_value.zig`
- `src/buffer_utils.zig`

## Success Criteria
- [ ] EnvValue buffer uses ReusableBuffer instead of ArrayList
- [ ] BufferUtils works with ReusableBuffer
- [ ] All tests pass
- [ ] No memory leaks

## Notes
- EnvValue is more complex than EnvKey
- Pay special attention to buffer_utils.zig since it's tightly coupled
- The `interpolations` field should stay as ArrayList for now
