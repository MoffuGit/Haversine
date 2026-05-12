const std = @import("std");
const builtin = std.builtin;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const cpu = @import("cpu.zig");
const profiler_mod = @import("profiler.zig");
const Profiler = profiler_mod.Profiler;
const Anchor = profiler_mod.Anchor;

const Tester = @This();

pub const Config = struct {
    /// Minimum number of iterations before the stale-min stop criterion is checked.
    min_runs: u64 = 8,
    /// Optional hard cap on the number of iterations.
    max_runs: ?u64 = null,
    /// Stop once no new total-elapsed minimum has been observed for this many milliseconds.
    stop_after_no_new_min_ms: u64 = 2_000,
};

pub const TotalStats = struct {
    min: u64 = std.math.maxInt(u64),
    max: u64 = 0,
    sum: u128 = 0,
};

pub const AggAnchor = struct {
    parent: ?u32,
    first_child: ?u32,
    next_sibling: ?u32,

    src: builtin.SourceLocation,
    label: []const u8,

    /// Number of runs in which this anchor appeared (hits > 0).
    run_count: u64,

    hits_per_run_min: u64,
    hits_per_run_max: u64,
    hits_per_run_sum: u128,

    exclusive_min: u64,
    exclusive_max: u64,
    exclusive_sum: u128,

    inclusive_min: u64,
    inclusive_max: u64,
    inclusive_sum: u128,

    bytes_min: u64,
    bytes_max: u64,
    bytes_sum: u128,

    gbps_min: f64,
    gbps_max: f64,
    gbps_seen: bool,

    pub const empty: AggAnchor = .{
        .parent = null,
        .first_child = null,
        .next_sibling = null,
        .src = undefined,
        .label = "",
        .run_count = 0,

        .hits_per_run_min = std.math.maxInt(u64),
        .hits_per_run_max = 0,
        .hits_per_run_sum = 0,

        .exclusive_min = std.math.maxInt(u64),
        .exclusive_max = 0,
        .exclusive_sum = 0,

        .inclusive_min = std.math.maxInt(u64),
        .inclusive_max = 0,
        .inclusive_sum = 0,

        .bytes_min = std.math.maxInt(u64),
        .bytes_max = 0,
        .bytes_sum = 0,

        .gbps_min = std.math.inf(f64),
        .gbps_max = 0.0,
        .gbps_seen = false,
    };
};

alloc: Allocator,
config: Config,
cpu_freq: u64,

profiler: Profiler,

anchors: ArrayList(AggAnchor),
root_first_child: ?u32,

run_count: u64,
total: TotalStats,

best_total_elapsed: u64,
last_min_tick: u64,

pub const empty: Tester = .{
    .alloc = undefined,
    .config = .{},
    .cpu_freq = 0,
    .profiler = .empty,
    .anchors = .empty,
    .root_first_child = null,
    .run_count = 0,
    .total = .{},
    .best_total_elapsed = std.math.maxInt(u64),
    .last_min_tick = 0,
};

pub fn init(self: *Tester, alloc: Allocator, config: Config) void {
    self.* = .{
        .alloc = alloc,
        .config = config,
        .cpu_freq = cpu.readCpuFreq(),
        .profiler = .empty,
        .anchors = .empty,
        .root_first_child = null,
        .run_count = 0,
        .total = .{},
        .best_total_elapsed = std.math.maxInt(u64),
        .last_min_tick = 0,
    };
}

pub fn deinit(self: *Tester) void {
    self.anchors.deinit(self.alloc);
}

/// Repeatedly invoke `callback(ctx, &tester.profiler)` until the stop criterion is met.
/// Each iteration starts with a fresh profiler. Per-anchor stats are folded into the
/// tester's aggregated tree.
pub fn run(
    self: *Tester,
    comptime Context: type,
    ctx: *Context,
    callback: *const fn (ctx: *Context, profiler: *Profiler) anyerror!void,
) !void {
    const stale_ticks = (self.config.stop_after_no_new_min_ms * self.cpu_freq) / 1000;
    self.last_min_tick = cpu.readCpuTimer();

    while (true) {
        self.profiler = .empty;
        self.profiler.init();

        const cb_result = callback(ctx, &self.profiler);
        self.profiler.deinit();
        try cb_result;

        try self.register(&self.profiler);

        const total_elapsed = self.profiler.end - self.profiler.start;
        if (total_elapsed < self.best_total_elapsed) {
            self.best_total_elapsed = total_elapsed;
            self.last_min_tick = self.profiler.end;
        }

        if (self.run_count < self.config.min_runs) continue;
        if (self.config.max_runs) |max_runs| {
            if (self.run_count >= max_runs) break;
        }
        if (self.profiler.end - self.last_min_tick >= stale_ticks) break;
    }
}

