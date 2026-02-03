# Advanced Benchmarking Suite

## Objective
Create a comprehensive benchmarking framework to measure parser performance across multiple dimensions: throughput, latency, memory usage, allocation patterns, and comparison with other parsers.

## Prerequisites
- Task 17 (Basic allocation benchmarks) completed
- Task 21 (Extensive test suite) completed
- All core features implemented

## Requirements

### 1. Micro-Benchmarks

**Create `benchmarks/micro_benchmarks.zig`:**

Measure individual operation performance.

```zig
const std = @import("std");
const zigenv = @import("zigenv");

pub const MicroBenchmark = struct {
    name: []const u8,
    iterations: usize,
    total_time_ns: u64,
    min_time_ns: u64,
    max_time_ns: u64,
    avg_time_ns: u64,
    median_time_ns: u64,
    p95_time_ns: u64,
    p99_time_ns: u64,
};

// Individual micro-benchmarks
pub fn benchmarkKeyParsing() !MicroBenchmark {
    // Measure just key extraction
    // KEY=value -> extract "KEY"
    // Run 1,000,000 iterations
}

pub fn benchmarkValueParsing() !MicroBenchmark {
    // Measure just value extraction
    // KEY=value -> extract "value"
}

pub fn benchmarkQuoteProcessing() !MicroBenchmark {
    // Measure quote parsing
    // "quoted value" -> quoted value
}

pub fn benchmarkEscapeProcessing() !MicroBenchmark {
    // Measure escape sequence processing
    // \n\t\r\" -> actual escape chars
}

pub fn benchmarkInterpolationResolution() !MicroBenchmark {
    // Measure variable interpolation
    // ${VAR} -> resolved value
}

pub fn benchmarkCommentSkipping() !MicroBenchmark {
    // Measure comment processing speed
}

pub fn benchmarkLineEndingNormalization() !MicroBenchmark {
    // Measure \r\n -> \n conversion
}

pub fn benchmarkBufferGrowth() !MicroBenchmark {
    // Measure buffer reallocation overhead
}

pub fn benchmarkHashMapLookup() !MicroBenchmark {
    // Measure environment variable lookup speed
}

pub fn benchmarkHeredocParsing() !MicroBenchmark {
    // Measure multi-line heredoc processing
}
```

### 2. Throughput Benchmarks

**Create `benchmarks/throughput_benchmarks.zig`:**

Measure parsing throughput (bytes/sec, entries/sec).

```zig
pub const ThroughputBenchmark = struct {
    name: []const u8,
    bytes_processed: usize,
    entries_parsed: usize,
    elapsed_ns: u64,
    bytes_per_second: f64,
    entries_per_second: f64,
    mbps: f64, // Megabytes per second
};

pub fn benchmarkSmallFileThroughput() !ThroughputBenchmark {
    // 100 entries, ~1KB
    // Measure how many files/sec can be parsed
}

pub fn benchmarkMediumFileThroughput() !ThroughputBenchmark {
    // 1,000 entries, ~10KB
}

pub fn benchmarkLargeFileThroughput() !ThroughputBenchmark {
    // 10,000 entries, ~100KB
}

pub fn benchmarkHugeFileThroughput() !ThroughputBenchmark {
    // 100,000 entries, ~1MB
}

pub fn benchmarkStreamingParse() !ThroughputBenchmark {
    // Measure streaming input (simulated network)
    // Parse as data arrives, not all at once
}

pub fn benchmarkBatchParsing() !ThroughputBenchmark {
    // Parse 1000 small files in sequence
    // Measure aggregate throughput
}
```

### 3. Latency Benchmarks

**Create `benchmarks/latency_benchmarks.zig`:**

Measure parser latency (time to first result, p50/p95/p99).

```zig
pub const LatencyBenchmark = struct {
    name: []const u8,
    samples: usize,
    min_ns: u64,
    max_ns: u64,
    mean_ns: u64,
    median_ns: u64,
    p50_ns: u64,
    p95_ns: u64,
    p99_ns: u64,
    p999_ns: u64,
    stddev_ns: f64,
};

pub fn benchmarkColdStartLatency() !LatencyBenchmark {
    // First parse after program start
    // Measure cold cache impact
}

pub fn benchmarkWarmCacheLatency() !LatencyBenchmark {
    // Repeated parses of same file
    // Measure warm cache performance
}

pub fn benchmarkTimeToFirstPair() !LatencyBenchmark {
    // How quickly can we extract the first key-value?
    // Important for streaming scenarios
}

pub fn benchmarkInteractiveLatency() !LatencyBenchmark {
    // Simulate user waiting for parse
    // Target: <10ms for small files
}

pub fn benchmarkWorstCaseLatency() !LatencyBenchmark {
    // Find worst-case input patterns
    // Complex interpolations, deep nesting, etc.
}
```

