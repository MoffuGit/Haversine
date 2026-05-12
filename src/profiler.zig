const std = @import("std");
const builtin = std.builtin;
const target = @import("builtin");
const cpu = @import("cpu.zig");
const posix = std.posix;
const print = std.debug.print;

pub const enabled = @import("build_options").profiler;

pub const max_anchors = 4096;
pub const max_depth = 256;

pub const Profiler = if (enabled) ProfilerImpl else NoopProfiler;
pub const Zone = if (enabled) ZoneImpl else NoopZone;

pub const Data = struct {
    elapsed: u64 = 0,
    bytes: u64 = 0,
    ru_minflt: isize = 0,
    ru_majflt: isize = 0,

    pub const empty: Data = .{};

    pub fn add(self: *Data, other: Data) void {
        self.elapsed +%= other.elapsed;
        self.bytes +%= other.bytes;
        self.ru_minflt += other.ru_minflt;
        self.ru_majflt += other.ru_majflt;
    }

    pub fn sub(self: *Data, other: Data) void {
        self.elapsed -%= other.elapsed;
        self.bytes -%= other.bytes;
        self.ru_minflt -= other.ru_minflt;
        self.ru_majflt -= other.ru_majflt;
    }
};

pub const Anchor = struct {
    const Self = @This();

    pub const empty: Self = .{
        .exclusive = .empty,
        .inclusive = .empty,
        .hits = 0,
        .src = undefined,
        .parent = null,
        .first_child = null,
        .next_sibling = null,
        .label = undefined,
    };

    exclusive: Data,
    inclusive: Data,
    hits: u64,
    parent: ?u32,
    first_child: ?u32,
    next_sibling: ?u32,
    src: builtin.SourceLocation,
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

    pub fn init(self: *NoopProfiler, _: []const u8) void {
        self.start = cpu.readCpuTimer();
    }

    pub fn deinit(self: *NoopProfiler) void {
        self.end = cpu.readCpuTimer();
    }

    pub fn log(self: *NoopProfiler) void {
        const timer_freq = cpu.readTimerFreq();
        const total_elapsed = self.end - self.start;
        const total_ms = 1000.0 * @as(f64, @floatFromInt(total_elapsed)) / @as(f64, @floatFromInt(timer_freq));

        var buffer: [256]u8 = undefined;
        const cpu_count = std.Thread.getCpuCount() catch 0;

        const sys_info = std.fmt.bufPrint(&buffer, "OS: {s} | Arch: {s} | CPU: {s} ({d} cores) | Timer freq: {d}\n", .{
            @tagName(target.os.tag),
            @tagName(target.cpu.arch),
            target.cpu.model.name,
            cpu_count,
            timer_freq,
        }) catch &.{};

        printHeader(sys_info.len);
        print("{s}", .{sys_info});
        print("Total time: {d:.4}ms\n", .{total_ms});
    }
};

const NoopZone = struct {
    pub const empty: NoopZone = .{};

    pub fn init(
        _: *NoopZone,
        _: builtin.SourceLocation,
        _: *NoopProfiler,
        _: Options,
    ) void {}

    pub fn deinit(_: *NoopZone, _: *NoopProfiler) void {}
};

