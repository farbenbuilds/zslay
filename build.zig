const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // export pure Zig module
    _ = b.addModule("zslay", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // build C-compatible static library
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "zslay",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/c_api.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    lib.installHeader(b.path("include/zslay.h"), "zslay.h");
    b.installArtifact(lib);

    // build the C ABI smoke test against the static library
    // Linux uses a static musl target so sandboxed Nix checks can spawn the binary
    const smoke_target = if (target.result.os.tag == .linux)
        b.resolveTargetQuery(.{
            .cpu_arch = target.result.cpu.arch,
            .os_tag = .linux,
            .abi = .musl,
        })
    else
        target;

    const c_smoke = b.addExecutable(.{
        .name = "c_api_smoke",
        .root_module = b.createModule(.{
            .target = smoke_target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    c_smoke.root_module.addCSourceFile(.{
        .file = b.path("src/c_api_smoke.c"),
        .flags = &.{ "-std=c11", "-Wall", "-Wextra" },
    });
    c_smoke.root_module.addIncludePath(b.path("include"));
    c_smoke.root_module.linkLibrary(lib);

    const run_c_smoke = b.addRunArtifact(c_smoke);

    // build and run the benchmark executable
    const bench = b.addExecutable(.{
        .name = "zslay-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/bench.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const bench_step = b.step("bench", "Build and run the zslay benchmark");
    bench_step.dependOn(&b.addRunArtifact(bench).step);

    // setup local unit tests
    const lib_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_lib_tests = b.addRunArtifact(lib_tests);

    const test_step = b.step("test", "Run unit tests for zslay");
    test_step.dependOn(&run_lib_tests.step);
    test_step.dependOn(&run_c_smoke.step);

    const check_step = b.step("check", "Run semantic linter");
    check_step.dependOn(&lib.step);
    check_step.dependOn(&lib_tests.step);
    check_step.dependOn(&c_smoke.step);
    check_step.dependOn(&bench.step);
}
