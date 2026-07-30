const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // export zig module for integration
    const zslay_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // build static library
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "zslay",
        .root_module = zslay_mod,
    });

    // output compiled library
    b.installArtifact(lib);

    // setup local unit tests
    const lib_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_lib_tests = b.addRunArtifact(lib_tests);

    // expose the build to the CLI
    const test_step = b.step("test", "Run unit tests for zslay");
    test_step.dependOn(&run_lib_tests.step);
}
