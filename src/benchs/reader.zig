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
    zone: Profiler.Zone,
};

test "Bench Reads" {
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
        writeBuffer,
        moveAllBytes,
        noopAllBytes,
        cmpAllBytes,
        decAllBytes,
    });
}

fn writeBuffer(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{
            .bytes = ctx.file_size,
            .label = "writeIntoBuffer",
            .flags = .{ .page_faults = true },
        });
        defer ctx.zone.deinit(profiler);

        const data = try ctx.alloc.alloc(u8, ctx.file_size);
        defer ctx.alloc.free(data);

        for (0..data.len) |idx| {
            data[idx] = @truncate(idx);
        }
    }
}

fn moveAllBytes(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{
            .bytes = ctx.file_size,
            .label = "moveAllBytes",
            .flags = .{ .page_faults = true },
        });
        defer ctx.zone.deinit(profiler);

        const data = try ctx.alloc.alloc(u8, ctx.file_size);
        defer ctx.alloc.free(data);

        moveAllBytesAsm(ctx.file_size, @ptrCast(data));
    }
}

fn noopAllBytes(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{
            .label = "noopAllBytes",
            .bytes = ctx.file_size,
        });
        defer ctx.zone.deinit(profiler);

        noopAllBytesAsm(ctx.file_size);
    }
}

fn cmpAllBytes(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{
            .label = "cmpAllBytes",
            .bytes = ctx.file_size,
        });
        defer ctx.zone.deinit(profiler);

        cmpAllBytesAsm(ctx.file_size);
    }
}

fn decAllBytes(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{
            .label = "decAllBytes",
            .bytes = ctx.file_size,
        });
        defer ctx.zone.deinit(profiler);

        decAllBytesAsm(ctx.file_size);
    }
}

fn moveAllBytesAsm(count: u64, data: *anyopaque) void {
    asm volatile (
        \\ eor x9, x9, x9
        \\1:
        \\ strb w9, [%[data], x9]
        \\ add x9, x9, #1
        \\ cmp x9, %[count]
        \\ b.lo 1b
        :
        : [count] "r" (count),
          [data] "r" (data),
        : .{ .x9 = true, .memory = true });
}

fn noopAllBytesAsm(count: u64) void {
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

fn cmpAllBytesAsm(count: u64) void {
    asm volatile (
        \\ eor x9, x9, x9
        \\1:
        \\ add x9, x9, #1
        \\ cmp x9, %[count]
        \\ b.lo 1b
        :
        : [count] "r" (count),
        : .{ .x9 = true });
}

fn decAllBytesAsm(count: u64) void {
    asm volatile (
        \\1:
        \\ sub %[count], %[count], #1
        \\ cbnz %[count], 1b
        :
        : [count] "r" (count),
        : .{ .x9 = true });
}
