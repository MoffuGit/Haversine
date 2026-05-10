const std = @import("std");
const builtin = std.builtin;
const cpu = @import("cpu.zig");

pub const Profiler = @This();

pub const empty: Profiler = .{
    .anchors = @splat(.{ .elapsed = 0, .hits = 0, .src = undefined }),
    .start = 0,
    .end = 0,
    .idx = 0,
};

anchors: [4096]Anchor,
start: u64,
end: u64,
idx: usize,

pub fn init(self: *Profiler) void {
    self.start = cpu.readCpuTimer();
}

pub fn deinit(self: *Profiler) void {
    self.end = cpu.readCpuTimer();
}

pub fn log(self: *Profiler) void {
    const cpu_freq = cpu.readCpuFreq();
    const total_elapsed = self.end - self.start;
    const total_ms = 1000.0 * @as(f64, @floatFromInt(total_elapsed)) / @as(f64, @floatFromInt(cpu_freq));

    std.log.info("Total time: {d:.4}ms (CPU freq {d})", .{ total_ms, cpu_freq });

    for (self.anchors[0..], 0..) |anchor, i| {
        if (anchor.hits == 0) continue;

        const percent = (100.0 * @as(f64, @floatFromInt(anchor.elapsed))) / @as(f64, @floatFromInt(total_elapsed));
        const elapsed_ms = 1000.0 * @as(f64, @floatFromInt(anchor.elapsed)) / @as(f64, @floatFromInt(cpu_freq));

        std.log.info(
            "  [{d}] {s}:{d} {s} -- ({d:.4}ms, {d:.2}%), hits: {d}",
            .{ i, anchor.src.file, anchor.src.line, anchor.src.fn_name, elapsed_ms, percent, anchor.hits },
        );
    }
}

pub const Anchor = struct {
    elapsed: u64,
    hits: u64,
    src: builtin.SourceLocation,
};

pub const Zone = struct {
    const Self = @This();

    pub const empty: Zone = .{
        .idx = undefined,
        .start = 0,
        .src = undefined,
    };

    pub fn init(self: *Self, src: builtin.SourceLocation, profiler: *Profiler) void {
        if (profiler.idx > profiler.anchors.len) @panic("Profiler MaxStack Reached");

        self.* = .{
            .idx = profiler.idx,
            .start = cpu.readCpuTimer(),
            .src = src,
        };

        profiler.idx += 1;
    }

    pub fn deinit(self: *Self, keep_depth: bool, profiler: *Profiler) void {
        if (!keep_depth) profiler.idx -= 1;
        const anchor = &profiler.anchors[self.idx];
        anchor.elapsed += cpu.readCpuTimer() - self.start;
        anchor.hits += 1;
        anchor.src = self.src;
    }

    idx: u64,
    start: u64,
    src: builtin.SourceLocation,
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
    zone.init(@src(), &profiler);
    defer zone.deinit(&profiler);

    try io.sleep(.fromSeconds(1), .real);
}