### 4. Memory Benchmarks

**Create `benchmarks/memory_benchmarks.zig`:**

Measure memory usage patterns in detail.

```zig
pub const MemoryBenchmark = struct {
    name: []const u8,
    allocations: usize,
    deallocations: usize,
    reallocations: usize,
    peak_bytes: usize,
    total_bytes_allocated: usize,
    bytes_wasted: usize, // Over-allocation
    fragmentation_score: f64,
};

pub fn benchmarkAllocationPatterns() !MemoryBenchmark {
    // Track allocation sizes and patterns
}

pub fn benchmarkMemoryFootprint() !MemoryBenchmark {
    // Measure resident set size (RSS)
}

pub fn benchmarkCacheEfficiency() !MemoryBenchmark {
    // Cache hit/miss rates (if measurable)
}

pub fn benchmarkMemoryLocality() !MemoryBenchmark {
    // Measure data structure locality
}

pub fn benchmarkPeakUsageScaling() !MemoryBenchmark {
    // How does peak memory scale with file size?
}

pub fn benchmarkPreScanningOverhead() !MemoryBenchmark {
    // Extra memory used by pre-scanning
}

pub fn benchmarkBufferReuseEfficiency() !MemoryBenchmark {
    // How effectively are buffers reused?
}
```

### 5. Scalability Benchmarks

**Create `benchmarks/scalability_benchmarks.zig`:**

Test performance scaling with input size.

```zig
pub const ScalabilityBenchmark = struct {
    file_sizes: []usize, // Bytes
    parse_times: []u64,  // Nanoseconds
    memory_used: []usize,
    complexity: []const u8, // "O(n)", "O(n log n)", etc.
};

pub fn benchmarkLinearScaling() !ScalabilityBenchmark {
    // Test files: 1KB, 10KB, 100KB, 1MB, 10MB
    // Verify O(n) scaling
}

pub fn benchmarkKeyCountScaling() !ScalabilityBenchmark {
    // Test: 10, 100, 1K, 10K, 100K keys
    // Measure how parse time scales
}

pub fn benchmarkValueSizeScaling() !ScalabilityBenchmark {
    // Test various value sizes: 10B to 1MB
    // Measure impact on performance
}

pub fn benchmarkInterpolationScaling() !ScalabilityBenchmark {
    // Test: 1, 10, 100, 1000 interpolations
    // Measure resolution overhead
}

pub fn benchmarkNestingDepthScaling() !ScalabilityBenchmark {
    // Test: ${A}, ${${B}}, ${${${C}}}, etc.
    // Measure impact of nesting
}
```

### 6. Comparative Benchmarks

**Create `benchmarks/comparative_benchmarks.zig`:**

Compare against other parsers.

```zig
pub const ComparativeBenchmark = struct {
    parser_name: []const u8,
    parse_time_ns: u64,
    memory_bytes: usize,
    allocations: usize,
    relative_speed: f64, // vs baseline
};

// Note: These require implementing bindings or subprocess calls

pub fn benchmarkVsCppnv() !ComparativeBenchmark {
    // Compare against original C++ implementation
    // Call via subprocess or C bindings
}

pub fn benchmarkVsGoGodotenv() !ComparativeBenchmark {
    // Compare against Go godotenv
    // Call via subprocess
}

pub fn benchmarkVsRustDotenvy() !ComparativeBenchmark {
    // Compare against Rust dotenvy
}

pub fn benchmarkVsNodeDotenv() !ComparativeBenchmark {
    // Compare against Node.js dotenv (via Node)
}

pub fn benchmarkVsPythonDotenv() !ComparativeBenchmark {
    // Compare against python-dotenv
}

// Create standardized test suite for fair comparison
pub fn createStandardizedTestSuite() !void {
    // Generate identical .env files for all parsers
    // - simple.env
    // - medium.env
    // - complex.env
    // - large.env
}
```

### 7. Concurrent/Parallel Benchmarks

**Create `benchmarks/parallel_benchmarks.zig`:**

Test multi-threaded scenarios (if applicable).

```zig
pub const ParallelBenchmark = struct {
    name: []const u8,
    thread_count: usize,
    total_parses: usize,
    elapsed_ns: u64,
    parses_per_second: f64,
    speedup_factor: f64, // vs single-threaded
};

pub fn benchmarkConcurrentParsing() !ParallelBenchmark {
    // Parse different files concurrently
    // Threads: 1, 2, 4, 8, 16
}

pub fn benchmarkParallelLookup() !ParallelBenchmark {
    // Multiple threads reading same Env
    // Measure contention
}

pub fn benchmarkThreadSafety() !ParallelBenchmark {
    // Stress test thread safety
    // Concurrent reads/writes
}
```

