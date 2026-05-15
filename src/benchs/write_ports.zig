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

test "Bench write Ports" {
    const io = std.testing.io;
    const gpa = std.testing.allocator;

    const buffer = try gpa.alloc(u8, 100000000);
    defer gpa.free(buffer);

    for (0..buffer.len) |idx| {
        buffer[idx] = 0;
    }

    var ctx: Context = .{
        .io = io,
        .alloc = gpa,
        .buffer = buffer,
        .zone = .empty,
    };

    try Tester.runAll(gpa, .{
        .min_runs = 3,
        .stop_after_no_new_min_ms = 1000,
        .max_runs = 10000,
        .log_profiler = true,
    }, Context, &ctx, .{ writex1, writex2, writex3, writex4, writex5, writex6 });
}
fn writex1(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "writex1" });
        defer ctx.zone.deinit(profiler);

        var count = ctx.buffer.len;

        asm volatile (
            \\1:
            \\ str x9, [%[buffer]]
            \\ subs %[count], %[count], #1
            \\ b.gt 1b
            : [count] "+r" (count),
            : [buffer] "r" (ctx.buffer.ptr),
            : .{ .x9 = true, .memory = true, .nzcv = true });
    }
}
fn writex2(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "writex2" });
        defer ctx.zone.deinit(profiler);

        var count = ctx.buffer.len;

        asm volatile (
            \\1:
            \\ str x9, [%[buffer]]
            \\ str x9, [%[buffer]]
            \\ subs %[count], %[count], #2
            \\ b.gt 1b
            : [count] "+r" (count),
            : [buffer] "r" (ctx.buffer.ptr),
            : .{ .x9 = true, .memory = true, .nzcv = true });
    }
}

fn writex3(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "writex3" });
        defer ctx.zone.deinit(profiler);

        var count = ctx.buffer.len;

        asm volatile (
            \\1:
            \\ str x9, [%[buffer]]
            \\ str x9, [%[buffer]]
            \\ str x9, [%[buffer]]
            \\ subs %[count], %[count], #3
            \\ b.gt 1b
            : [count] "+r" (count),
            : [buffer] "r" (ctx.buffer.ptr),
            : .{ .x9 = true, .memory = true, .nzcv = true });
    }
}

fn writex4(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "writex4" });
        defer ctx.zone.deinit(profiler);

        var count = ctx.buffer.len;

        asm volatile (
            \\1:
            \\ str x9, [%[buffer]]
            \\ str x9, [%[buffer]]
            \\ str x9, [%[buffer]]
            \\ str x9, [%[buffer]]
            \\ subs %[count], %[count], #4
            \\ b.gt 1b
            : [count] "+r" (count),
            : [buffer] "r" (ctx.buffer.ptr),
            : .{ .x9 = true, .memory = true, .nzcv = true });
    }
}

fn writex5(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "writex5" });
        defer ctx.zone.deinit(profiler);

        var count = ctx.buffer.len;

        asm volatile (
            \\1:
            \\ str x9, [%[buffer]]
            \\ str x9, [%[buffer]]
            \\ str x9, [%[buffer]]
            \\ str x9, [%[buffer]]
            \\ str x9, [%[buffer]]
            \\ subs %[count], %[count], #5
            \\ b.gt 1b
            : [count] "+r" (count),
            : [buffer] "r" (ctx.buffer.ptr),
            : .{ .x9 = true, .memory = true, .nzcv = true });
    }
}

fn writex6(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "writex6" });
        defer ctx.zone.deinit(profiler);

        var count = ctx.buffer.len;

        asm volatile (
            \\1:
            \\ str x9, [%[buffer]]
            \\ str x9, [%[buffer]]
            \\ str x9, [%[buffer]]
            \\ str x9, [%[buffer]]
            \\ str x9, [%[buffer]]
            \\ str x9, [%[buffer]]
            \\ subs %[count], %[count], #6
            \\ b.gt 1b
            : [count] "+r" (count),
            : [buffer] "r" (ctx.buffer.ptr),
            : .{ .x9 = true, .memory = true, .nzcv = true });
    }
}