const ProfilerImpl = struct {
    pub const empty: ProfilerImpl = .{
        .anchors = @splat(Anchor.empty),
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
    label: []const u8,

    pub fn init(self: *ProfilerImpl, label: []const u8) void {
        self.start = cpu.readCpuTimer();
        self.label = label;
    }

    pub fn deinit(self: *ProfilerImpl) void {
        self.end = cpu.readCpuTimer();
    }

    pub fn log(self: *ProfilerImpl) void {
        const timer_freq = cpu.readTimerFreq();
        const total_elapsed = self.end - self.start;
        const total_ms = 1000.0 * @as(f64, @floatFromInt(total_elapsed)) / @as(f64, @floatFromInt(timer_freq));

        var buffer: [256]u8 = undefined;
        const cpu_count = std.Thread.getCpuCount() catch 0;

        const sys_info = std.fmt.bufPrint(&buffer, " OS: {s} | ARCH: {s} | CPU: {s} ({d} cores) ", .{
            @tagName(target.os.tag),
            @tagName(target.cpu.arch),
            target.cpu.model.name,
            cpu_count,
        }) catch &.{};

        var upper: [256]u8 = undefined;
        const final = std.ascii.upperString(&upper, &buffer);

        var profiler: [256]u8 = @splat(' ');
        const data = std.fmt.bufPrint(&profiler, " {s} | {d:.4}ms | Timer freq: {d}", .{
            self.label, total_ms,
            timer_freq,
        }) catch &.{};

        const width = @max(sys_info.len, data.len) + 2;

        print("\n", .{});
        printHeader(width);
        print("│{s}│\n", .{final[0..sys_info.len]});
        printDivider(width);

        print("│{s}│\n", .{data[0 .. width - 2]});
        printFooter(width);

        var indent_buf: [max_depth * 2]u8 = @splat(' ');

        for (self.anchors[0..self.anchor_count], 0..) |anchor, i| {
            if (anchor.hits == 0) continue;

            const has_children = anchor.exclusive.elapsed != anchor.inclusive.elapsed;

            const exclusive_pct = (100.0 * @as(f64, @floatFromInt(anchor.exclusive.elapsed))) / @as(f64, @floatFromInt(total_elapsed));
            const exclusive_ms = 1000.0 * @as(f64, @floatFromInt(anchor.exclusive.elapsed)) / @as(f64, @floatFromInt(timer_freq));

            const depth = self.anchorDepth(@intCast(i));
            const indent = indent_buf[0 .. depth * 4];

            if (has_children) {
                const inclusive_pct = (100.0 * @as(f64, @floatFromInt(anchor.inclusive.elapsed))) / @as(f64, @floatFromInt(total_elapsed));
                const inclusive_ms = 1000.0 * @as(f64, @floatFromInt(anchor.inclusive.elapsed)) / @as(f64, @floatFromInt(timer_freq));

                print(
                    "{s} {s} |{d:.4}ms, {d:.2}%| w/children |{d:.4}ms, {d:.2}%| h:{d} |{s}:{d}| fn:{s}\n",
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
                print(
                    "{s} {s} |{d:.4}ms, {d:.2}%| h:{d} |{s}:{d}| fn:{s}\n",
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

            if (anchor.inclusive.bytes > 0) {
                const gigabyte: f64 = 1024.0 * 1024.0 * 1024.0;
                const seconds = @as(f64, @floatFromInt(anchor.inclusive.elapsed)) / @as(f64, @floatFromInt(timer_freq));
                const gb = @as(f64, @floatFromInt(anchor.inclusive.bytes)) / gigabyte;
                const gbps = gb / seconds;

                print(
                    "{s}  → Memory |{d:.4}gb at {d:.4}gb/s|\n",
                    .{ indent, gb, gbps },
                );
            }
            if (anchor.inclusive.ru_majflt > 0 or anchor.inclusive.ru_minflt > 0) {
                if (has_children) {
                    print(
                        "{s}  → Page Faults |min: {}, maj: {}| w/children |min: {}, maj: {}|\n",
                        .{
                            indent,
                            anchor.exclusive.ru_minflt,
                            anchor.exclusive.ru_majflt,
                            anchor.inclusive.ru_minflt,
                            anchor.inclusive.ru_majflt,
                        },
                    );
                } else {
                    print(
                        "{s}  → Page Faults |min: {}, maj: {}|\n",
                        .{ indent, anchor.exclusive.ru_minflt, anchor.exclusive.ru_majflt },
                    );
                }
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

fn printFooter(length: u64) void {
    print("└", .{});
    var i: usize = 0;
    while (i < length - 2) : (i += 1) {
        print("─", .{});
    }
    print("┘\n", .{});
}

fn printDivider(length: u64) void {
    print("├", .{});
    var i: usize = 0;
    while (i < length - 2) : (i += 1) {
        print("─", .{});
    }
    print("┤\n", .{});
}

fn printHeader(length: usize) void {
    if (length < 2) return;

    print("┌", .{});
    var i: usize = 0;
    while (i < length - 2) : (i += 1) {
        print("┬", .{});
    }
    print("┐\n", .{});

    print("├", .{});
    i = 0;
    while (i < length - 2) : (i += 1) {
        print("┴", .{});
    }
    print("┤\n", .{});
}

fn printCentered(text: []const u8, width: usize) void {
    if (width < 2) return;
    const inner = width - 2;
    const pad: usize = if (text.len < inner) inner - text.len else 0;
    const left = pad / 2;
    const right = pad - left;

    print("│", .{});
    var i: usize = 0;
    while (i < left) : (i += 1) print(" ", .{});
    print("{s}", .{text});
    i = 0;
    while (i < right) : (i += 1) print(" ", .{});
    print("│\n", .{});
}

pub fn sameSrc(a: builtin.SourceLocation, b: builtin.SourceLocation) bool {
    return a.line == b.line and
        a.column == b.column and
        std.mem.eql(u8, a.file, b.file) and
        std.mem.eql(u8, a.fn_name, b.fn_name);
}

const Options = struct {
    label: []const u8,
    bytes: u64 = 0,
};

const ZoneImpl = struct {
    const Self = @This();

    anchor_idx: u32,
    parent_idx: ?u32,
    old_inclusive: Data,
    start: u64,
    bytes: u64,
    start_ru_minflt: isize,
    start_ru_majflt: isize,

    pub const empty: ZoneImpl = .{
        .anchor_idx = 0,
        .parent_idx = null,
        .old_inclusive = .empty,
        .start = 0,
        .bytes = 0,
        .start_ru_majflt = 0,
        .start_ru_minflt = 0,
    };

    pub fn init(self: *Self, src: builtin.SourceLocation, profiler: *ProfilerImpl, opts: Options) void {
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
                .exclusive = .empty,
                .inclusive = .empty,
                .hits = 0,
                .src = src,
                .parent = parent_idx,
                .first_child = null,
                .next_sibling = parent_slot.*,
                .label = opts.label,
            };
            parent_slot.* = idx;
        }

        profiler.stack[profiler.depth] = .{
            .anchor_idx = idx,
            .first_child = profiler.anchors[idx].first_child,
        };
        profiler.depth += 1;

        const rusage = posix.getrusage(0);

        self.* = .{
            .bytes = opts.bytes,
            .anchor_idx = idx,
            .parent_idx = parent_idx,
            .old_inclusive = profiler.anchors[idx].inclusive,
            .start = cpu.readCpuTimer(),
            .start_ru_minflt = rusage.minflt,
            .start_ru_majflt = rusage.majflt,
        };
    }

    pub fn deinit(self: *Self, profiler: *ProfilerImpl) void {
        profiler.depth -= 1;
        std.debug.assert(profiler.stack[profiler.depth].anchor_idx == self.anchor_idx);

        const elapsed = cpu.readCpuTimer() - self.start;

        const rusage = posix.getrusage(0);

        const delta: Data = .{
            .elapsed = elapsed,
            .bytes = self.bytes,
            .ru_minflt = rusage.minflt - self.start_ru_minflt,
            .ru_majflt = rusage.majflt - self.start_ru_majflt,
        };

        const anchor = &profiler.anchors[self.anchor_idx];
        // Sync any newly-added children back to the anchor.
        anchor.first_child = profiler.stack[profiler.depth].first_child;
        anchor.exclusive.add(delta);
        anchor.inclusive = self.old_inclusive;
        anchor.inclusive.add(delta);
        anchor.hits += 1;

        if (self.parent_idx) |p| {
            profiler.anchors[p].exclusive.sub(delta);
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
    zone.init(@src(), &profiler, .{ .label = "basic" });
    defer zone.deinit(&profiler);

    try io.sleep(.fromSeconds(1), .real);
}
