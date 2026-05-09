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

    const install_generator = b.addInstallArtifact(generator, .{});

    const gen_step = b.step("gen", "Run the generator");

    const gen_cmd = b.addRunArtifact(generator);
    gen_cmd.step.dependOn(&install_generator.step);
    gen_step.dependOn(&gen_cmd.step);

    if (b.args) |args| {
        gen_cmd.addArgs(args);
    }

    const processor = b.addExecutable(.{
        .name = "Processor",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/processor.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const install_processor = b.addInstallArtifact(processor, .{});

    const prop_step = b.step("prop", "Run the processor");

    const prop_cmd = b.addRunArtifact(processor);
    prop_cmd.step.dependOn(&install_processor.step);
    prop_step.dependOn(&prop_cmd.step);

    if (b.args) |args| {
        prop_cmd.addArgs(args);
    }

    b.getInstallStep().dependOn(&install_generator.step);
    b.getInstallStep().dependOn(&install_processor.step);

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