### 8. Real-World Scenario Benchmarks

**Create `benchmarks/scenario_benchmarks.zig`:**

Simulate actual use cases.

```zig
pub const ScenarioBenchmark = struct {
    scenario: []const u8,
    operations: usize,
    total_time_ns: u64,
    avg_operation_time_ns: u64,
};

pub fn benchmarkWebServerStartup() !ScenarioBenchmark {
    // Simulate web server loading config on startup
    // Parse .env + validate + apply
}

pub fn benchmarkCLIToolStartup() !ScenarioBenchmark {
    // Simulate CLI tool startup
    // Parse quickly, minimize latency
}

pub fn benchmarkContainerStart() !ScenarioBenchmark {
    // Simulate Docker container startup
    // Parse multiple .env files
}

pub fn benchmarkHotReload() !ScenarioBenchmark {
    // Simulate file watcher reloading config
    // Parse .env on file change
}

pub fn benchmarkConfigMerge() !ScenarioBenchmark {
    // Parse multiple files and merge
    // .env, .env.local, .env. production, etc.
}

pub fn benchmarkLargeMonorepo() !ScenarioBenchmark {
    // Simulate monorepo with many .env files
    // Parse dozens of files
}
```

### 9. Optimization Validation Benchmarks

**Create `benchmarks/optimization_benchmarks.zig`:**

Validate specific optimizations.

```zig
pub fn benchmarkWithVsWithoutPreScanning() !ComparisonResult {
    // Measure impact of pre-scanning optimization
}

pub fn benchmarkBufferGrowthStrategies() !ComparisonResult {
    // Compare: 30%, 50%, 100% growth
}

pub fn benchmarkHashMapSizes() !ComparisonResult {
    // Compare different initial capacities
}

pub fn benchmarkStringInternOptimization() !ComparisonResult {
    // If applicable: string interning for keys
}

pub fn benchmarkArenaVsGeneralAllocator() !ComparisonResult {
    // Compare allocator strategies
}
```

### 10. Regression Benchmarks

**Create `benchmarks/regression_benchmarks.zig`:**

Track performance over time.

```zig
pub const RegressionReport = struct {
    benchmark_date: []const u8,
    commit_hash: []const u8,
    results: []BenchmarkResult,
    
    pub fn compare(old: RegressionReport, new: RegressionReport) !void {
        // Compare and flag regressions
        // Alert if > 10% slower
    }
};

pub fn runFullRegressionSuite() !RegressionReport {
    // Run all benchmarks
    // Save results with timestamp and commit
}

pub fn loadHistoricalResults() ![]RegressionReport {
    // Load previous benchmark results
    // From benchmarks/results/
}

pub fn generateRegressionReport() !void {
    // Create HTML/markdown report
    // With graphs and trends
}
```

## Benchmark Infrastructure

### 11. Benchmark Framework

**Create `benchmarks/framework.zig`:**

Reusable benchmark infrastructure.

```zig
pub const BenchmarkConfig = struct {
    warmup_iterations: usize = 100,
    measurement_iterations: usize = 1000,
    min_measurement_time_ms: u64 = 1000,
    max_measurement_time_ms: u64 = 10000,
};

pub fn benchmark(
    comptime name: []const u8,
    comptime func: anytype,
    config: BenchmarkConfig,
) !BenchmarkResult {
    // Generic benchmark runner
    // - Warmup phase
    // - Measurement phase
    // - Statistical analysis
    // - Outlier detection
}

pub fn printResults(results: []BenchmarkResult) !void {
    // Pretty-print benchmark results
    // Table format with colors
}

pub fn exportToJson(results: []BenchmarkResult, path: []const u8) !void {
    // Export for analysis tools
}

pub fn exportToCsv(results: []BenchmarkResult, path: []const u8) !void {
    // Export for spreadsheets
}

pub fn generateHtmlReport(results: []BenchmarkResult, path: []const u8) !void {
    // Generate interactive HTML report
    // With charts (via Chart.js or similar)
}
```

### 12. Statistical Analysis

**Create `benchmarks/statistics.zig`:**

