const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const profiler_enabled = b.option(
        bool,
        "profiler",
        "Enable the Profiler instrumentation (default: true). Set to false to compile it out as a no-op.",
    ) orelse true;

    const build_options = b.addOptions();
    build_options.addOption(bool, "profiler", profiler_enabled);
    const build_options_module = build_options.createModule();

    const generator_module = b.createModule(.{
        .root_source_file = b.path("src/generator.zig"),
        .target = target,
        .optimize = optimize,
    });
    generator_module.addImport("build_options", build_options_module);

    const generator = b.addExecutable(.{
        .name = "Generator",
        .root_module = generator_module,
    });

    const install_generator = b.addInstallArtifact(generator, .{});

    const gen_step = b.step("gen", "Run the generator");

    const gen_cmd = b.addRunArtifact(generator);
    gen_cmd.step.dependOn(&install_generator.step);
    gen_step.dependOn(&gen_cmd.step);

    if (b.args) |args| {
        gen_cmd.addArgs(args);
    }

    const processor_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    processor_module.addImport("build_options", build_options_module);

    const processor = b.addExecutable(.{
        .name = "Processor",
        .root_module = processor_module,
    });

    const install_processor = b.addInstallArtifact(processor, .{});

    const prop_step = b.step("prop", "Run the processor");

    const prop_cmd = b.addRunArtifact(processor);
    prop_cmd.step.dependOn(&install_processor.step);
    prop_step.dependOn(&prop_cmd.step);

    if (b.args) |args| {
        prop_cmd.addArgs(args);
    }

    const reader_bench_module = b.createModule(.{
        .root_source_file = b.path("src/reader_bench.zig"),
        .target = target,
        .optimize = optimize,
    });
    reader_bench_module.addImport("build_options", build_options_module);

    const reader_bench = b.addExecutable(.{
        .name = "ReaderBench",
        .root_module = reader_bench_module,
    });

    const install_reader_bench = b.addInstallArtifact(reader_bench, .{});

    const reader_bench_step = b.step("bench-reader", "Run the reader benchmark");
    const reader_bench_cmd = b.addRunArtifact(reader_bench);
    reader_bench_cmd.step.dependOn(&install_reader_bench.step);
    reader_bench_step.dependOn(&reader_bench_cmd.step);

    if (b.args) |args| {
        reader_bench_cmd.addArgs(args);
    }

    b.getInstallStep().dependOn(&install_generator.step);
    b.getInstallStep().dependOn(&install_processor.step);
    b.getInstallStep().dependOn(&install_reader_bench.step);

    const tests_module = b.createModule(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    tests_module.addImport("build_options", build_options_module);

    const tests = b.addTest(.{
        .name = "Tests",
        .root_module = tests_module,
    });

    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_tests.step);
}
