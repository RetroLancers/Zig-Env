# Benchmark and Validate Allocation Optimization

## Objective
Create comprehensive benchmarks to measure the effectiveness of the pre-scanning and buffer growth optimizations, and validate that the approach achieves the desired allocation reduction.

## Prerequisites
- Task 10 (ReusableBuffer) must be completed
- Task 15 (File Pre-Scanning) must be completed  
- Task 16 (Integration) must be completed

## Requirements

### 1. Create `benchmarks/allocation_benchmark.zig`

**Benchmark Structure:**
```zig
const std = @import(\"std\");
const zigenv = @import(\"zigenv\");
const Allocator = std.mem.Allocator;

/// Tracking allocator to count allocations
const TrackingAllocator = struct {
    parent: Allocator,
    allocation_count: usize,
    reallocation_count: usize,
    bytes_allocated: usize,
    
    // Implement allocator interface with tracking
};

pub fn benchmarkSimpleFile() !BenchmarkResult {
    // Test: Simple key=value pairs
}

pub fn benchmarkLargeFile() !BenchmarkResult {
    // Test: 1000+ key=value pairs
}

pub fn benchmarkHeredocFile() !BenchmarkResult {
    // Test: Multiple heredocs
}

pub fn benchmarkMixedFile() !BenchmarkResult {
    // Test: Mix of simple, complex, heredocs, comments
}

pub const BenchmarkResult = struct {
    name: []const u8,
    allocations: usize,
    reallocations: usize,
    bytes_allocated: usize,
    parse_time_ns: u64,
};
```

### 2. Test Scenarios

**Scenario 1: Simple File**
```
KEY1=value1
KEY2=value2
KEY3=value3
...
(100 times)
```

**Expected Results:**
- Without optimization: ~300-500 allocations
- With optimization: ~200-300 allocations
- Reduction: ~40-50%

**Scenario 2: Large File**
```
1000 key=value pairs
Mix of short and long keys/values
```

**Expected Results:**
- Allocation reduction scales with file size
- Pre-scan overhead should be <5% of total time

**Scenario 3: Heredoc-Heavy**
```
KEY1="""
multi
line
value
"""
KEY2='''
another
heredoc
'''
...
(50 heredocs)
```

**Expected Results:**
- Scanner may underestimate 10-20% of heredocs
- Growth mechanism should handle efficiently
- Still see 30-40% allocation reduction

**Scenario 4: Real-World Sample**
```
# Comments
EMPTY_VALUE=
SIMPLE=value
QUOTED="quoted value"
HEREDOC="""
multi
line
"""
INTERPOLATED=${SIMPLE}_extended
```

**Expected Results:**
- Best representation of actual usage
- Should see ~60-70% allocation reduction
- Parse time improvement of 5-10%

### 3. Create Comparison Report

**Output Format:**
```
=== Allocation Benchmark Results ===

Simple File (100 entries):
  Allocations: 412 -> 245 (-40.5%)
  Reallocations: 187 -> 34 (-81.8%)
  Bytes: 5,234 -> 5,180 (-1.0%)
  Time: 42.3μs -> 40.1μs (-5.2%)

Large File (1000 entries):
  Allocations: 4,523 -> 2,891 (-36.1%)
  Reallocations: 2,045 -> 312 (-84.7%)
  Bytes: 52,340 -> 51,800 (-1.0%)
  Time: 523.4μs -> 487.2μs (-6.9%)

Heredoc-Heavy (50 entries):
  Allocations: 623 -> 412 (-33.9%)
  Reallocations: 234 -> 67 (-71.4%)
  Bytes: 15,678 -> 15,234 (-2.8%)
  Time: 134.5μs -> 129.1μs (-4.0%)

Real-World Sample:
  Allocations: 89 -> 52 (-41.6%)
  Reallocations: 45 -> 8 (-82.2%)
  Bytes: 1,234 -> 1,198 (-2.9%)
  Time: 18.7μs -> 17.3μs (-7.5%)

=== Summary ===
Average allocation reduction: 38.0%
Average reallocation reduction: 80.1%
Average time improvement: 5.9%

✓ Optimization targets met
```

### 4. Validation Criteria

**Must Meet:**
- [ ] Allocation reduction ≥ 30% (average)
- [ ] Reallocation reduction ≥ 70% (average)
- [ ] No memory leaks
- [ ] All functional tests still pass
- [ ] Parse time not regressed (ideally improved)

**Nice to Have:**
- [ ] Allocation reduction ≥ 40%
- [ ] Time improvement 5-10%
- [ ] Memory usage not increased >5%

### 5. Update build.zig

Add benchmark executable:
```zig
const benchmark_exe = b.addExecutable(.{
    .name = "allocation_benchmark",
    .root_source_file = .{ .path = "benchmarks/allocation_benchmark.zig" },
    .target = target,
    .optimize = optimize,
});

const benchmark_cmd = b.addRunArtifact(benchmark_exe);
const benchmark_step = b.step("benchmark", "Run allocation benchmarks");
benchmark_step.dependOn(&benchmark_cmd.step);
```

**Usage:**
```bash
zig build benchmark
```

### 6. Documentation

**Create `docs/Performance.md`:**
```markdown
# Performance Characteristics

## Memory Allocation Strategy

### Pre-Scanning Phase
- Single pass: O(n) where n = file size
- No allocations during scan
- Overhead: 2-5% of total parse time

### Buffer Allocation
- Keys: Allocated once at max_key_size
- Values: Allocated once at max_value_size
- Growth: 30% expansion if pre-scan underestimates

### Benchmark Results
[Include summary table from benchmarks]

## Trade-offs

### Pros
- 30-40% fewer allocations
- 70-80% fewer reallocations
- 5-10% faster parsing
- Predictable memory usage

### Cons
- 2-5% overhead from pre-scanning
- May over-allocate for files with few large values
- Not beneficial for very small files (<100 bytes)

## Recommendations

- ✅ Use for production .env parsing
- ✅ Ideal for files >1KB
- ⚠️ Consider skipping pre-scan for <100 byte files
- ✅ Growth mechanism handles edge cases well
```

## Success Criteria
- [ ] Benchmark suite created and runs successfully
- [ ] All scenarios tested
- [ ] Results meet validation criteria
- [ ] Performance documentation created
- [ ] No regressions detected
- [ ] Results show meaningful improvement

## Deliverables
1. `benchmarks/allocation_benchmark.zig` - Full benchmark suite
2. `docs/Performance.md` - Performance documentation
3. Benchmark results output
4. Comparison against C++ implementation (optional but nice)
5. Updated README with performance notes

## Notes
- Run benchmarks in release mode (`-O ReleaseFast`)
- Use large enough sample sizes for statistical significance
- Consider running on different hardware/OS for validation
- Compare against C++ cppnv performance if possible
- Document any surprising results or edge cases discovered

## Future Improvements (Out of Scope)
- Automated regression testing in CI
- Flamegraph profiling
- Memory profiling with valgrind/similar
- Comparison with other .env parsers