fn pushU64(min: *u64, max: *u64, sum: *u128, value: u64) void {
    if (value < min.*) min.* = value;
    if (value > max.*) max.* = value;
    sum.* += value;
}

fn register(self: *Tester, run_profiler: *const Profiler) !void {
    const total_elapsed = run_profiler.end - run_profiler.start;
    pushU64(&self.total.min, &self.total.max, &self.total.sum, total_elapsed);
    self.run_count += 1;

    if (comptime !profiler_mod.enabled) return;

    try self.registerChildren(run_profiler, null, run_profiler.root_first_child);
}

fn registerChildren(
    self: *Tester,
    run_profiler: *const Profiler,
    parent_agg_idx: ?u32,
    run_child_idx: ?u32,
) !void {
    if (comptime !profiler_mod.enabled) return;

    var cur = run_child_idx;
    while (cur) |run_idx| : (cur = run_profiler.anchors[run_idx].next_sibling) {
        const run_anchor = &run_profiler.anchors[run_idx];
        if (run_anchor.hits == 0) continue;

        const agg_idx = try self.findOrCreateAggAnchor(parent_agg_idx, run_anchor);
        const agg = &self.anchors.items[agg_idx];

        agg.run_count += 1;
        pushU64(&agg.hits_per_run_min, &agg.hits_per_run_max, &agg.hits_per_run_sum, run_anchor.hits);
        pushU64(&agg.exclusive_min, &agg.exclusive_max, &agg.exclusive_sum, run_anchor.elapsed_exclusive);
        pushU64(&agg.inclusive_min, &agg.inclusive_max, &agg.inclusive_sum, run_anchor.elapsed_inclusive);
        pushU64(&agg.bytes_min, &agg.bytes_max, &agg.bytes_sum, run_anchor.bytes);

        if (run_anchor.bytes > 0 and run_anchor.elapsed_inclusive > 0) {
            const gigabyte: f64 = 1024.0 * 1024.0 * 1024.0;
            const gb = @as(f64, @floatFromInt(run_anchor.bytes)) / gigabyte;
            const seconds = @as(f64, @floatFromInt(run_anchor.elapsed_inclusive)) / @as(f64, @floatFromInt(self.cpu_freq));
            const gbps = gb / seconds;

            if (!agg.gbps_seen) {
                agg.gbps_min = gbps;
                agg.gbps_max = gbps;
                agg.gbps_seen = true;
            } else {
                if (gbps < agg.gbps_min) agg.gbps_min = gbps;
                if (gbps > agg.gbps_max) agg.gbps_max = gbps;
            }
        }

        try self.registerChildren(run_profiler, agg_idx, run_anchor.first_child);
    }
}

fn findOrCreateAggAnchor(
    self: *Tester,
    parent_agg_idx: ?u32,
    run_anchor: *const Anchor,
) !u32 {
    const first_child_slot = if (parent_agg_idx) |p|
        &self.anchors.items[p].first_child
    else
        &self.root_first_child;

    var cur = first_child_slot.*;
    while (cur) |agg_idx| : (cur = self.anchors.items[agg_idx].next_sibling) {
        const agg = &self.anchors.items[agg_idx];
        if (profiler_mod.sameSrc(agg.src, run_anchor.src)) {
            std.debug.assert(std.mem.eql(u8, agg.label, run_anchor.label));
            return agg_idx;
        }
    }

    const new_idx: u32 = @intCast(self.anchors.items.len);
    var entry: AggAnchor = .empty;
    entry.parent = parent_agg_idx;
    entry.src = run_anchor.src;
    entry.label = run_anchor.label;
    try self.anchors.append(self.alloc, entry);

    // Append to tail so log order matches "first seen" order.
    if (first_child_slot.* == null) {
        first_child_slot.* = new_idx;
    } else {
        var tail = first_child_slot.*.?;
        while (self.anchors.items[tail].next_sibling) |next| {
            tail = next;
        }
        self.anchors.items[tail].next_sibling = new_idx;
    }

    return new_idx;
}

pub fn log(self: *const Tester) void {
    if (self.run_count == 0) {
        std.log.info("Tester | no runs recorded", .{});
        return;
    }

    const cpu_freq_f: f64 = @floatFromInt(self.cpu_freq);
    const runs_f: f64 = @floatFromInt(self.run_count);

    const total_min_ms = 1000.0 * @as(f64, @floatFromInt(self.total.min)) / cpu_freq_f;
    const total_max_ms = 1000.0 * @as(f64, @floatFromInt(self.total.max)) / cpu_freq_f;
    const total_avg_ms = 1000.0 * (@as(f64, @floatFromInt(self.total.sum)) / runs_f) / cpu_freq_f;

    std.log.info(
        "runs:{d} | min:{d:.4}ms avg:{d:.4}ms max:{d:.4}ms (CPU freq {d})",
        .{ self.run_count, total_min_ms, total_avg_ms, total_max_ms, self.cpu_freq },
    );

    if (comptime !profiler_mod.enabled) {
        std.log.info("  Profiler disabled; per-anchor stats unavailable.", .{});
        return;
    }

    self.logChildren(self.root_first_child, 0);
}

