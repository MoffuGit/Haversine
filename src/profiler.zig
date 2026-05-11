const std = @import("std");
const builtin = std.builtin;
const cpu = @import("cpu.zig");

pub const enabled = @import("build_options").profiler;

pub const max_anchors = 4096;
pub const max_depth = 256;

pub const Profiler = if (enabled) ProfilerImpl else NoopProfiler;
pub const Zone = if (enabled) ZoneImpl else NoopZone;

pub const Anchor = struct {
    elapsed_exclusive: u64,
    elapsed_inclusive: u64,
    hits: u64,
    src: builtin.SourceLocation,
    parent: ?u32,
    first_child: ?u32,
    next_sibling: ?u32,
    label: []const u8,
};

pub const StackEntry = struct {
    anchor_idx: u32,
    first_child: ?u32,
};

const NoopProfiler = struct {
    start: u64 = 0,
    end: u64 = 0,

    pub const empty: NoopProfiler = .{};

    pub fn init(self: *NoopProfiler) void {
        self.start = cpu.readCpuTimer();
    }

    pub fn deinit(self: *NoopProfiler) void {
        self.end = cpu.readCpuTimer();
    }

    pub fn log(self: *NoopProfiler) void {
        const cpu_freq = cpu.readCpuFreq();
        const total_elapsed = self.end - self.start;
        const total_ms = 1000.0 * @as(f64, @floatFromInt(total_elapsed)) / @as(f64, @floatFromInt(cpu_freq));

        std.log.info("Total time: {d:.4}ms (CPU freq {d})", .{ total_ms, cpu_freq });
    }
};

const NoopZone = struct {
    pub const empty: NoopZone = .{};

    pub fn init(
        _: *NoopZone,
        _: []const u8,
        _: builtin.SourceLocation,
        _: *NoopProfiler,
    ) void {}

    pub fn deinit(_: *NoopZone, _: *NoopProfiler) void {}
};

const ProfilerImpl = struct {
    pub const empty: ProfilerImpl = .{
        .anchors = @splat(.{
            .elapsed_exclusive = 0,
            .elapsed_inclusive = 0,
            .hits = 0,
            .src = undefined,
            .parent = null,
            .first_child = null,
            .next_sibling = null,
            .label = undefined,
        }),
        .stack = @splat(.{ .anchor_idx = 0, .first_child = null }),
        .root_first_child = null,
        .depth = 0,
        .anchor_count = 0,
        .start = 0,
        .end = 0,
    };

    anchors: [max_anchors]Anchor,
    stack: [max_depth]StackEntry,
    root_first_child: ?u32,
    depth: usize,
    anchor_count: usize,
    start: u64,
    end: u64,

    pub fn init(self: *ProfilerImpl) void {
        self.start = cpu.readCpuTimer();
    }

    pub fn deinit(self: *ProfilerImpl) void {
        self.end = cpu.readCpuTimer();
    }

    pub fn log(self: *ProfilerImpl) void {
        const cpu_freq = cpu.readCpuFreq();
        const total_elapsed = self.end - self.start;
        const total_ms = 1000.0 * @as(f64, @floatFromInt(total_elapsed)) / @as(f64, @floatFromInt(cpu_freq));

        std.log.info("Total time: {d:.4}ms (CPU freq {d})", .{ total_ms, cpu_freq });

        var indent_buf: [max_depth * 2]u8 = @splat(' ');

        for (self.anchors[0..self.anchor_count], 0..) |anchor, i| {
            if (anchor.hits == 0) continue;

            const has_children = anchor.elapsed_exclusive != anchor.elapsed_inclusive;

            const exclusive_pct = (100.0 * @as(f64, @floatFromInt(anchor.elapsed_exclusive))) / @as(f64, @floatFromInt(total_elapsed));
            const exclusive_ms = 1000.0 * @as(f64, @floatFromInt(anchor.elapsed_exclusive)) / @as(f64, @floatFromInt(cpu_freq));

            const depth = self.anchorDepth(@intCast(i));
            const indent = indent_buf[0 .. depth * 4];

            if (has_children) {
                const inclusive_pct = (100.0 * @as(f64, @floatFromInt(anchor.elapsed_inclusive))) / @as(f64, @floatFromInt(total_elapsed));
                const inclusive_ms = 1000.0 * @as(f64, @floatFromInt(anchor.elapsed_inclusive)) / @as(f64, @floatFromInt(cpu_freq));

                std.log.info(
                    "  {s} {s} |{d:.4}ms, {d:.2}%| w/children |{d:.4}ms, {d:.2}%| h:{d} |{s}:{d}| fn:{s}",
                    .{
                        indent,
                        anchor.label,
                        exclusive_ms,
                        exclusive_pct,
                        inclusive_ms,
                        inclusive_pct,
                        anchor.hits,
                        anchor.src.file,
                        anchor.src.line,
                        anchor.src.fn_name,
                    },
                );
            } else {
                std.log.info(
                    "  {s} {s} |{d:.4}ms, {d:.2}%| h:{d} |{s}:{d}| fn:{s}",
                    .{
                        indent,
                        anchor.label,
                        exclusive_ms,
                        exclusive_pct,
                        anchor.hits,
                        anchor.src.file,
                        anchor.src.line,
                        anchor.src.fn_name,
                    },
                );
            }
        }
    }

    fn anchorDepth(self: *ProfilerImpl, idx: u32) usize {
        var depth: usize = 0;
        var cur: ?u32 = self.anchors[idx].parent;
        while (cur) |p| : (depth += 1) {
            cur = self.anchors[p].parent;
        }
        return depth;
    }

    fn parentChildrenSlot(self: *ProfilerImpl) *?u32 {
        return if (self.depth == 0) &self.root_first_child else &self.stack[self.depth - 1].first_child;
    }
};

