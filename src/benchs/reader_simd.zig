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

// Original x86 reference (for documentation):
//
// Read_4x2:
//     xor rax, rax
//     align 64
// .loop:
//     mov r8d, [rdx ]
//     mov r8d, [rdx + 4]
//     add rax, 8
//     cmp rax, rcx
//     jb .loop
//     ret
//
// Read_8x2:
//     xor rax, rax
//     align 64
// .loop:
//     mov r8, [rdx ]
//     mov r8, [rdx + 8]
//     add rax, 16
//     cmp rax, rcx
//     jb .loop
//     ret
//
// Read_16x2:
//     xor rax, rax
//     align 64
// .loop:
//     vmovdqu xmm0, [rdx]
//     vmovdqu xmm0, [rdx + 16]
//     add rax, 32
//     cmp rax, rcx
//     jb .loop
//     ret
//
// Read_32x2:
//     xor rax, rax
//     align 64
// .loop:
//     vmovdqu ymm0, [rdx]
//     vmovdqu ymm0, [rdx + 32]
//     add rax, 64
//     cmp rax, rcx
//     jb .loop
//     ret

test "Bench Reader SIMD (L1 hit)" {
    const io = std.testing.io;
    const gpa = std.testing.allocator;

    // Small buffer that fits comfortably in L1 (Apple Silicon L1d is 128 KiB / core).
    const buffer = try gpa.alloc(u8, 4 * KiB);
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
        read_4x2,  read_8x2,   read_16x2,  read_32x2,
        read_32x3, read_ld4x2, read_ld4x3,
    });
}

// Total bytes "read" per benchmark run. We always hit the same address so
// everything stays resident in L1, but we account for bandwidth as if we had
// streamed `total_bytes` from memory.
const total_bytes: usize = 1 * 1024 * 1024 * 1024; // 1 GiB

// Read_4x2: two 4-byte loads per iteration -> 8 bytes / iter.
fn read_4x2(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = total_bytes, .label = "read_4x2" });
        defer ctx.zone.deinit(profiler);

        var count: usize = total_bytes;

        asm volatile (
            \\.balign 64
            \\1:
            \\ ldr w9, [%[buffer]]
            \\ ldr w9, [%[buffer], #4]
            \\ subs %[count], %[count], #8
            \\ b.hi 1b
            : [count] "+r" (count),
            : [buffer] "r" (ctx.buffer.ptr),
            : .{ .x9 = true, .memory = true, .nzcv = true });
    }
}

// Read_8x2: two 8-byte loads per iteration -> 16 bytes / iter.
fn read_8x2(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = total_bytes, .label = "read_8x2" });
        defer ctx.zone.deinit(profiler);

        var count: usize = total_bytes;

        asm volatile (
            \\.balign 64
            \\1:
            \\ ldr x9, [%[buffer]]
            \\ ldr x9, [%[buffer], #8]
            \\ subs %[count], %[count], #16
            \\ b.hi 1b
            : [count] "+r" (count),
            : [buffer] "r" (ctx.buffer.ptr),
            : .{ .x9 = true, .memory = true, .nzcv = true });
    }
}

// Read_16x2: two 16-byte (NEON Q-register) loads per iteration -> 32 bytes / iter.
// ARM64 equivalent of `vmovdqu xmm0, [...]` is `ldr q0, [...]`.
fn read_16x2(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = total_bytes, .label = "read_16x2" });
        defer ctx.zone.deinit(profiler);

        var count: usize = total_bytes;

        asm volatile (
            \\.balign 64
            \\1:
            \\ ldr q0, [%[buffer]]
            \\ ldr q0, [%[buffer], #16]
            \\ subs %[count], %[count], #32
            \\ b.hi 1b
            : [count] "+r" (count),
            : [buffer] "r" (ctx.buffer.ptr),
            : .{ .v0 = true, .memory = true, .nzcv = true });
    }
}

fn read_32x2(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = total_bytes, .label = "read_32x2" });
        defer ctx.zone.deinit(profiler);

        var count: usize = total_bytes;

        asm volatile (
            \\.balign 64
            \\1:
            \\ ldp q0, q1, [%[buffer]]
            \\ ldp q2, q3, [%[buffer], #32]
            \\ subs %[count], %[count], #64
            \\ b.hi 1b
            : [count] "+r" (count),
            : [buffer] "r" (ctx.buffer.ptr),
            : .{ .v0 = true, .v1 = true, .v2 = true, .v3 = true, .memory = true, .nzcv = true });
    }
}

// Read_32x3: three 32-byte loads per iteration -> 96 bytes / iter.
fn read_32x3(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = total_bytes, .label = "read_32x3" });
        defer ctx.zone.deinit(profiler);

        var count: usize = total_bytes;

        asm volatile (
            \\.balign 64
            \\1:
            \\ ldp q0, q1, [%[buffer]]
            \\ ldp q2, q3, [%[buffer], #32]
            \\ ldp q4, q5, [%[buffer], #64]
            \\ subs %[count], %[count], #96
            \\ b.hi 1b
            : [count] "+r" (count),
            : [buffer] "r" (ctx.buffer.ptr),
            : .{
              .v0 = true,
              .v1 = true,
              .v2 = true,
              .v3 = true,
              .v4 = true,
              .v5 = true,
              .memory = true,
              .nzcv = true,
            });
    }
}

// Read_ld4x2: two `ld4` 4-register de-interleaving loads per iteration.
// Each `ld4 {v0.2d-v3.2d}, [x]` loads 4 Q registers = 64 bytes in a single
// instruction, so two of them = 128 bytes / iter (same total as read_32x4
// but with only 2 load instructions issued).
fn read_ld4x2(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = total_bytes, .label = "read_ld4x2" });
        defer ctx.zone.deinit(profiler);

        var count: usize = total_bytes;

        asm volatile (
            \\.balign 64
            \\1:
            \\ ld4 {v0.2d, v1.2d, v2.2d, v3.2d}, [%[buffer]]
            \\ ld4 {v4.2d, v5.2d, v6.2d, v7.2d}, [%[buffer]]
            \\ subs %[count], %[count], #128
            \\ b.hi 1b
            : [count] "+r" (count),
            : [buffer] "r" (ctx.buffer.ptr),
            : .{
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
}

// Read_ld4x3: three `ld4` 4-register de-interleaving loads per iteration.
// 3 * 64 = 192 bytes / iter.
fn read_ld4x3(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = total_bytes, .label = "read_ld4x3" });
        defer ctx.zone.deinit(profiler);

        var count: usize = total_bytes;

        asm volatile (
            \\.balign 64
            \\1:
            \\ ld4 {v0.2d,  v1.2d,  v2.2d,  v3.2d},  [%[buffer]]
            \\ ld4 {v4.2d,  v5.2d,  v6.2d,  v7.2d},  [%[buffer]]
            \\ ld4 {v8.2d,  v9.2d,  v10.2d, v11.2d}, [%[buffer]]
            \\ subs %[count], %[count], #192
            \\ b.hi 1b
            : [count] "+r" (count),
            : [buffer] "r" (ctx.buffer.ptr),
            : .{
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
              .memory = true,
              .nzcv = true,
            });
    }
}
