const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // export pure Zig module for other Zig projects integration
    // registered with the name "zslay"
    _ = b.addModule("zslay", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // build C-compatible static library through src/c_api.zig
    // compiles exported symbols with C calling conventions
    const lib = b.addStaticLibrary(.{
        .name = "zslay",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/c_api.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // output compiled library
    b.installArtifact(lib);

    // setup local unit tests from src/test.zig
    // executed natively via "zig build test" inside Nix
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
