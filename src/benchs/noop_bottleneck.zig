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

const Strategy = struct {
    label: []const u8,
    cb: *const fn (?*Context, *Profiler.Profiler) anyerror!void,
};

const strategies: []const Strategy = &.{
    .{
        .label = "noop",
        .cb = noop,
    },
    .{
        .label = "noop3bytes",
        .cb = noop3bytes,
    },
    .{
        .label = "noop9bytes",
        .cb = noop9bytes,
    },
    .{
        .label = "noop16bytes",
        .cb = noop16bytes,
    },
};

test "Bench Noop Bottlenecks" {
    const io = std.testing.io;
    const gpa = std.testing.allocator;

    var ctx: Context = .{
        .io = io,
        .alloc = gpa,
        .loop = 10000000,
    };

    var tester: Tester = undefined;
    for (strategies) |strategy| {
        tester = .empty;
        try tester.init(gpa, strategy.label, .{
            .min_runs = 3,
            .stop_after_no_new_min_ms = 10000,
            .max_runs = 100,
            .log_profiler = true,
        });
        defer tester.deinit(gpa);

        try tester.run(Context, &ctx, strategy.cb);
        tester.log();
    }
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