fn sameSrc(a: builtin.SourceLocation, b: builtin.SourceLocation) bool {
    return a.line == b.line and
        a.column == b.column and
        std.mem.eql(u8, a.file, b.file) and
        std.mem.eql(u8, a.fn_name, b.fn_name);
}

const ZoneImpl = struct {
    const Self = @This();

    anchor_idx: u32,
    parent_idx: ?u32,
    old_elapsed_inclusive: u64,
    start: u64,

    pub const empty: ZoneImpl = .{
        .anchor_idx = 0,
        .parent_idx = null,
        .old_elapsed_inclusive = 0,
        .start = 0,
    };

    pub fn init(self: *Self, label: []const u8, src: builtin.SourceLocation, profiler: *ProfilerImpl) void {
        if (profiler.depth >= profiler.stack.len) @panic("Profiler MaxDepth Reached");

        const parent_slot = profiler.parentChildrenSlot();
        const parent_idx: ?u32 = if (profiler.depth == 0) null else profiler.stack[profiler.depth - 1].anchor_idx;

        // Walk only the current parent's children (small list) instead of all anchors.
        var idx: u32 = undefined;
        var found = false;
        var cur = parent_slot.*;
        while (cur) |c| {
            if (sameSrc(profiler.anchors[c].src, src)) {
                idx = c;
                found = true;
                break;
            }
            cur = profiler.anchors[c].next_sibling;
        }

        if (!found) {
            if (profiler.anchor_count >= profiler.anchors.len) @panic("Profiler MaxAnchors Reached");
            idx = @intCast(profiler.anchor_count);
            profiler.anchor_count += 1;
            profiler.anchors[idx] = .{
                .elapsed_exclusive = 0,
                .elapsed_inclusive = 0,
                .hits = 0,
                .src = src,
                .parent = parent_idx,
                .first_child = null,
                .next_sibling = parent_slot.*,
                .label = label,
            };
            parent_slot.* = idx;
        }

        // Push onto stack, mirroring this anchor's first_child so children
        // added during this zone's lifetime can update it without an anchor lookup.
        profiler.stack[profiler.depth] = .{
            .anchor_idx = idx,
            .first_child = profiler.anchors[idx].first_child,
        };
        profiler.depth += 1;

        self.* = .{
            .anchor_idx = idx,
            .parent_idx = parent_idx,
            .old_elapsed_inclusive = profiler.anchors[idx].elapsed_inclusive,
            .start = cpu.readCpuTimer(),
        };
    }

    pub fn deinit(self: *Self, profiler: *ProfilerImpl) void {
        profiler.depth -= 1;
        std.debug.assert(profiler.stack[profiler.depth].anchor_idx == self.anchor_idx);

        const elapsed = cpu.readCpuTimer() - self.start;

        const anchor = &profiler.anchors[self.anchor_idx];
        // Sync any newly-added children back to the anchor.
        anchor.first_child = profiler.stack[profiler.depth].first_child;
        anchor.elapsed_exclusive +%= elapsed;
        anchor.elapsed_inclusive = self.old_elapsed_inclusive + elapsed;
        anchor.hits += 1;

        if (self.parent_idx) |p| {
            profiler.anchors[p].elapsed_exclusive -%= elapsed;
        }
    }
};

test "Test Basic Profiler" {
    std.testing.log_level = .info;
    const io = std.testing.io;

    var profiler: Profiler = .empty;

    profiler.init();
    defer {
        profiler.deinit();
        profiler.log();
    }

    var zone: Zone = .empty;
    zone.init("basic", @src(), &profiler);
    defer zone.deinit(&profiler);

    try io.sleep(.fromSeconds(1), .real);
}
