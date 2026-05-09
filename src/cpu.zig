//https://gist.github.com/bhb/7dc0df53a1a7b18ba04c786d76859c44
const std = @import("std");
const testing = std.testing;

const time = @cImport({
    @cInclude("sys/time.h");
});

pub const OsFreq = 1_000_000;

pub fn readOsTimer() u64 {
    var value = time.timeval{
        .tv_sec = 0, // Seconds
        .tv_usec = 0, // Microseconds
    };

    _ = time.gettimeofday(&value, null);

    return OsFreq * @as(u64, @bitCast(value.tv_sec)) + @as(u32, @bitCast(value.tv_usec));
}

pub fn readCpuFreq() u64 {
    var val: u64 = undefined;

    asm volatile ("mrs %[val], cntfrq_el0"
        : [val] "=r" (val),
    );

    return val;
}

pub fn readCpuTimer() u64 {
    var val: u64 = undefined;

    asm volatile ("mrs %[val], cntvct_el0"
        : [val] "=r" (val),
    );

    return val;
}

pub fn guessCpuFreq(milliseconds_to_wait: u64) void {
    const os_freq = OsFreq;
    std.debug.print("    OS Freq: {} (reported)\n", .{os_freq});

    const cpu_start: u64 = readCpuTimer();
    const os_start: u64 = readOsTimer();
    var os_end: u64 = 0;
    var os_elapsed: u64 = 0;
    const os_wait_time: u64 = os_freq * milliseconds_to_wait / 1000;

    while (os_elapsed < os_wait_time) {
        os_end = readOsTimer();
        os_elapsed = os_end - os_start;
    }

    const cpu_end: u64 = readCpuTimer();
    const cpu_elapsed: u64 = cpu_end - cpu_start;
    var cpu_freq: u64 = 0;
    if (os_elapsed != 0) {
        cpu_freq = os_freq * cpu_elapsed / os_elapsed;
    }

    std.debug.print("   OS Timer: {} -> {} = {} elapsed\n", .{ os_start, os_end, os_elapsed });
    std.debug.print(" OS Seconds: {d:.4}\n", .{@as(f64, @floatFromInt(os_elapsed)) / @as(f64, @floatFromInt(os_freq))});

    std.debug.print("  CPU Timer: {} -> {} = {} elapsed\n", .{ cpu_start, cpu_end, cpu_elapsed });
    std.debug.print("   CPU Freq: {} (guessed)\n", .{cpu_freq});
}

test "guess cpu freq" {
    guessCpuFreq(1000);
    guessCpuFreq(100);
    guessCpuFreq(10);
}

test "os timer" {
    std.log.debug("OS Freq: {}", .{OsFreq});

    const OSStart = readOsTimer();
    var OSEnd: u64 = 0;
    var OSElapsed: u64 = 0;

    while (OSElapsed < OsFreq) {
        OSEnd = readOsTimer();
        OSElapsed = OSEnd - OSStart;
    }

    std.log.debug("OS Timer:{} -> {} = {} elapsed", .{ OSStart, OSEnd, OSElapsed });
    std.log.debug("OS Seconds: {}", .{@as(f64, @floatFromInt(OSElapsed)) / @as(f64, @floatFromInt(OsFreq))});
}

test "cpu timer" {
    testing.log_level = .debug;
    const CpuFreq = readCpuFreq();
    std.log.debug("OS Freq: {}", .{OsFreq});
    std.log.debug("CPU Freq: {}", .{CpuFreq});

    const CPUStart: u64 = readCpuTimer();
    const OSStart = readOsTimer();
    var OSEnd: u64 = 0;
    var OSElapsed: u64 = 0;

    while (OSElapsed < OsFreq) {
        OSEnd = readOsTimer();
        OSElapsed = OSEnd - OSStart;
    }

    const CPUEnd: u64 = readCpuTimer();
    const CPUElapsed: u64 = CPUEnd - CPUStart;

    std.log.debug("OS Timer: {} -> {} = {} elapsed", .{ OSStart, OSEnd, OSElapsed });
    std.log.debug("OS Seconds: {d}", .{@as(f64, @floatFromInt(OSElapsed)) / @as(f64, @floatFromInt(OsFreq))});
    std.log.debug("CPU Timer: {} -> {} = {} elapsed", .{ CPUStart, CPUEnd, CPUElapsed });
    std.log.debug("CPU Seconds: {d}", .{@as(f64, @floatFromInt(CPUElapsed)) / @as(f64, @floatFromInt(CpuFreq))});
}