fn logChildren(self: *const Tester, child_idx: ?u32, depth: usize) void {
    if (comptime !profiler_mod.enabled) return;

    const cpu_freq_f: f64 = @floatFromInt(self.cpu_freq);

    var indent_buf: [profiler_mod.max_depth * 4]u8 = @splat(' ');

    var cur = child_idx;
    while (cur) |idx| : (cur = self.anchors.items[idx].next_sibling) {
        const agg = &self.anchors.items[idx];
        const indent_len = depth * 4;
        const indent = indent_buf[0..indent_len];

        const seen_f: f64 = @floatFromInt(agg.run_count);

        const excl_min_ms = 1000.0 * @as(f64, @floatFromInt(agg.exclusive_min)) / cpu_freq_f;
        const excl_max_ms = 1000.0 * @as(f64, @floatFromInt(agg.exclusive_max)) / cpu_freq_f;
        const excl_avg_ms = 1000.0 * (@as(f64, @floatFromInt(agg.exclusive_sum)) / seen_f) / cpu_freq_f;

        const incl_min_ms = 1000.0 * @as(f64, @floatFromInt(agg.inclusive_min)) / cpu_freq_f;
        const incl_max_ms = 1000.0 * @as(f64, @floatFromInt(agg.inclusive_max)) / cpu_freq_f;
        const incl_avg_ms = 1000.0 * (@as(f64, @floatFromInt(agg.inclusive_sum)) / seen_f) / cpu_freq_f;

        std.log.info(
            "{s}{s} | seen {d}/{d} | {s}:{d} \n{s}      |excl min/avg/max {d:.4}/{d:.4}/{d:.4}ms\n{s}      |incl min/avg/max {d:.4}/{d:.4}/{d:.4}ms ",
            .{
                indent,
                agg.label,
                agg.run_count,
                self.run_count,
                agg.src.file,
                agg.src.line,
                indent,
                excl_min_ms,
                excl_avg_ms,
                excl_max_ms,
                indent,
                incl_min_ms,
                incl_avg_ms,
                incl_max_ms,
            },
        );

        if (agg.gbps_seen) {
            const gigabyte: f64 = 1024.0 * 1024.0 * 1024.0;
            const gb_min = @as(f64, @floatFromInt(agg.bytes_min)) / gigabyte;
            const gb_max = @as(f64, @floatFromInt(agg.bytes_max)) / gigabyte;
            std.log.info(
                "{s}→ bytes min/max {d:.4}/{d:.4}gb | GB/s min/max {d:.4}/{d:.4}",
                .{ indent, gb_min, gb_max, agg.gbps_min, agg.gbps_max },
            );
        }

        self.logChildren(agg.first_child, depth + 1);
    }
}

// ---------- tests ----------

test "Tester aggregates nested zones across runs" {
    if (comptime !profiler_mod.enabled) return error.SkipZigTest;

    const Zone = profiler_mod.Zone;

    const Ctx = struct {
        bumps: u32 = 0,

        fn cb(self: *@This(), p: *Profiler) anyerror!void {
            var outer: Zone = .empty;
            outer.init(@src(), p, .{ .label = "outer" });
            defer outer.deinit(p);

            var inner: Zone = .empty;
            inner.init(@src(), p, .{ .label = "inner", .bytes = 64 });
            defer inner.deinit(p);

            self.bumps += 1;
        }
    };

    var ctx: Ctx = .{};

    var tester: Tester = .empty;
    tester.init(std.testing.allocator, .{
        .min_runs = 3,
        .max_runs = 3,
        .stop_after_no_new_min_ms = 1,
    });
    defer tester.deinit();

    try tester.run(Ctx, &ctx, Ctx.cb);

    try std.testing.expectEqual(@as(u64, 3), tester.run_count);
    try std.testing.expectEqual(@as(u32, 3), ctx.bumps);
    try std.testing.expectEqual(@as(usize, 2), tester.anchors.items.len);

    const outer_idx = tester.root_first_child orelse return error.TestExpected;
    const outer = tester.anchors.items[outer_idx];
    try std.testing.expectEqualStrings("outer", outer.label);
    try std.testing.expectEqual(@as(u64, 3), outer.run_count);

    const inner_idx = outer.first_child orelse return error.TestExpected;
    const inner = tester.anchors.items[inner_idx];
    try std.testing.expectEqualStrings("inner", inner.label);
    try std.testing.expectEqual(@as(u64, 3), inner.run_count);
    try std.testing.expect(inner.gbps_seen);
}
