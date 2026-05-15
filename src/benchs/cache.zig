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
        // read1KiB,
        // read128KiB,
        // read256KiB,
        // read512KiB,
        // read1Mib,
        // read2Mib,
        // read16Mib,
        // read1Gib,
        // read128KiB_ld1,
        // read256KiB_ld1,
        // read512KiB_ld1,
        // read1Mib_ld1,
        // read2Mib_ld1,
        // read16Mib_ld1,
        // read1Gib_ld1,
        read128KiB_loop_ldp,
        read256KiB_loop_ldp,
        read512KiB_loop_ldp,
        read1Mib_loop_ldp,
        read2Mib_loop_ldp,
        read16Mib_loop_ldp,
        read1Gib_loop_ldp,
        read128KiB_loop_ld1,
        read256KiB_loop_ld1,
        read512KiB_loop_ld1,
        read1Mib_loop_ld1,
        read2Mib_loop_ld1,
        read16Mib_loop_ld1,
        read1Gib_loop_ld1,
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

fn read128KiB_loop_ldp(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "read128KiB_loop_ldp" });
        defer ctx.zone.deinit(profiler);

        readBufferDoubleLDP(ctx.buffer, 128 * KiB);
    }
}

fn read256KiB_loop_ldp(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "read256KiB_loop_ldp" });
        defer ctx.zone.deinit(profiler);

        readBufferDoubleLDP(ctx.buffer, 256 * KiB);
    }
}

fn read512KiB_loop_ldp(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "read512KiB_loop_ldp" });
        defer ctx.zone.deinit(profiler);

        readBufferDoubleLDP(ctx.buffer, 512 * KiB);
    }
}

fn read1Mib_loop_ldp(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "read1Mib_loop_ldp" });
        defer ctx.zone.deinit(profiler);

        readBufferDoubleLDP(ctx.buffer, MiB);
    }
}

fn read2Mib_loop_ldp(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "read2Mib_loop_ldp" });
        defer ctx.zone.deinit(profiler);

        readBufferDoubleLDP(ctx.buffer, 2 * MiB);
    }
}

fn read16Mib_loop_ldp(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "read16Mib_loop_ldp" });
        defer ctx.zone.deinit(profiler);

        readBufferDoubleLDP(ctx.buffer, 16 * MiB);
    }
}

fn read1Gib_loop_ldp(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "read1Gib_loop_ldp" });
        defer ctx.zone.deinit(profiler);

        readBufferDoubleLDP(ctx.buffer, GiB);
    }
}

fn read128KiB_loop_ld1(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "read128KiB_loop_ld1" });
        defer ctx.zone.deinit(profiler);

        readBufferDoubleLD1(ctx.buffer, 128 * KiB);
    }
}

fn read256KiB_loop_ld1(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "read256KiB_loop_ld1" });
        defer ctx.zone.deinit(profiler);

        readBufferDoubleLD1(ctx.buffer, 256 * KiB);
    }
}

fn read512KiB_loop_ld1(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "read512KiB_loop_ld1" });
        defer ctx.zone.deinit(profiler);

        readBufferDoubleLD1(ctx.buffer, 512 * KiB);
    }
}

fn read1Mib_loop_ld1(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "read1Mib_loop_ld1" });
        defer ctx.zone.deinit(profiler);

        readBufferDoubleLD1(ctx.buffer, MiB);
    }
}

fn read2Mib_loop_ld1(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "read2Mib_loop_ld1" });
        defer ctx.zone.deinit(profiler);

        readBufferDoubleLD1(ctx.buffer, 2 * MiB);
    }
}

fn read16Mib_loop_ld1(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "read16Mib_loop_ld1" });
        defer ctx.zone.deinit(profiler);

        readBufferDoubleLD1(ctx.buffer, 16 * MiB);
    }
}

fn read1Gib_loop_ld1(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = ctx.buffer.len, .label = "read1Gib_loop_ld1" });
        defer ctx.zone.deinit(profiler);

        readBufferDoubleLD1(ctx.buffer, GiB);
    }
}

// Double-loop variant mirroring the x86 DoubleLoopRead_32x8 pattern but using
// 4× LDP q,q (128 B per inner iteration) instead of 8× vmovdqu.
//   outer = buffer.len / block_size  (re-read the same block this many times)
//   inner = block_size / 128         (4 LDPs cover 128 B per inner iter)
pub fn readBufferDoubleLDP(buffer: []u8, block_size: u64) void {
    var outer: u64 = buffer.len / block_size;
    const inner_init: u64 = block_size / 128;
    asm volatile (
        \\1:
        \\ mov x10, %[buffer]
        \\ mov x9, %[inner_init]
        \\2:
        \\ ldp q0, q1, [x10]
        \\ ldp q2, q3, [x10, #32]
        \\ ldp q4, q5, [x10, #64]
        \\ ldp q6, q7, [x10, #96]
        \\ add x10, x10, #128
        \\ subs x9, x9, #1
        \\ b.ne 2b
        \\ subs %[outer], %[outer], #1
        \\ b.ne 1b
        : [outer] "+r" (outer),
        : [buffer] "r" (buffer.ptr),
          [inner_init] "r" (inner_init),
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

// Double-loop variant using 4× LD1 (4-register, 64 B each = 256 B per inner
// iteration). LD1 multi-structure has no immediate-offset addressing form, so
// we use post-index #64 to walk the block.
//   outer = buffer.len / block_size
//   inner = block_size / 256
pub fn readBufferDoubleLD1(buffer: []u8, block_size: u64) void {
    var outer: u64 = buffer.len / block_size;
    const inner_init: u64 = block_size / 256;
    asm volatile (
        \\1:
        \\ mov x10, %[buffer]
        \\ mov x9, %[inner_init]
        \\2:
        \\ ld1 { v0.16b,  v1.16b,  v2.16b,  v3.16b  }, [x10], #64
        \\ ld1 { v4.16b,  v5.16b,  v6.16b,  v7.16b  }, [x10], #64
        \\ ld1 { v8.16b,  v9.16b,  v10.16b, v11.16b }, [x10], #64
        \\ ld1 { v12.16b, v13.16b, v14.16b, v15.16b }, [x10], #64
        \\ subs x9, x9, #1
        \\ b.ne 2b
        \\ subs %[outer], %[outer], #1
        \\ b.ne 1b
        : [outer] "+r" (outer),
        : [buffer] "r" (buffer.ptr),
          [inner_init] "r" (inner_init),
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
