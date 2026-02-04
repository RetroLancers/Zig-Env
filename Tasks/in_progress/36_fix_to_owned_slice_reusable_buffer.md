# Task: 36_fix_to_owned_slice_reusable_buffer.md

## Objective
Change the fallback logic in toOwnedSlice in ReusableBuffer to avoid potential double-free or leaks by using allocator.dupe and explicit free instead of relying on realloc failure semantics.

## Checklist
- [ ] Implement changes
- [ ] Verify fix/change

