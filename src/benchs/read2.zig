const std = @import("std");

const profilerpkg = @import("../profiler.zig");
const Profiler = profilerpkg.Profiler;
const Allocator = std.mem.Allocator;
const Tester = @import("../tester.zig");

const KiB = 1024;
const MiB = 1024 * KiB;

const Context = struct {
    io: std.Io,
    alloc: Allocator,
    path: [:0]const u8,
    file_size: u64,
    zone: profilerpkg.Zone,
};

test "Bench Reads 2" {
    const io = std.testing.io;
    const gpa = std.testing.allocator;

    const path = "./generated/43564768_1000000_10011.998232663716.json";

    const stat = try std.Io.Dir.cwd().statFile(io, path, .{});

    var ctx: Context = .{
        .io = io,
        .alloc = gpa,
        .path = path,
        .file_size = stat.size,
        .zone = .empty,
    };

    try Tester.runAll(gpa, .{
        .min_runs = 3,
        .stop_after_no_new_min_ms = 1000,
        .max_runs = 200,
        .log_profiler = true,
    }, Context, &ctx, .{
        allocAndRead,
        allocAndTouch,
    });
}

fn allocAndTouch(_ctx: ?*Context, profiler: *Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .label = "allocAndTouch", .bytes = 2 * MiB, .flags = .{ .page_faults = true } });
        defer ctx.zone.deinit(profiler);
        const buffer = try ctx.alloc.alloc(u8, 2 * MiB);
        defer ctx.alloc.free(buffer);

        for (0..(buffer.len + 128 - 1) / 128) |idx| {
            buffer[idx * 128] = 1;
        }
    }
}

fn allocAndRead(_ctx: ?*Context, profiler: *Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .label = "allocAndRead", .bytes = ctx.file_size, .flags = .{ .page_faults = true } });
        defer ctx.zone.deinit(profiler);
        const buffer = try ctx.alloc.alloc(u8, 2 * MiB);
        defer ctx.alloc.free(buffer);

        var file = try std.Io.Dir.cwd().openFile(ctx.io, ctx.path, .{});
        defer file.close(ctx.io);

        var reader = file.reader(ctx.io, buffer);
        const interface = &reader.interface;

        while (true) {
            interface.fill(buffer.len) catch break;
            interface.tossBuffered();
        }
    }
}

// fn allocBuffer(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
//     if (_ctx) |ctx| {
//         ctx.zone = .empty;
//         ctx.zone.init(@src(), profiler, .{ .label = "allocBuffer", .bytes = ctx.file_size, .flags = .{ .page_faults = true } });
//         defer ctx.zone.deinit(profiler);
//         const buffer = try ctx.alloc.alloc(u8, 2 * MiB);
//         defer ctx.alloc.free(buffer);
//
//         var file = try std.Io.Dir.cwd().openFile(ctx.io, ctx.path, .{});
//         defer file.close(ctx.io);
//
//         var reader = file.reader(ctx.io, buffer);
//         const interface = &reader.interface;
//
//         while (true) {
//             interface.fill(buffer.len) catch break;
//             interface.tossBuffered();
//         }
//     }
// }
