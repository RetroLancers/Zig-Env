const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

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
    };

    for (test_files) |test_file| {
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
}
