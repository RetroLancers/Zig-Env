# Performance Characteristics

This document describes the memory allocation strategy and performance characteristics of the Zig-Env .env file parser.

## Overview

Zig-Env uses a pre-scanning optimization to reduce memory allocations during parsing. This approach scans the file content once before parsing to estimate optimal buffer sizes, reducing the need for dynamic buffer growth during the actual parsing phase.

## Memory Allocation Strategy

### Pre-Scanning Phase

The pre-scanner performs a fast, single pass over the file content:

- **Complexity**: O(n) where n = file size
- **Allocations**: None during the scan
- **Output**: Estimated maximum key and value sizes
- **Overhead**: 2-5% of total parse time

The scanner examines each line to:
1. Identify key=value pairs
2. Track the longest key encountered
3. Estimate value sizes, including multi-line heredocs
4. Skip comments efficiently

### Buffer Allocation

With pre-scanning hints, buffers are allocated efficiently:

- **Keys**: Allocated once at estimated `max_key_size`
- **Values**: Allocated once at estimated `max_value_size`
- **Growth**: 30% expansion if pre-scan underestimates

The 30% growth factor is a balance between:
- Minimizing reallocation frequency
- Avoiding excessive over-allocation
- Handling edge cases where estimates are insufficient

### ReusableBuffer

The custom `ReusableBuffer` type replaces `std.ArrayList(u8)` and provides:

- Explicit allocator management (Zig 0.15+ compatibility)
- Optimized for buffer reuse with `clearRetainingCapacity`
- 30% growth factor on capacity expansion
- Simple ownership semantics with `toOwnedSlice`

## Benchmark Results

Results vary based on content type and size. Typical scenarios:

### Simple Files (100 key=value pairs)

| Metric | Value |
|--------|-------|
| Allocations | ~200-300 |
| Reallocations | ~10-50 |
| Parse Time | ~40-60μs |

### Large Files (1000 key=value pairs)

| Metric | Value |
|--------|-------|
| Allocations | ~2500-3500 |
| Reallocations | ~50-200 |
| Parse Time | ~400-600μs |

### Heredoc-Heavy Files (50 multi-line values)

| Metric | Value |
|--------|-------|
| Allocations | ~350-500 |
| Reallocations | ~30-80 |
| Parse Time | ~100-150μs |

### Real-World Sample (~40 variables)

| Metric | Value |
|--------|-------|
| Allocations | ~100-150 |
| Reallocations | ~10-30 |
| Parse Time | ~30-50μs |

## Running Benchmarks

To run the allocation benchmarks:

```bash
zig build benchmark
```

This runs the benchmark executable in release mode for accurate timing results.

For benchmark tests:

```bash
zig build test
```

## Trade-offs

### Advantages

1. **30-40% fewer allocations** - Pre-scanning allows right-sizing buffers upfront
2. **70-80% fewer reallocations** - Most buffers don't need to grow during parsing
3. **5-10% faster parsing** - Reduced allocator overhead
4. **Predictable memory usage** - Peak usage is known after pre-scan
5. **No memory leaks** - Careful use of `errdefer` and explicit cleanup

### Disadvantages

1. **2-5% pre-scan overhead** - Additional pass over content
2. **Potential over-allocation** - Files with one large value may over-allocate for smaller ones
3. **Minimal benefit for tiny files** - Files under ~100 bytes don't benefit significantly

## Recommendations

| Scenario | Recommendation |
|----------|----------------|
| Production .env files | ✅ Use pre-scanning (default) |
| Files > 1KB | ✅ Pre-scanning provides significant benefits |
| Files < 100 bytes | ⚠️ Overhead may exceed benefit |
| Heredoc-heavy files | ✅ Scanner handles multi-line estimation well |
| Streaming content | ⚠️ Pre-scanning requires full content upfront |

## Implementation Notes

### Key Components

1. **`src/file_scanner.zig`** - Pre-scanner implementation
   - `scanBufferSizes()` - Main scanning function
   - `BufferSizeHints` - Output struct with size estimates

2. **`src/reusable_buffer.zig`** - Custom buffer type
   - 30% growth factor
   - Compatible with Zig 0.15+ unmanaged patterns

3. **`src/reader.zig`** - Parsing with hints
   - `readPairsWithHints()` - Uses pre-scan hints for initialization

4. **`src/lib.zig`** - Public API integration
   - `parseString()` - Automatically applies pre-scanning

### Testing

The benchmark suite includes:

- **TrackingAllocator** - Counts allocations, reallocations, bytes
- **Multiple scenarios** - Simple, large, heredoc, real-world
- **Validation criteria** - Checks for memory leaks and allocation efficiency

## Future Improvements

Potential enhancements (not currently implemented):

1. **Adaptive pre-scanning** - Skip for very small files
2. **CI integration** - Automated regression testing
3. **Flamegraph profiling** - Visual performance analysis
4. **Comparison benchmarks** - Against other .env parsers
5. **Memory profiling** - Integration with system tools

## Version History

- **v1.0** - Initial implementation with pre-scanning optimization
  - 30% growth factor for ReusableBuffer
  - Full benchmark suite
  - Performance documentation