```zig
pub fn calculatePercentile(samples: []u64, percentile: f64) u64 {
    // Calculate p50, p95, p99, etc.
}

pub fn calculateMean(samples: []u64) f64 {
    // Calculate average
}

pub fn calculateStdDev(samples: []u64, mean: f64) f64 {
    // Calculate standard deviation
}

pub fn detectOutliers(samples: []u64) []usize {
    // Identify outlier indices
    // Using IQR or z-score method
}

pub fn calculateConfidenceInterval(samples: []u64, confidence: f64) struct { lower: f64, upper: f64 } {
    // 95% confidence interval
}
```

## Benchmark Organization

```
benchmarks/
├── framework.zig                      # Core benchmark infrastructure
├── statistics.zig                     # Statistical utilities
├── allocation_benchmark.zig           # Existing (Task 17)
├── micro_benchmarks.zig               # NEW - Individual operations
├── throughput_benchmarks.zig          # NEW - Bytes/sec, entries/sec
├── latency_benchmarks.zig             # NEW - p50/p95/p99 latency
├── memory_benchmarks.zig              # NEW - Detailed memory analysis
├── scalability_benchmarks.zig         # NEW - Scaling with input size
├── comparative_benchmarks.zig         # NEW - vs other parsers
├── parallel_benchmarks.zig            # NEW - Multi-threaded scenarios
├── scenario_benchmarks.zig            # NEW - Real-world use cases
├── optimization_benchmarks.zig        # NEW - Validate optimizations
├── regression_benchmarks.zig          # NEW - Track over time
├── fixtures/                          # Benchmark test files
│   ├── small.env
│   ├── medium.env
│   ├── large.env
│   ├── huge.env
│   └── ... (various scenarios)
├── results/                           # Historical results
│   ├── 2026-02-03_abc123.json
│   ├── 2026-02-10_def456.json
│   └── ...
└── reports/                           # Generated reports
    ├── latest.html
    ├── trends.html
    └── comparison.html
```

## Success Criteria

- [ ] All 12 benchmark categories implemented
- [ ] Benchmark framework with warmup, outlier detection, statistics
- [ ] At least 50+ individual benchmarks across categories
- [ ] Comparison with at least 2 other parsers (C++ and one other)
- [ ] Regression tracking infrastructure
- [ ] HTML report generation with charts
- [ ] CSV/JSON export for external analysis
- [ ] Documentation of all benchmarks
- [ ] CI/CD integration (run on every PR/commit)
- [ ] Performance regression alerts (>10% slower)

## Build Configuration

**Update `build.zig`:**

```zig
// Benchmark executables
const micro_bench = b.addExecutable(.{
    .name = "micro_benchmarks",
    .root_source_file = .{ .path = "benchmarks/micro_benchmarks.zig" },
    .target = target,
    .optimize = .ReleaseFast, // Important!
});

// ... (similar for all benchmark files)

// Benchmark step
const bench_step = b.step("bench", "Run all benchmarks");

// Individual benchmark steps
const micro_bench_step = b.step("bench:micro", "Run micro-benchmarks");
const throughput_bench_step = b.step("bench:throughput", "Run throughput benchmarks");
// ... etc

// Full benchmark suite
const full_bench_step = b.step("bench:full", "Run full benchmark suite with report");
```

## Usage

```bash
# Run all benchmarks
zig build bench

# Run specific category
zig build bench:micro
zig build bench:throughput
zig build bench:latency

# Run with report generation
zig build bench:full

# Compare with baseline
zig build bench:regression

# Quick smoke test
zig build bench:quick
```

## Documentation

**Create `docs/Benchmarking.md`:**

```markdown
# Benchmarking Guide

## Overview
Comprehensive benchmark suite covering:
- Micro-benchmarks (individual operations)
- Throughput benchmarks (bytes/sec, entries/sec)
- Latency benchmarks (p50/p95/p99)
- Memory benchmarks (allocations, peak usage)
- Scalability benchmarks (O(n) verification)
- Comparative benchmarks (vs other parsers)
- Real-world scenarios
- Regression tracking

## Running Benchmarks

### Quick Start
```bash
zig build bench
```

### Detailed Analysis
```bash
# Full suite with HTML report
zig build bench:full

# Open report
open benchmarks/reports/latest.html
```

### Interpreting Results

#### Throughput
- **Good**: >100MB/s for simple files
- **Acceptable**: >10MB/s for complex files
- **Needs improvement**: <1MB/s

#### Latency
- **Good**: p99 < 1ms for small files
- **Acceptable**: p99 < 10ms for medium files
- **Needs improvement**: p99 > 100ms

#### Memory
- **Good**: <2x file size peak memory
- **Acceptable**: <5x file size
- **Needs improvement**: >10x file size

### Regression Alerts
Automatic alerts if:
- Parse time increases >10%
- Memory usage increases >15%
- Allocation count increases >20%

## Benchmark Categories

[Detailed description of each category]

## Adding New Benchmarks

[Guidelines for contributors]
```

