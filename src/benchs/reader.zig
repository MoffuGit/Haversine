const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const Profiler = @import("../profiler.zig");
const Tester = @import("../tester.zig");

const KiB = 1024;
const MiB = 1024 * KiB;

const Context = struct {
    io: std.Io,
    alloc: Allocator,
    path: [:0]const u8,
    file_size: u64,
};

const Strategy = struct {
    label: []const u8,
    cb: *const fn (?*Context, *Profiler.Profiler) anyerror!void,
};

const strategies: []const Strategy = &.{
    .{
        .cb = readBuffer64k,
        .label = "readBuffer64k",
    },
    .{
        .cb = readBuffer1mb,
        .label = "readBuffer1mb",
    },
    .{
        .cb = readBuffer8mb,
        .label = "readBuffer8mb",
    },
    .{
        .cb = allocBuffer,
        .label = "allocBuffer",
    },
    .{
        .cb = writeBuffer,
        .label = "writeBuffer",
    },
};

test "Bench Reads" {
    const io = std.testing.io;
    const gpa = std.testing.allocator;

    const path = "./generated/43564768_100000000_10010.628207263575.json";

    const stat = try std.Io.Dir.cwd().statFile(io, path, .{});

    var ctx: Context = .{
        .io = io,
        .alloc = gpa,
        .path = path,
        .file_size = stat.size,
    };

    var tester: Tester = undefined;
    for (strategies) |strategy| {
        tester = .empty;
        try tester.init(gpa, strategy.label, .{
            .min_runs = 3,
            .stop_after_no_new_min_ms = 10000,
            .max_runs = 1024 * 1024,
        });
        defer tester.deinit(gpa);

        try tester.run(Context, &ctx, strategy.cb);
        tester.log();
    }
}

fn readBuffer64k(_ctx: ?*Context, _: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        var buffer: [64 * KiB]u8 = undefined;

        var file = try std.Io.Dir.cwd().openFile(ctx.io, ctx.path, .{});
        defer file.close(ctx.io);

        var reader = file.reader(ctx.io, &buffer);
        const interface = &reader.interface;

        while (true) {
            _ = interface.takeByte() catch break;
        }
    }
}

fn readBuffer1mb(_ctx: ?*Context, _: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        var buffer: [MiB]u8 = undefined;

        var file = try std.Io.Dir.cwd().openFile(ctx.io, ctx.path, .{});
        defer file.close(ctx.io);

        var reader = file.reader(ctx.io, &buffer);
        const interface = &reader.interface;

        while (true) {
            _ = interface.takeByte() catch break;
        }
    }
}

fn readBuffer8mb(_ctx: ?*Context, _: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        var buffer: [MiB * 8]u8 = undefined;

        var file = try std.Io.Dir.cwd().openFile(ctx.io, ctx.path, .{});
        defer file.close(ctx.io);

        var reader = file.reader(ctx.io, &buffer);
        const interface = &reader.interface;

        while (true) {
            _ = interface.takeByte() catch break;
        }
    }
}

fn allocBuffer(_ctx: ?*Context, _: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        var buffer: [MiB]u8 = undefined;

        var file = try std.Io.Dir.cwd().openFile(ctx.io, ctx.path, .{});
        defer file.close(ctx.io);

        const data = try ctx.alloc.alloc(u8, ctx.file_size);
        defer ctx.alloc.free(data);

        var reader = file.reader(ctx.io, &buffer);
        const interface = &reader.interface;

        var offset: usize = 0;
        while (offset < data.len) {
            const remaining = data.len - offset;
            const chunk_len = @min(remaining, buffer.len);
            const n = try interface.readSliceShort(data[offset..][0..chunk_len]);
            if (n == 0) break;
            offset += n;
        }
    }
}

fn writeBuffer(_ctx: ?*Context, _: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        const data = try ctx.alloc.alloc(u8, ctx.file_size);
        defer ctx.alloc.free(data);

        for (0..data.len) |idx| {
            data[idx] = @intCast(idx);
        }
    }
}
