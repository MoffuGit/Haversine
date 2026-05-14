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
    buffer: []u8,
    zone: Profiler.Zone,
};

test "Bench Branch Prediction" {
    const io = std.testing.io;
    const gpa = std.testing.allocator;

    const buffer = try gpa.alloc(u8, 10000000);
    defer gpa.free(buffer);

    //NOTE:
    //i expected this to reduce the time my neverTaken
    //fn would take on his max time, but din't happen
    for (0..buffer.len) |idx| {
        buffer[idx] = 0;
    }

    var ctx: Context = .{
        .io = io,
        .alloc = gpa,
        .buffer = buffer,
        .zone = undefined,
    };

    try Tester.runAll(gpa, .{
        .min_runs = 3,
        .stop_after_no_new_min_ms = 100,
        .max_runs = 200,
        .log_profiler = true,
    }, Context, &ctx, .{
        neverTaken,
        alwaysTaken,
        every2,
        every3,
        every4,
        random,
        randomSecure,
    });
}

fn neverTaken(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        for (0..ctx.buffer.len) |idx| {
            ctx.buffer[idx] = 0;
        }

        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{
            .label = "neverTaken",
            .bytes = ctx.buffer.len,
        });
        defer ctx.zone.deinit(profiler);

        conditionalNop(ctx.buffer.len, @ptrCast(ctx.buffer));
    }
}

fn alwaysTaken(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        for (0..ctx.buffer.len) |idx| {
            ctx.buffer[idx] = 1;
        }

        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{
            .label = "alwaysTaken",
            .bytes = ctx.buffer.len,
        });
        defer ctx.zone.deinit(profiler);

        conditionalNop(ctx.buffer.len, @ptrCast(ctx.buffer));
    }
}

fn every2(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        for (0..ctx.buffer.len) |idx| {
            ctx.buffer[idx] = @intFromBool(idx % 2 == 0);
        }

        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{
            .label = "every2",
            .bytes = ctx.buffer.len,
        });
        defer ctx.zone.deinit(profiler);

        conditionalNop(ctx.buffer.len, @ptrCast(ctx.buffer));
    }
}

fn every3(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        for (0..ctx.buffer.len) |idx| {
            ctx.buffer[idx] = @intFromBool(idx % 3 == 0);
        }

        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{
            .label = "every3",
            .bytes = ctx.buffer.len,
        });
        defer ctx.zone.deinit(profiler);

        conditionalNop(ctx.buffer.len, @ptrCast(ctx.buffer));
    }
}

fn every4(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        for (0..ctx.buffer.len) |idx| {
            ctx.buffer[idx] = @intFromBool(idx % 4 == 0);
        }

        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{
            .label = "every4",
            .bytes = ctx.buffer.len,
        });
        defer ctx.zone.deinit(profiler);

        conditionalNop(ctx.buffer.len, @ptrCast(ctx.buffer));
    }
}

fn random(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        const rng_impl: std.Random.IoSource = .{ .io = ctx.io };
        const rng = rng_impl.interface();

        for (0..ctx.buffer.len) |idx| {
            if (rng.boolean()) {
                ctx.buffer[idx] = 1;
            }
        }

        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{
            .label = "random",
            .bytes = ctx.buffer.len,
        });
        defer ctx.zone.deinit(profiler);

        conditionalNop(ctx.buffer.len, @ptrCast(ctx.buffer));
    }
}

fn randomSecure(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        try ctx.io.randomSecure(ctx.buffer);

        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{
            .label = "randomSecure",
            .bytes = ctx.buffer.len,
        });
        defer ctx.zone.deinit(profiler);

        conditionalNop(ctx.buffer.len, @ptrCast(ctx.buffer));
    }
}

fn conditionalNop(count: u64, buffer: *anyopaque) void {
    asm volatile (
        \\ mov x9, xzr
        \\1:
        \\ ldr x10, [%[buffer], x9]
        \\ add x9, x9, #1
        \\ tst x10, #1
        \\ b.ne 2f
        \\ nop
        \\2:
        \\ cmp x9, %[count]
        \\ b.lo 1b
        :
        : [count] "r" (count),
          [buffer] "r" (buffer),
        : .{ .x9 = true, .x10 = true, .memory = true });
}

//I didn't get it right
// fn conditionalNop(count: u64, buffer: *anyopaque) void {
//     asm volatile (
//         \\ eor x9, x9, x9
//         \\1:
//         \\ move x10, [%[data], x9]
//         \\ add x9, x9, #1
//         \\ tst x10, 1
//         \\ b.ne 2b
//         \\nop
//         \\2:
//         \\ cmp x9, %[count]
//         \\ b.lo 1b
//         :
//         : [count] "r" (count),
//           [buffer] "r" (buffer),
//         : .{ .x9 = true, .memory = true });
// }
