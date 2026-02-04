const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const skip_perf = b.option(bool, "skip-perf", "Skip performance regression tests") orelse false;

    // Create the core module
    const zigenv_mod = b.addModule("zigenv", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Library
    const lib = b.addLibrary(.{
        .name = "zigenv",
        .root_module = zigenv_mod,
    });
    b.installArtifact(lib);

    // Unit tests
    const unit_tests = b.addTest(.{
        .root_module = zigenv_mod,
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    // Add external test files
    const test_files = [_][]const u8{
        "tests/basic_test.zig",
        "tests/quote_test.zig",
        "tests/escape_test.zig",
        "tests/interpolation_test.zig",
        "tests/heredoc_test.zig",
        "tests/edge_cases.zig",
        "tests/garbage_after_quote.zig",
        "tests/single_quote_heredoc_test.zig",
        "tests/braceless_variable_test.zig",
        "tests/whitespace_interpolation_test.zig",
        // Extensive test suite
        "tests/file_based_tests.zig",
        "tests/edge_cases_comprehensive.zig",
        "tests/unicode_tests.zig",
        "tests/windows_tests.zig",
        "tests/stress_tests.zig",
        "tests/fuzz_tests.zig",
        "tests/property_tests.zig",
        "tests/compatibility_tests.zig",
        "tests/performance_regression_tests.zig",
        "tests/error_messages_tests.zig",
        "tests/custom_lists_test.zig",
    };

    for (test_files) |test_file| {
        if (skip_perf and std.mem.eql(u8, test_file, "tests/performance_regression_tests.zig")) {
            continue;
        }
        // Each test file needs its own module because they are separate root source files
        const test_mod = b.createModule(.{
            .root_source_file = b.path(test_file),
            .target = target,
            .optimize = optimize,
        });
        // Import the library module into the test module
        test_mod.addImport("zigenv", zigenv_mod);

        const tests = b.addTest(.{
            .root_module = test_mod,
        });
        const run_tests = b.addRunArtifact(tests);
        test_step.dependOn(&run_tests.step);
    }

    // Documentation
    const install_docs = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    const docs_step = b.step("docs", "Generate documentation");
    docs_step.dependOn(&install_docs.step);

    // Benchmarks
    const benchmark_mod = b.createModule(.{
        .root_source_file = b.path("benchmarks/allocation_benchmark.zig"),
        .target = target,
        .optimize = .ReleaseFast, // Always optimize benchmarks for accurate results
    });
    benchmark_mod.addImport("zigenv", zigenv_mod);

    const benchmark_exe = b.addExecutable(.{
        .name = "allocation_benchmark",
        .root_module = benchmark_mod,
    });
    b.installArtifact(benchmark_exe);

    const benchmark_cmd = b.addRunArtifact(benchmark_exe);
    const benchmark_step = b.step("benchmark", "Run allocation benchmarks");
    benchmark_step.dependOn(&benchmark_cmd.step);

    // Benchmark tests
    const benchmark_test = b.addTest(.{
        .root_module = benchmark_mod,
    });
    const run_benchmark_tests = b.addRunArtifact(benchmark_test);
    test_step.dependOn(&run_benchmark_tests.step);

    // --- Advanced Benchmarking Suite ---

    // Common bench step
    const bench_step = b.step("bench", "Run all benchmarks");
    // Add existing legacy benchmark
    bench_step.dependOn(&benchmark_cmd.step);

    // Micro Benchmarks
    const micro_bench_mod = b.createModule(.{
        .root_source_file = b.path("benchmarks/micro_benchmarks.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });
    micro_bench_mod.addImport("zigenv", zigenv_mod);

    const micro_bench_exe = b.addExecutable(.{
        .name = "micro_benchmarks",
        .root_module = micro_bench_mod,
    });

    b.installArtifact(micro_bench_exe);

    const run_micro_bench = b.addRunArtifact(micro_bench_exe);
    if (b.args) |args| {
        run_micro_bench.addArgs(args);
    }

    const bench_micro_step = b.step("bench:micro", "Run micro-benchmarks");
    bench_micro_step.dependOn(&run_micro_bench.step);
    bench_step.dependOn(&run_micro_bench.step);

    // Throughput Benchmarks
    const throughput_bench_mod = b.createModule(.{
        .root_source_file = b.path("benchmarks/throughput_benchmarks.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });
    throughput_bench_mod.addImport("zigenv", zigenv_mod);

    const throughput_bench_exe = b.addExecutable(.{
        .name = "throughput_benchmarks",
        .root_module = throughput_bench_mod,
    });
    b.installArtifact(throughput_bench_exe);

    const run_throughput_bench = b.addRunArtifact(throughput_bench_exe);
    const bench_throughput_step = b.step("bench:throughput", "Run throughput benchmarks");
    bench_throughput_step.dependOn(&run_throughput_bench.step);
    bench_step.dependOn(&run_throughput_bench.step);

    // Latency Benchmarks
    const latency_bench_mod = b.createModule(.{
        .root_source_file = b.path("benchmarks/latency_benchmarks.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });
    latency_bench_mod.addImport("zigenv", zigenv_mod);

    const latency_bench_exe = b.addExecutable(.{
        .name = "latency_benchmarks",
        .root_module = latency_bench_mod,
    });
    b.installArtifact(latency_bench_exe);

    const run_latency_bench = b.addRunArtifact(latency_bench_exe);
    const bench_latency_step = b.step("bench:latency", "Run latency benchmarks");
    bench_latency_step.dependOn(&run_latency_bench.step);
    bench_step.dependOn(&run_latency_bench.step);

    // Memory Benchmarks
    const memory_bench_mod = b.createModule(.{
        .root_source_file = b.path("benchmarks/memory_benchmarks.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });
    memory_bench_mod.addImport("zigenv", zigenv_mod);

    const memory_bench_exe = b.addExecutable(.{
        .name = "memory_benchmarks",
        .root_module = memory_bench_mod,
    });
    b.installArtifact(memory_bench_exe);

    const run_memory_bench = b.addRunArtifact(memory_bench_exe);
    const bench_memory_step = b.step("bench:memory", "Run memory benchmarks");
    bench_memory_step.dependOn(&run_memory_bench.step);
    bench_step.dependOn(&run_memory_bench.step);

    // Scalability Benchmarks
    const scalability_bench_mod = b.createModule(.{
        .root_source_file = b.path("benchmarks/scalability_benchmarks.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });
    scalability_bench_mod.addImport("zigenv", zigenv_mod);

    const scalability_bench_exe = b.addExecutable(.{
        .name = "scalability_benchmarks",
        .root_module = scalability_bench_mod,
    });
    b.installArtifact(scalability_bench_exe);

    const run_scalability_bench = b.addRunArtifact(scalability_bench_exe);
    const bench_scalability_step = b.step("bench:scalability", "Run scalability benchmarks");
    bench_scalability_step.dependOn(&run_scalability_bench.step);
    bench_step.dependOn(&run_scalability_bench.step);

    // Scenario Benchmarks
    const scenario_bench_mod = b.createModule(.{
        .root_source_file = b.path("benchmarks/scenario_benchmarks.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });
    scenario_bench_mod.addImport("zigenv", zigenv_mod);

    const scenario_bench_exe = b.addExecutable(.{
        .name = "scenario_benchmarks",
        .root_module = scenario_bench_mod,
    });
    b.installArtifact(scenario_bench_exe);

    const run_scenario_bench = b.addRunArtifact(scenario_bench_exe);
    const bench_scenario_step = b.step("bench:scenario", "Run scenario benchmarks");
    bench_scenario_step.dependOn(&run_scenario_bench.step);
    bench_step.dependOn(&run_scenario_bench.step);
}
