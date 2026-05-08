const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const generator = b.addExecutable(.{
        .name = "Generator",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/generator.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(generator);

    const gen_step = b.step("gen", "Run the app");

    const gen_cmd = b.addRunArtifact(generator);
    gen_step.dependOn(&gen_cmd.step);

    gen_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        gen_cmd.addArgs(args);
    }

    const tests = b.addTest(.{
        .name = "Tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tests.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_tests.step);
}
