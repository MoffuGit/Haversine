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

test "Bench Read Ports" {
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
    }, Context, &ctx, .{
        readx1,
        readx2,
        readx3,
        readx4,
        // readx1byte, readx1half, readx1word, readx1,
        // readx2byte, readx2half, readx2word, readx2,
    });
}

fn readx1byte(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "readx1byte" });
        defer ctx.zone.deinit(profiler);

        var count = ctx.buffer.len;

        asm volatile (
            \\1:
            \\ ldrb w9, [%[buffer]]
            \\ subs %[count], %[count], #1
            \\ b.gt 1b
            : [count] "+r" (count),
            : [buffer] "r" (ctx.buffer.ptr),
            : .{ .x9 = true, .memory = true, .nzcv = true });
    }
}

fn readx1half(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "readx1half" });
        defer ctx.zone.deinit(profiler);

        var count = ctx.buffer.len;

        asm volatile (
            \\1:
            \\ ldrh w9, [%[buffer]]
            \\ subs %[count], %[count], #1
            \\ b.gt 1b
            : [count] "+r" (count),
            : [buffer] "r" (ctx.buffer.ptr),
            : .{ .x9 = true, .memory = true, .nzcv = true });
    }
}

fn readx1word(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "readx1word" });
        defer ctx.zone.deinit(profiler);

        var count = ctx.buffer.len;

        asm volatile (
            \\1:
            \\ ldr w9, [%[buffer]]
            \\ subs %[count], %[count], #1
            \\ b.gt 1b
            : [count] "+r" (count),
            : [buffer] "r" (ctx.buffer.ptr),
            : .{ .x9 = true, .memory = true, .nzcv = true });
    }
}

fn readx1(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "readx1" });
        defer ctx.zone.deinit(profiler);

        var count = ctx.buffer.len;

        asm volatile (
            \\1:
            \\ ldr x9, [%[buffer]]
            \\ subs %[count], %[count], #1
            \\ b.gt 1b
            : [count] "+r" (count),
            : [buffer] "r" (ctx.buffer.ptr),
            : .{ .x9 = true, .memory = true, .nzcv = true });
    }
}

fn readx2byte(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "readx2byte" });
        defer ctx.zone.deinit(profiler);

        var count = ctx.buffer.len;

        asm volatile (
            \\1:
            \\ ldrb w9, [%[buffer]]
            \\ ldrb w9, [%[buffer]]
            \\ subs %[count], %[count], #1
            \\ b.gt 1b
            : [count] "+r" (count),
            : [buffer] "r" (ctx.buffer.ptr),
            : .{ .x9 = true, .memory = true, .nzcv = true });
    }
}

fn readx2half(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "readx2half" });
        defer ctx.zone.deinit(profiler);

        var count = ctx.buffer.len;

        asm volatile (
            \\1:
            \\ ldrh w9, [%[buffer]]
            \\ ldrh w9, [%[buffer]]
            \\ subs %[count], %[count], #1
            \\ b.gt 1b
            : [count] "+r" (count),
            : [buffer] "r" (ctx.buffer.ptr),
            : .{ .x9 = true, .memory = true, .nzcv = true });
    }
}

fn readx2word(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "readx2word" });
        defer ctx.zone.deinit(profiler);

        var count = ctx.buffer.len;

        asm volatile (
            \\1:
            \\ ldr w9, [%[buffer]]
            \\ ldr w9, [%[buffer]]
            \\ subs %[count], %[count], #1
            \\ b.gt 1b
            : [count] "+r" (count),
            : [buffer] "r" (ctx.buffer.ptr),
            : .{ .x9 = true, .memory = true, .nzcv = true });
    }
}

fn readx2(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "readx2" });
        defer ctx.zone.deinit(profiler);

        var count = ctx.buffer.len;

        asm volatile (
            \\1:
            \\ ldr x9, [%[buffer]]
            \\ ldr x9, [%[buffer]]
            \\ subs %[count], %[count], #2
            \\ b.gt 1b
            : [count] "+r" (count),
            : [buffer] "r" (ctx.buffer.ptr),
            : .{ .x9 = true, .memory = true, .nzcv = true });
    }
}

fn readx3(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "readx3" });
        defer ctx.zone.deinit(profiler);

        var count = ctx.buffer.len;

        asm volatile (
            \\1:
            \\ ldr x9, [%[buffer]]
            \\ ldr x9, [%[buffer]]
            \\ ldr x9, [%[buffer]]
            \\ subs %[count], %[count], #3
            \\ b.gt 1b
            : [count] "+r" (count),
            : [buffer] "r" (ctx.buffer.ptr),
            : .{ .x9 = true, .memory = true, .nzcv = true });
    }
}

fn readx4(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "readx4" });
        defer ctx.zone.deinit(profiler);

        var count = ctx.buffer.len;

        asm volatile (
            \\1:
            \\ ldr x9, [%[buffer]]
            \\ ldr x9, [%[buffer]]
            \\ ldr x9, [%[buffer]]
            \\ ldr x9, [%[buffer]]
            \\ subs %[count], %[count], #4
            \\ b.gt 1b
            : [count] "+r" (count),
            : [buffer] "r" (ctx.buffer.ptr),
            : .{ .x9 = true, .memory = true, .nzcv = true });
    }
}

fn readx5(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "readx5" });
        defer ctx.zone.deinit(profiler);

        var count = ctx.buffer.len;

        asm volatile (
            \\1:
            \\ ldr x9, [%[buffer]]
            \\ ldr x9, [%[buffer]]
            \\ ldr x9, [%[buffer]]
            \\ ldr x9, [%[buffer]]
            \\ ldr x9, [%[buffer]]
            \\ subs %[count], %[count], #5
            \\ b.gt 1b
            : [count] "+r" (count),
            : [buffer] "r" (ctx.buffer.ptr),
            : .{ .x9 = true, .memory = true, .nzcv = true });
    }
}

fn readx6(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "readx6" });
        defer ctx.zone.deinit(profiler);

        var count = ctx.buffer.len;

        asm volatile (
            \\1:
            \\ ldr x9, [%[buffer]]
            \\ ldr x9, [%[buffer]]
            \\ ldr x9, [%[buffer]]
            \\ ldr x9, [%[buffer]]
            \\ ldr x9, [%[buffer]]
            \\ ldr x9, [%[buffer]]
            \\ subs %[count], %[count], #6
            \\ b.gt 1b
            : [count] "+r" (count),
            : [buffer] "r" (ctx.buffer.ptr),
            : .{ .x9 = true, .memory = true, .nzcv = true });
    }
}
