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
    loop: u64,
};

test "Bench Noop Bottlenecks" {
    const io = std.testing.io;
    const gpa = std.testing.allocator;

    var ctx: Context = .{
        .io = io,
        .alloc = gpa,
        .loop = 10000000,
    };

    try Tester.runAll(gpa, .{
        .min_runs = 3,
        .stop_after_no_new_min_ms = 10000,
        .max_runs = 100,
        .log_profiler = true,
    }, Context, &ctx, .{ noop, noop3bytes, noop9bytes, noop16bytes });
}

fn noop(_ctx: ?*Context, _: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        noopAsm(ctx.loop);
    }
}

fn noop3bytes(_ctx: ?*Context, _: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        noop3bytesAsm(ctx.loop);
    }
}

fn noop9bytes(_ctx: ?*Context, _: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        noop9bytesAsm(ctx.loop);
    }
}

fn noop16bytes(_ctx: ?*Context, _: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        noop16bytesAsm(ctx.loop);
    }
}

fn noopAsm(count: u64) void {
    asm volatile (
        \\ eor x9, x9, x9
        \\1:
        \\ nop
        \\ add x9, x9, #1
        \\ cmp x9, %[count]
        \\ b.lo 1b
        :
        : [count] "r" (count),
        : .{ .x9 = true });
}

fn noop3bytesAsm(count: u64) void {
    asm volatile (
        \\ eor x9, x9, x9
        \\1:
        \\ nop
        \\ nop
        \\ nop
        \\ add x9, x9, #1
        \\ cmp x9, %[count]
        \\ b.lo 1b
        :
        : [count] "r" (count),
        : .{ .x9 = true });
}

fn noop9bytesAsm(count: u64) void {
    asm volatile (
        \\ eor x9, x9, x9
        \\1:
        \\ nop
        \\ nop
        \\ nop
        \\ nop
        \\ nop
        \\ nop
        \\ nop
        \\ nop
        \\ nop
        \\ add x9, x9, #1
        \\ cmp x9, %[count]
        \\ b.lo 1b
        :
        : [count] "r" (count),
        : .{ .x9 = true });
}

fn noop16bytesAsm(count: u64) void {
    asm volatile (
        \\ eor x9, x9, x9
        \\1:
        \\ nop
        \\ nop
        \\ nop
        \\ nop
        \\ nop
        \\ nop
        \\ nop
        \\ nop
        \\ nop
        \\ nop
        \\ nop
        \\ nop
        \\ nop
        \\ nop
        \\ nop
        \\ nop
        \\ add x9, x9, #1
        \\ cmp x9, %[count]
        \\ b.lo 1b
        :
        : [count] "r" (count),
        : .{ .x9 = true });
}