**Create `docs/Performance_Comparison.md`:**

Comparison with other parsers.

```markdown
# Performance Comparison

## Benchmark Environment
- CPU: [spec]
- RAM: [spec]
- OS: [spec]
- Zig version: 0.15.2
- Optimization: ReleaseFast

## Results Summary

| Parser | Language | Parse Time | Memory | Notes |
|--------|----------|-----------|--------|-------|
| Zig-Env | Zig | 100μs | 1.2MB | This implementation |
| cppnv | C++ | 95μs | 1.1MB | Original |
| godotenv | Go | 150μs | 2.5MB | |
| dotenvy | Rust | 80μs | 0.9MB | |
| dotenv | Node.js | 500μs | 5.0MB | |
| python-dotenv | Python | 800μs | 8.0MB | |

## Detailed Analysis
[Breakdown by file size, complexity, etc.]
```

## Clood Groups to Create/Update

- `benchmarking.json` (new)
- `performance-analysis.json` (new)
- `statistics.json` (new)

## Files to Create/Modify

| File | Purpose |
|------|---------|
| `benchmarks/framework.zig` | Core benchmark infrastructure |
| `benchmarks/statistics.zig` | Statistical analysis utilities |
| `benchmarks/micro_benchmarks.zig` | Individual operation benchmarks |
| `benchmarks/throughput_benchmarks.zig` | Throughput measurements |
| `benchmarks/latency_benchmarks.zig` | Latency measurements |
| `benchmarks/memory_benchmarks.zig` | Memory analysis |
| `benchmarks/scalability_benchmarks.zig` | Scaling analysis |
| `benchmarks/comparative_benchmarks.zig` | Cross-parser comparison |
| `benchmarks/parallel_benchmarks.zig` | Multi-threaded tests |
| `benchmarks/scenario_benchmarks.zig` | Real-world scenarios |
| `benchmarks/optimization_benchmarks.zig` | Optimization validation |
| `benchmarks/regression_benchmarks.zig` | Regression tracking |
| `benchmarks/fixtures/*.env` | Benchmark test data |
| `docs/Benchmarking.md` | Benchmarking documentation |
| `docs/Performance_Comparison.md` | Cross-parser comparison |
| `build.zig` | Build configuration updates |

## Deliverables

1. **12 benchmark categories** fully implemented
2. **50+ individual benchmarks** with statistical analysis
3. **Benchmark framework** with warmup, outlier detection, reporting
4. **Comparison with 3+ other parsers**
5. **HTML report generation** with interactive charts
6. **Regression tracking** infrastructure
7. **Comprehensive documentation** in `docs/`
8. **CI/CD integration** for automated benchmarking
9. **Performance baseline** established
10. **Alert system** for performance regressions

## Notes

- **Always use ReleaseFast**: Benchmarks must be optimized
- **Warm up**: Run warmup iterations before measurement
- **Statistical rigor**: Use percentiles, detect outliers
- **Reproducibility**: Document environment, use fixed seeds
- **Fair comparison**: Use identical test data for all parsers
- **Automate**: Integrate into CI/CD pipeline
- **Track over time**: Store historical results
- **Visualize**: Generate charts and graphs
- **Context**: Include system specs in reports

## Cross-Parser Setup (Optional but Recommended)

To compare with other parsers:

1. **C++ (cppnv)**: Build original implementation, call via subprocess or C bindings
2. **Go (godotenv)**: Create small Go program, call via subprocess
3. **Rust (dotenvy)**: Create small Rust program, call via subprocess
4. **Node.js (dotenv)**: Create JS script, call via node subprocess
5. **Python (python-dotenv)**: Create Python script, call via subprocess

**Create standardized test harness:**
```bash
# benchmarks/cross_parser/
├── test_files/          # Identical .env files for all
├── cppnv_bench.cpp      # C++ benchmark
├── godotenv_bench.go    # Go benchmark
├── dotenvy_bench.rs     # Rust benchmark
├── dotenv_bench.js      # Node.js benchmark
├── dotenv_bench.py      # Python benchmark
└── run_all.zig          # Run all and compare
```

## Future Enhancements (Out of Scope)

- Continuous benchmarking service (like benchmarksgame)
- Flamegraph profiling integration
- CPU cache analysis (cachegrind)
- Branch prediction analysis
- SIMD optimization exploration - Memory allocator comparison (different allocators)
- JIT compilation exploration (if applicable)
- WebAssembly performance testing
