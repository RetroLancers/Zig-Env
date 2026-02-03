# Zig 0.15 Migration Plan

## Overview
This document outlines the migration strategy for upgrading to Zig 0.15.2, which changed ArrayList to be unmanaged by default.

## Zig Version
- **Current**: Zig 0.15.2
- **Path**: `C:\ProgramData\chocolatey\lib\zig\tools\zig-x86_64-windows-0.15.2\zig.exe`

## Key Changes in Zig 0.15
- `std.ArrayList` → `std.array_list.Managed` (will eventually be removed)
- `std.ArrayListAligned` → `std.array_list.AlignedManaged`
- Unmanaged is now the default/recommended approach

## Our Usage Pattern
In the C++ codebase (`cppnv`), we use `std::string` as a reusable buffer with:
- Dynamic resizing
- Index tracking
- Append operations
- Owned memory management

In Zig, we've been using `std.ArrayList(u8)` for this same pattern in `EnvKey` and `EnvValue`.

## Migration Strategy

### Phase 1: Create Custom Buffer Type (Task 10)
Create `ReusableBuffer` - a custom type optimized for our buffer usage pattern.

**Rationale:**
- Better semantic meaning than ArrayList
- Optimized for reuse (clearRetainingCapacity)
- Simpler API for our specific use case
- Avoids the managed/unmanaged debate for buffers

### Phase 2: Migrate Buffer Fields (Tasks 11-12)
Replace ArrayList in structures that use it as a reusable buffer:
1. **Task 11**: EnvKey (simpler, good starting point)
2. **Task 12**: EnvValue (more complex, includes buffer_utils)

### Phase 3: Handle Collection ArrayLists (Task 13)
Review and update ArrayLists used for collections:
- `std.ArrayList(EnvPair)` in reader, memory, finalizer
- `std.ArrayList(VariablePosition)` in EnvValue

**Decision**: Keep as managed ArrayList for now since these are legitimate collections, not reusable buffers.

### Phase 4: Verification (Task 14)
Comprehensive testing and validation of the migration.

## Task Breakdown

| Task | Priority | Estimated Effort | Dependencies |
|------|----------|-----------------|--------------|
| 10 - Create ReusableBuffer | High | 2-3 hours | None |
| 11 - Migrate EnvKey | High | 1-2 hours | Task 10 |
| 12 - Migrate EnvValue | High | 2-3 hours | Task 10, 11 |
| 13 - Remaining ArrayLists | Medium | 1-2 hours | Task 10-12 |
| 14 - Verification | High | 1-2 hours | All above |

**Total Estimated Effort**: 7-12 hours

## Benefits

### Code Quality
- ✅ Better semantic clarity (ReusableBuffer vs ArrayList)
- ✅ Type safety maintained
- ✅ Cleaner API for our use case

### Performance
- ✅ No performance regression expected
- ✅ Better memory reuse with clearRetainingCapacity
- ✅ Potential for future optimizations

### Maintainability
- ✅ Easier to understand buffer usage pattern
- ✅ Matches the C++ pattern more closely
- ✅ Future-proof for Zig evolution

## Testing Strategy
Each task includes its own tests, plus:
1. Unit tests for each modified component
2. Integration tests for the full parser
3. Memory leak detection
4. Performance verification

## Rollback Plan
If issues arise:
1. Each task is on its own feature branch
2. Can revert individual tasks if needed
3. Keep old code commented during initial migration

## Success Criteria
- ✅ All tests pass
- ✅ No memory leaks
- ✅ No deprecation warnings
- ✅ Code compiles with Zig 0.15.2
- ✅ Performance maintained or improved
- ✅ Documentation updated

## Timeline
- **Phase 1**: 1 work session
- **Phase 2**: 1-2 work sessions  
- **Phase 3**: 1 work session
- **Phase 4**: 1 work session

**Total**: 4-5 work sessions

## Notes
- Start with Task 10 (ReusableBuffer foundation)
- Tasks 11-12 can be done sequentially (11 provides pattern for 12)
- Task 13 is more about verification than refactoring
- Task 14 is critical - don't skip it

## References
- Zig 0.15 Release Notes
- ArrayList → Unmanaged discussion: Zig GitHub
- C++ cppnv implementation: `cppnv/cppnv/node_dotenv.h`
