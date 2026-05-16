const std = @import("std");
const Profiler = @import("profiler.zig");
const Processor = @import("processor.zig");
const reference = @import("reference.zig");
const Parser = @import("parser.zig");

const GlobalProfiler = &@import("global.zig").GlobalProfiler;

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;

    GlobalProfiler.init("GLOBAL PROFILER");
    defer {
        GlobalProfiler.deinit();
        GlobalProfiler.log();
    }

    var iter = try init.minimal.args.iterateAllocator(gpa);
    _ = iter.next();
    const path = iter.next() orelse return Error.MissingArgs;

    const info = try Parser.parse_path(path, GlobalProfiler);

    var processor: Processor = undefined;
    try processor.init(init.io, gpa, path, GlobalProfiler);
    defer processor.deinit();

    const count = processor.process();
    const res = count / @as(f64, @floatFromInt(info.size));

    if (info.res != res) {
        std.log.err("expected: {}, got: {}", .{ info.res, res });
    }
}

pub const PathInfo = struct {
    seed: u64,
    size: u64,
    res: f64,
};

const Error =
    error{
        MissingArgs,
    };
