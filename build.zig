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
