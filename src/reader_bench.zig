const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;

const Profiler = @import("profiler.zig");
const Tester = @import("tester.zig");

const KiB = 1024;
const MiB = 1024 * KiB;

const Context = struct {
    io: std.Io,
    alloc: Allocator,
    path: [:0]const u8,
    file_size: u64,
};

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    var arg_it = init.minimal.args.iterate();
    _ = arg_it.next() orelse return error.MissingArgs;
    const path = arg_it.next() orelse return error.MissingArgs;

    std.log.info("readers bench | file: {s}", .{path});

    const stat = try std.Io.Dir.cwd().statFile(io, path, .{});

    var ctx: Context = .{
        .io = io,
        .alloc = gpa,
        .path = path,
        .file_size = stat.size,
    };

    const strategies: [1]Strategy = .{.{
        .cb = readBuffered,
        .label = "readBuffered",
    }};

    var tester: Tester = undefined;
    for (strategies) |strategy| {
        tester = .empty;
        tester.init(gpa, .{
            .min_runs = 3,
            .stop_after_no_new_min_ms = 1500,
        });
        defer tester.deinit();

        std.log.info("--- strategy: {s} ---", .{strategy.label});

        try tester.run(Context, &ctx, strategy.cb);
        tester.log();
    }
}

const Strategy = struct {
    cb: *const fn (*Context, *Profiler.Profiler) anyerror!void,
    label: []const u8,
};

fn readBuffered(ctx: *Context, profiler: *Profiler.Profiler) !void {
    var z: Profiler.Zone = .empty;
    z.init(@src(), profiler, .{ .label = "readBuffered", .bytes = ctx.file_size });
    defer z.deinit(profiler);

    const file = try std.Io.Dir.cwd().openFile(ctx.io, ctx.path, .{});
    defer file.close(ctx.io);

    var buffer: [64 * KiB]u8 = undefined;

    var reader = file.reader(ctx.io, &buffer);
    const interface = &reader.interface;

    _ = interface.discardRemaining() catch |err| switch (err) {
        error.ReadFailed => return err,
    };
}
