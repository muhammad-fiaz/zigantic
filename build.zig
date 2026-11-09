const std = @import("std");

const examples = [_][]const u8{
    "basic",
    "model",
    "errors",
    "nested",
    "collections",
    "formats",
    "unions",
    "modifiers",
    "query",
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const tint = b.dependency("tint", .{ .target = target, .optimize = optimize }).module("tint");

    const zigantic = b.addModule("zigantic", .{
        .root_source_file = b.path("src/zigantic.zig"),
        .target = target,
        .optimize = optimize,
    });
    zigantic.addImport("tint", tint);

    const tests = b.addTest(.{ .root_module = zigantic });
    const run_tests = b.addRunArtifact(tests);
    b.step("test", "Run the unit and integration tests").dependOn(&run_tests.step);

    const run_all = b.step("run-all-examples", "Run every example");

    inline for (examples) |name| {
        const exe = b.addExecutable(.{
            .name = name,
            .root_module = b.createModule(.{
                .root_source_file = b.path("examples/" ++ name ++ ".zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        exe.root_module.addImport("zigantic", zigantic);

        b.step("example-" ++ name, "Build an example").dependOn(&b.addInstallArtifact(exe, .{}).step);
        const run = b.addRunArtifact(exe);
        b.step("run-" ++ name, "Run an example").dependOn(&run.step);
        run_all.dependOn(&run.step);
    }

    const bench = b.addExecutable(.{
        .name = "benchmark",
        .root_module = b.createModule(.{
            .root_source_file = b.path("bench/benchmark.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });
    bench.root_module.addImport("zigantic", zigantic);
    const run_bench = b.addRunArtifact(bench);
    b.step("bench", "Run the benchmarks").dependOn(&run_bench.step);

    const docs = b.addObject(.{ .name = "zigantic", .root_module = zigantic });
    const install_docs = b.addInstallDirectory(.{
        .source_dir = docs.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs/api",
    });
    b.step("docs", "Generate the native Zig API documentation").dependOn(&install_docs.step);

    const test_all = b.step("test-all", "Run tests, examples and benchmarks");
    test_all.dependOn(&run_tests.step);
    test_all.dependOn(run_all);
    test_all.dependOn(&run_bench.step);
}
