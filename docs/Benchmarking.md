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
# Run all benchmarks
zig build bench

# Run micro-benchmarks
zig build bench:micro
```

### Interpreting Results

#### Micro Benchmarks
Measures raw execution time of individual components (Key Parsing, Value Parsing).

- **Total Time**: Sum of all iterations.
- **Avg Time**: Average time per iteration (lower is better).
- **P99**: 99th percentile latency (tail latency).

## Benchmark Categories

1. **Micro Benchmarks**: `benchmarks/micro_benchmarks.zig`
   - Key Parsing
   - Value Parsing
   
2. **Throughput**: (Coming soon)
3. **Latency**: (Coming soon)

## Adding New Benchmarks

Create a new file in `benchmarks/` and register it in `build.zig`.
Use `framework.benchmark` or `framework.benchmarkWithSetup`.
