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
        read_4x2, read_8x2, read_16x2, read_32x2, read_32x3,
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

// Read_32x2: two 32-byte loads per iteration -> 64 bytes / iter.
// AArch64 NEON has no 256-bit registers (no AVX/YMM equivalent without SVE),
// so each "32-byte load" is expressed as a paired 16-byte load: `ldp q0, q1, [...]`.
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
            \\ ldp q0, q1, [%[buffer], #32]
            \\ subs %[count], %[count], #64
            \\ b.hi 1b
            : [count] "+r" (count),
            : [buffer] "r" (ctx.buffer.ptr),
            : .{ .v0 = true, .v1 = true, .memory = true, .nzcv = true });
    }
}

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
            \\ ldp q0, q1, [%[buffer], #32]
            \\ ldp q0, q1, [%[buffer], #64]
            \\ subs %[count], %[count], #96
            \\ b.hi 1b
            : [count] "+r" (count),
            : [buffer] "r" (ctx.buffer.ptr),
            : .{ .v0 = true, .v1 = true, .memory = true, .nzcv = true });
    }
}

fn read_32x4(_ctx: ?*Context, profiler: *Profiler.Profiler) !void {
    if (_ctx) |ctx| {
        ctx.zone = .empty;
        ctx.zone.init(@src(), profiler, .{ .bytes = total_bytes, .label = "read_32x4" });
        defer ctx.zone.deinit(profiler);

        var count: usize = total_bytes;

        asm volatile (
            \\.balign 64
            \\1:
            \\ ldp q0, q1, [%[buffer]]
            \\ ldp q0, q1, [%[buffer], #32]
            \\ ldp q0, q1, [%[buffer], #64]
            \\ ldp q0, q1, [%[buffer], #96]
            \\ subs %[count], %[count], #128
            \\ b.hi 1b
            : [count] "+r" (count),
            : [buffer] "r" (ctx.buffer.ptr),
            : .{ .v0 = true, .v1 = true, .memory = true, .nzcv = true });
    }
}
