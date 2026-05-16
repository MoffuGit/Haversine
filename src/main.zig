const std = @import("std");
const mem = std.mem;
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

    const args = try parse_args(init.minimal.args, gpa);

    var processor: Processor = undefined;
    try processor.init(init.io, gpa, args.path);
    defer processor.deinit();

    const count = processor.process(reference.referenceHaversine);
    const res = count / @as(f64, @floatFromInt(args.size));

    if (args.res != res) {
        std.log.err("expected: {}, got: {}", .{ args.res, res });
    }
}

pub const Args = struct {
    seed: u64,
    size: u64,
    res: f64,
    path: [:0]const u8,
};

const Error =
    std.fmt.ParseFloatError ||
    std.fmt.ParseIntError ||
    error{
        MissingArgs,
    };

pub fn parse_args(args: std.process.Args, alloc: mem.Allocator) Error!Args {
    var zone: Profiler.Zone = .empty;
    zone.init(@src(), GlobalProfiler, .{ .label = "processArgs" });
    defer zone.deinit(GlobalProfiler);

    var iter = try args.iterateAllocator(alloc);
    _ = iter.next();

    const path_arg = iter.next() orelse return Error.MissingArgs;

    const basename = std.fs.path.basename(path_arg);
    const stem = std.fs.path.stem(basename);

    var parts = std.mem.splitScalar(u8, stem, '_');

    const seed_arg = parts.next() orelse return Error.MissingArgs;
    const seed = try std.fmt.parseInt(u64, seed_arg, 10);

    const size_arg = parts.next() orelse return Error.MissingArgs;
    const size = try std.fmt.parseInt(u64, size_arg, 10);

    const res_arg = parts.next() orelse return Error.MissingArgs;
    const res = try std.fmt.parseFloat(f64, res_arg);

    return .{
        .path = path_arg,
        .size = size,
        .seed = seed,
        .res = res,
    };
}
