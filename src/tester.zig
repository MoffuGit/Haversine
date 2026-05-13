const std = @import("std");
const Allocator = std.mem.Allocator;
const builtin = std.builtin;
const target = @import("builtin");
const printpkg = @import("print.zig");
const print = std.debug.print;

const cpu = @import("cpu.zig");
const profilerpkg = @import("profiler.zig");
const Profiler = profilerpkg.Profiler;
const Anchor = profilerpkg.Anchor;

const Tester = @This();

const max_default = 1024;

pub const Config = struct {
    /// Minimum number of iterations before the stale-min stop criterion is checked.
    min_runs: u64 = 8,
    /// Optional hard cap on the number of iterations.
    max_runs: ?u64 = null,
    /// Stop once no new total-elapsed minimum has been observed for this many milliseconds.
    stop_after_no_new_min_ms: f64 = 2_000.0,
};

const Run = struct { profiler: Profiler = .empty, fail: bool = false };

label: []const u8,
config: Config,

offset: u64,
runs: []Run,

start: u64,
end: u64,

min: u64,
min_tick: u64,
min_offset: usize,

pub const empty: Tester = .{
    .label = "",
    .config = .{},
    .offset = 0,
    .start = 0,
    .end = 0,
    .runs = &.{},
    .min = std.math.maxInt(u64),
    .min_tick = 0,
    .min_offset = 0,
};

pub fn init(self: *Tester, alloc: Allocator, label: []const u8, config: Config) !void {
    const capacity = config.max_runs orelse max_default;
    self.runs = try alloc.alloc(Run, capacity);
    self.label = label;
    self.config = config;
    self.start = cpu.readCpuTimer();
}

pub fn deinit(self: *Tester, alloc: Allocator) void {
    self.end = cpu.readCpuTimer();
    alloc.free(self.runs);
    self.runs = &.{};
}

pub fn run(
    self: *Tester,
    comptime Context: type,
    ctx: ?*Context,
    callback: *const fn (ctx: ?*Context, profiler: *Profiler) anyerror!void,
) !void {
    self.min_tick = cpu.readCpuTimer();
    const timer_freq = cpu.readTimerFreq();
    while (self.offset < self.runs.len) : (self.offset += 1) {
        const r = &self.runs[self.offset];
        const profiler = &r.profiler;
        {
            profiler.init("TEST PROFILER");
            defer profiler.deinit();

            callback(ctx, profiler) catch {
                r.fail = true;
            };
        }
        const total = profiler.end - profiler.start;

        if (total < self.min) {
            self.min = total;
            self.min_offset = self.offset;
            self.min_tick = profiler.end;
        }
        if (self.offset < self.config.min_runs) continue;

        const last_min = 1000.0 * @as(f64, @floatFromInt(profiler.end - self.min_tick)) / @as(f64, @floatFromInt(timer_freq));

        if (last_min >= self.config.stop_after_no_new_min_ms) break;
    }
}

pub fn log(self: *const Tester) void {
    const timer_freq = cpu.readTimerFreq();

    const completed: u64 = @min(self.offset + 1, self.runs.len);

    var min_total: u64 = std.math.maxInt(u64);
    var max_total: u64 = 0;
    var sum_total: u128 = 0;
    var fails: u64 = 0;
    var ok_runs: u64 = 0;

    var i: u64 = 0;
    while (i < completed) : (i += 1) {
        const r = &self.runs[i];
        if (r.fail) {
            fails += 1;
            continue;
        }
        const total = r.profiler.end - r.profiler.start;
        if (total < min_total) min_total = total;
        if (total > max_total) max_total = total;
        sum_total += total;
        ok_runs += 1;
    }

    const freq_f = @as(f64, @floatFromInt(timer_freq));
    const min_ms: f64 = if (ok_runs == 0) 0 else 1000.0 * @as(f64, @floatFromInt(min_total)) / freq_f;
    const max_ms: f64 = if (ok_runs == 0) 0 else 1000.0 * @as(f64, @floatFromInt(max_total)) / freq_f;
    const avg_ms: f64 = if (ok_runs == 0) 0 else 1000.0 * (@as(f64, @floatFromInt(sum_total)) / @as(f64, @floatFromInt(ok_runs))) / freq_f;

    var sys_buf: [256]u8 = undefined;
    const cpu_count = std.Thread.getCpuCount() catch 0;
    const sys_info = std.fmt.bufPrint(&sys_buf, " OS: {s} | Arch: {s} | CPU: {s} ({d} cores) ", .{
        @tagName(target.os.tag),
        @tagName(target.cpu.arch),
        target.cpu.model.name,
        cpu_count,
    }) catch &.{};

    var label_buf: [256]u8 = undefined;
    const label_info = std.fmt.bufPrint(&label_buf, " {s} | runs: {d} | fails: {d} | Timer freq: {d} ", .{
        self.label,
        completed,
        fails,
        timer_freq,
    }) catch &.{};

    var stats_buf: [256]u8 = undefined;
    const stats_info = std.fmt.bufPrint(&stats_buf, " min: {d:.4}ms | max: {d:.4}ms | avg: {d:.4}ms ", .{
        min_ms, max_ms, avg_ms,
    }) catch &.{};

    print("\n", .{});
    printpkg.printResult(&.{ sys_info, label_info, stats_info }, &.{});
}
