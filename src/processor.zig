const std = @import("std");
const ArrayList = std.ArrayList;
const mem = std.mem;
const reference = @import("reference.zig");
const Parser = @import("parser.zig");
const Profiler = @import("profiler.zig");

const GlobalProfiler = &@import("global.zig").GlobalProfiler;

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;

    GlobalProfiler.init();
    defer {
        GlobalProfiler.deinit();
        GlobalProfiler.log();
    }

    const args = try parse_args(init.minimal.args, gpa);

    var file_zone: Profiler.Zone = .empty;
    file_zone.init(@src(), GlobalProfiler);

    const file = try std.Io.Dir.cwd().openFile(init.io, args.path, .{});
    defer file.close(init.io);

    var buffer: [1024 * 1024 * 8]u8 = undefined;
    var reader = file.reader(init.io, &buffer);

    file_zone.deinit(true, GlobalProfiler);

    var parser: Parser = undefined;
    parser.init(&reader.interface, gpa);
    defer parser.deinit();

    var count: f64 = 0.0;

    while (parser.next()) |p| {
        var zone: Profiler.Zone = .empty;
        zone.init(@src(), GlobalProfiler);
        defer zone.deinit(false, GlobalProfiler);
        count += reference.referenceHaversine(p.x0, p.y0, p.x1, p.y1, 6372.8);
    }

    const res = count / @as(f64, @floatFromInt(args.size));

    if (args.res != res) {
        std.log.info("expected: {}, got: {}", .{ args.res, res });
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
    zone.init(@src(), GlobalProfiler);
    zone.deinit(true, GlobalProfiler);

    var iter = try args.iterateAllocator(alloc);
    _ = iter.next();

    const path_arg = iter.next() orelse return Error.MissingArgs;

    var split = std.mem.splitScalar(u8, path_arg, '/');
    _ = split.next();
    _ = split.next();

    const name = split.next() orelse return Error.MissingArgs;
    var _split = std.mem.splitScalar(u8, name, '_');

    const seed_arg = _split.next() orelse return Error.MissingArgs;
    const seed = try std.fmt.parseInt(u64, seed_arg, 10);

    const size_arg = _split.next() orelse return Error.MissingArgs;
    const size = try std.fmt.parseInt(u64, size_arg, 10);

    const res_arg = _split.next() orelse return Error.MissingArgs;
    const res_trim = std.mem.trimEnd(u8, res_arg, ".json");
    const res = try std.fmt.parseFloat(f64, res_trim);

    return .{
        .path = path_arg,
        .size = size,
        .seed = seed,
        .res = res,
    };
}
