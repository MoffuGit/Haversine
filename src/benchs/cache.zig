const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const Profiler = @import("../profiler.zig");
const Tester = @import("../tester.zig");

const KiB = 1024;
const MiB = 1024 * KiB;
const GiB = 1024 * MiB;

const BufferSize: usize = 1 * GiB;

const Context = struct {
    io: std.Io,
    alloc: Allocator,
    buffer: []u8,
    zone: Profiler.Zone,
};

test "Bench Reader Cache" {
    const io = std.testing.io;
    const gpa = std.testing.allocator;

    const buffer = try gpa.alloc(u8, BufferSize);
    defer gpa.free(buffer);

    for (0..buffer.len) |idx| {
        buffer[idx] = 1;
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
        read1KiB,
        read128KiB,
        read256KiB,
        read512KiB,
        read1Mib,
        read2Mib,
        // read16Mib,
        // read1Gib,
        // read128KiB_ld1,
        // read256KiB_ld1,
        // read512KiB_ld1,
        // read1Mib_ld1,
        // read2Mib_ld1,
        // read16Mib_ld1,
        // read1Gib_ld1,
        // read1Gibxld1,
    });
}

fn read1KiB(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "read128KiB" });
        defer ctx.zone.deinit(profiler);

        readBuffer(ctx.buffer, KiB - 1);
    }
}

fn read128KiB(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "read128KiB" });
        defer ctx.zone.deinit(profiler);

        // 128 KiB window -> mask = 128*1024 - 1 = 0x1FFFF.
        readBuffer(ctx.buffer, 128 * KiB - 1);
    }
}

fn read256KiB(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "read256KiB" });
        defer ctx.zone.deinit(profiler);

        readBuffer(ctx.buffer, 2 * (128 * KiB) - 1);
    }
}

fn read512KiB(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "read512KiB" });
        defer ctx.zone.deinit(profiler);

        readBuffer(ctx.buffer, 4 * (128 * KiB) - 1);
    }
}

fn read1Mib(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "read1Mib" });
        defer ctx.zone.deinit(profiler);

        readBuffer(ctx.buffer, MiB - 1);
    }
}

fn read2Mib(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "read2Mib" });
        defer ctx.zone.deinit(profiler);

        readBuffer(ctx.buffer, 2 * MiB - 1);
    }
}

fn read16Mib(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "read16Mib" });
        defer ctx.zone.deinit(profiler);

        readBuffer(ctx.buffer, 16 * MiB - 1);
    }
}

fn read1Gib(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "read1Gib" });
        defer ctx.zone.deinit(profiler);

        readBuffer(ctx.buffer, GiB - 1);
    }
}

pub fn readBuffer(buffer: []u8, mask: u64) void {
    var count: usize = buffer.len;
    asm volatile (
        \\ eor x9, x9, x9
        \\ mov x10, %[buffer]
        \\.balign 64
        \\1:
        \\ ldp q0, q1, [x10]
        \\ ldp q2, q3, [x10, #32]
        \\ ldp q4, q5, [x10, #64]
        \\ ldp q6, q7, [x10, #96]
        \\ add x9, x9, #128
        \\ and x9, x9, %[mask]
        \\ add x10, %[buffer], x9
        \\ subs %[count], %[count], #128
        \\ b.hi 1b
        : [count] "+r" (count),
        : [buffer] "r" (buffer.ptr),
          [mask] "r" (mask),
        : .{
          .x9 = true,
          .x10 = true,
          .v0 = true,
          .v1 = true,
          .v2 = true,
          .v3 = true,
          .v4 = true,
          .v5 = true,
          .v6 = true,
          .v7 = true,
          .memory = true,
          .nzcv = true,
        });
}

fn read128KiB_ld1(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "read128KiB_ld1" });
        defer ctx.zone.deinit(profiler);

        readBufferLd1(ctx.buffer, 128 * KiB - 1);
    }
}

fn read256KiB_ld1(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "read256KiB_ld1" });
        defer ctx.zone.deinit(profiler);

        readBufferLd1(ctx.buffer, 2 * (128 * KiB) - 1);
    }
}

fn read512KiB_ld1(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "read512KiB_ld1" });
        defer ctx.zone.deinit(profiler);

        readBufferLd1(ctx.buffer, 4 * (128 * KiB) - 1);
    }
}

fn read1Mib_ld1(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "read1Mib_ld1" });
        defer ctx.zone.deinit(profiler);

        readBufferLd1(ctx.buffer, MiB - 1);
    }
}

fn read2Mib_ld1(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "read2Mib_ld1" });
        defer ctx.zone.deinit(profiler);

        readBufferLd1(ctx.buffer, 2 * MiB - 1);
    }
}

fn read16Mib_ld1(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "read16Mib_ld1" });
        defer ctx.zone.deinit(profiler);

        readBufferLd1(ctx.buffer, 16 * MiB - 1);
    }
}

fn read1Gib_ld1(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "read1Gib_ld1" });
        defer ctx.zone.deinit(profiler);

        readBufferLd1(ctx.buffer, GiB - 1);
    }
}
fn read1Gibxld1(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "read1Gib_ld1" });
        defer ctx.zone.deinit(profiler);

        readBufferxLd1(ctx.buffer, GiB - 1);
    }
}

pub fn readBufferxLd1(buffer: []u8, mask: u64) void {
    var count: usize = buffer.len;
    asm volatile (
        \\ eor x9, x9, x9
        \\ mov x10, %[buffer]
        \\1:
        \\ ld1 { v0.16b,  v1.16b,  v2.16b,  v3.16b  }, [x10], #64
        \\ add x9, x9, #128
        \\ and x9, x9, %[mask]
        \\ add x10, %[buffer], x9
        \\ subs %[count], %[count], #128
        \\ b.hi 1b
        : [count] "+r" (count),
        : [buffer] "r" (buffer.ptr),
          [mask] "r" (mask),
        : .{
          .x9 = true,
          .x10 = true,
          .v0 = true,
          .v1 = true,
          .v2 = true,
          .v3 = true,
          .v4 = true,
          .v5 = true,
          .v6 = true,
          .v7 = true,
          .memory = true,
          .nzcv = true,
        });
}

pub fn readBufferLd1(buffer: []u8, mask: u64) void {
    var count: usize = buffer.len;
    asm volatile (
        \\ eor x9, x9, x9
        \\ mov x10, %[buffer]
        \\1:
        \\ ld1 { v0.16b,  v1.16b,  v2.16b,  v3.16b  }, [x10], #64
        \\ ld1 { v4.16b,  v5.16b,  v6.16b,  v7.16b  }, [x10], #64
        \\ ld1 { v8.16b,  v9.16b,  v10.16b, v11.16b }, [x10], #64
        \\ ld1 { v12.16b, v13.16b, v14.16b, v15.16b }, [x10], #64
        \\ add x9, x9, #256
        \\ and x9, x9, %[mask]
        \\ add x10, %[buffer], x9
        \\ subs %[count], %[count], #256
        \\ b.hi 1b
        : [count] "+r" (count),
        : [buffer] "r" (buffer.ptr),
          [mask] "r" (mask),
        : .{
          .x9 = true,
          .x10 = true,
          .v0 = true,
          .v1 = true,
          .v2 = true,
          .v3 = true,
          .v4 = true,
          .v5 = true,
          .v6 = true,
          .v7 = true,
          .v8 = true,
          .v9 = true,
          .v10 = true,
          .v11 = true,
          .v12 = true,
          .v13 = true,
          .v14 = true,
          .v15 = true,
          .memory = true,
          .nzcv = true,
        });
}
