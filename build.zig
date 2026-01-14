const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the zigantic module
    const zigantic_module = b.createModule(.{
        .root_source_file = b.path("src/zigantic.zig"),
    });

    // Expose the module for external projects
    _ = b.addModule("zigantic", .{
        .root_source_file = b.path("src/zigantic.zig"),
    });

    // Build examples
    const examples = [_]struct { name: []const u8, path: []const u8 }{
        .{ .name = "basic", .path = "examples/basic.zig" },
        .{ .name = "advanced_types", .path = "examples/advanced_types.zig" },
        .{ .name = "validators", .path = "examples/validators.zig" },
        .{ .name = "json_example", .path = "examples/json_example.zig" },
        .{ .name = "error_handling", .path = "examples/error_handling.zig" },
    };

    // Create run-all-examples step
    const run_all_examples = b.step("run-all-examples", "Run all examples sequentially");
    var previous_run_step: ?*std.Build.Step = null;

    inline for (examples) |example| {
        const exe = b.addExecutable(.{
            .name = example.name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(example.path),
                .target = target,
                .optimize = optimize,
            }),
        });
        exe.root_module.addImport("zigantic", zigantic_module);

        const install_exe = b.addInstallArtifact(exe, .{});
        const example_step = b.step("example-" ++ example.name, "Build " ++ example.name ++ " example");
        example_step.dependOn(&install_exe.step);

        const run_exe = b.addRunArtifact(exe);
        run_exe.step.dependOn(&install_exe.step);
        const run_step = b.step("run-" ++ example.name, "Run " ++ example.name ++ " example");
        run_step.dependOn(&run_exe.step);

        // Add to run-all-examples
        const run_all_exe = b.addRunArtifact(exe);
        if (previous_run_step) |prev| {
            run_all_exe.step.dependOn(prev);
        }
        previous_run_step = &run_all_exe.step;
    }

    if (previous_run_step) |last| {
        run_all_examples.dependOn(last);
    }

    // Default example
    const default_example = b.addExecutable(.{
        .name = "example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/basic.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    default_example.root_module.addImport("zigantic", zigantic_module);
    const install_default = b.addInstallArtifact(default_example, .{});
    const run_default = b.addRunArtifact(default_example);
    run_default.step.dependOn(&install_default.step);
    const example_step = b.step("example", "Run the basic example");
    example_step.dependOn(&run_default.step);

    // Unit tests
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/zigantic.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    // Benchmark
    const bench_exe = b.addExecutable(.{
        .name = "benchmark",
        .root_module = b.createModule(.{
            .root_source_file = b.path("bench/benchmark.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });
    bench_exe.root_module.addImport("zigantic", zigantic_module);

    const install_bench = b.addInstallArtifact(bench_exe, .{});
    const run_bench = b.addRunArtifact(bench_exe);
    run_bench.step.dependOn(&install_bench.step);

    const bench_step = b.step("bench", "Run benchmarks");
    bench_step.dependOn(&run_bench.step);

    // Docs generation
    const docs_step = b.step("docs", "Generate documentation");
    const docs_obj = b.addObject(.{
        .name = "zigantic",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/zigantic.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const install_docs = b.addInstallDirectory(.{
        .source_dir = docs_obj.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    docs_step.dependOn(&install_docs.step);

    // Test-all step (runs tests, benchmarks, and examples)
    const test_all_step = b.step("test-all", "Run all tests, benchmarks, and examples sequentially");
    test_all_step.dependOn(test_step);
    test_all_step.dependOn(bench_step);
    test_all_step.dependOn(run_all_examples);

    // Library
    const lib = b.addLibrary(.{
        .name = "zigantic",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/zigantic.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(lib);
}
