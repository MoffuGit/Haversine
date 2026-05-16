const std = @import("std");
const Profiler = @import("profiler.zig");
const Processor = @import("processor.zig");
const reference = @import("reference.zig");

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

    const info = try parse_path(path);

    var processor: Processor = undefined;
    try processor.init(init.io, gpa, path);
    defer processor.deinit();

    const count = processor.process(reference.referenceHaversine);
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
    std.fmt.ParseFloatError ||
    std.fmt.ParseIntError ||
    error{
        MissingArgs,
    };

pub fn parse_path(path: [:0]const u8) Error!PathInfo {
    var zone: Profiler.Zone = .empty;
    zone.init(@src(), GlobalProfiler, .{ .label = "parsePath" });
    defer zone.deinit(GlobalProfiler);

    const basename = std.fs.path.basename(path);
    const stem = std.fs.path.stem(basename);

    var parts = std.mem.splitScalar(u8, stem, '_');

    const seed_arg = parts.next() orelse return Error.MissingArgs;
    const seed = try std.fmt.parseInt(u64, seed_arg, 10);

    const size_arg = parts.next() orelse return Error.MissingArgs;
    const size = try std.fmt.parseInt(u64, size_arg, 10);

    const res_arg = parts.next() orelse return Error.MissingArgs;
    const res = try std.fmt.parseFloat(f64, res_arg);

    return .{
        .size = size,
        .seed = seed,
        .res = res,
    };
}
