const std = @import("std");
const reference = @import("reference.zig");
const cpu = @import("cpu.zig");
const Profiler = @import("profiler.zig");
const benchs = @import("benchs/index.zig");

test {
    _ = reference;
    _ = Profiler;
    _ = cpu;
    _ = benchs;
}
