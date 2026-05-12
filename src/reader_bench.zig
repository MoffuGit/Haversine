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

    const strategies: [4]Strategy = .{
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
    };

    var tester: Tester = undefined;
    for (strategies) |strategy| {
        tester = .empty;
        tester.init(gpa, .{
            .min_runs = 3,
            .stop_after_no_new_min_ms = 10000,
        });
        defer tester.deinit();

        std.log.info("--- strategy: {s} ---", .{strategy.label});

        try tester.run(Context, &ctx, strategy.cb);
        tester.log();
    }
}

const Strategy = struct {
    label: []const u8,
    cb: *const fn (*Context, *Profiler.Profiler) anyerror!void,
};

fn readBuffer64k(ctx: *Context, profiler: *Profiler.Profiler) !void {
    var z: Profiler.Zone = .empty;
    z.init(@src(), profiler, .{ .label = "readBuffer64k", .bytes = ctx.file_size });
    defer z.deinit(profiler);

    var buffer: [64 * KiB]u8 = undefined;

    var file = try std.Io.Dir.cwd().openFile(ctx.io, ctx.path, .{});
    defer file.close(ctx.io);

    var reader = file.reader(ctx.io, &buffer);
    const interface = &reader.interface;

    while (true) {
        _ = interface.takeByte() catch break;
    }
}

fn readBuffer1mb(ctx: *Context, profiler: *Profiler.Profiler) !void {
    var z: Profiler.Zone = .empty;
    z.init(@src(), profiler, .{ .label = "readBuffer1mb", .bytes = ctx.file_size });
    defer z.deinit(profiler);

    var buffer: [MiB]u8 = undefined;

    var file = try std.Io.Dir.cwd().openFile(ctx.io, ctx.path, .{});
    defer file.close(ctx.io);

    var reader = file.reader(ctx.io, &buffer);
    const interface = &reader.interface;

    while (true) {
        _ = interface.takeByte() catch break;
    }
}

fn readBuffer8mb(ctx: *Context, profiler: *Profiler.Profiler) !void {
    var z: Profiler.Zone = .empty;
    z.init(@src(), profiler, .{ .label = "readBuffer8mb", .bytes = ctx.file_size });
    defer z.deinit(profiler);

    var buffer: [MiB * 8]u8 = undefined;

    var file = try std.Io.Dir.cwd().openFile(ctx.io, ctx.path, .{});
    defer file.close(ctx.io);

    var reader = file.reader(ctx.io, &buffer);
    const interface = &reader.interface;

    while (true) {
        _ = interface.takeByte() catch break;
    }
}

fn allocBuffer(ctx: *Context, profiler: *Profiler.Profiler) !void {
    var z: Profiler.Zone = .empty;
    z.init(@src(), profiler, .{ .label = "allocBuffer", .bytes = ctx.file_size });
    defer z.deinit(profiler);

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

//BUG:
//this things dont work, they fail with INVAL,
//the file size is the issue,
// fn readFileAlloc(ctx: *Context, profiler: *Profiler.Profiler) !void {
//     var z: Profiler.Zone = .empty;
//     z.init(@src(), profiler, .{ .label = "readBuffered", .bytes = ctx.file_size });
//     defer z.deinit(profiler);
//
//     // const file = try std.Io.Dir.cwd().readFileAlloc(ctx.io, ctx.path, ctx.alloc, .unlimited);
//     // defer ctx.alloc.free(file);
// }
//
// pub fn readFile(ctx: *Context, profiler: *Profiler.Profiler) !void {
//     var z: Profiler.Zone = .empty;
//     z.init(@src(), profiler, .{ .label = "readBuffered", .bytes = ctx.file_size });
//     defer z.deinit(profiler);
//
//     const content = try ctx.alloc.alloc(u8, ctx.file_size);
//     defer ctx.alloc.free(content);
//     _ = try std.Io.Dir.cwd().readFile(ctx.io, ctx.path, content);
// }
