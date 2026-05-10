const std = @import("std");
const GPA = std.heap.GeneralPurposeAllocator(.{});
const ArrayList = std.ArrayList;
const mem = std.mem;
const reference = @import("reference.zig");
const Parser = @import("parser.zig");
const cpu = @import("cpu.zig");

pub fn main() !void {
    const cpu_freq = cpu.guessCpuFreq(100);
    const start = cpu.readCpuTimer();
    defer {
        const end = cpu.readCpuTimer();

        const total: f64 = @floatFromInt(end - start);

        std.debug.print("total time: {d}ms\n", .{(total / cpu_freq) * 1000.0});
    }

    var gpa: GPA = .{};
    const alloc = gpa.allocator();

    const args = std.os.argv;

    if (args.len != 2) return error.WrongArgs;

    const path_arg: []u8 = mem.span(args[1]);

    var split = std.mem.splitScalar(u8, path_arg, '/');
    _ = split.next();
    _ = split.next();

    const name = split.next() orelse return;
    var _split = std.mem.splitScalar(u8, name, '_');

    const seed_arg = _split.next() orelse return;
    const seed = try std.fmt.parseInt(u64, seed_arg, 10);
    _ = seed;

    const size_arg = _split.next() orelse return;
    const size = try std.fmt.parseInt(u64, size_arg, 10);

    const res_arg = _split.next() orelse return;
    const res_trim = std.mem.trimEnd(u8, res_arg, ".json");
    const expected_res = try std.fmt.parseFloat(f64, res_trim);

    const file = try std.fs.cwd().openFile(path_arg, .{});
    defer file.close();

    var buffer: [1024 * 1024 * 8]u8 = undefined;
    var reader = file.reader(&buffer);

    const setup_end = cpu.readCpuTimer();
    const total: f64 = @floatFromInt(setup_end - start);

    std.debug.print("initial setup: {d}ms\n", .{(total / cpu_freq) * 1000.0});

    var parser: Parser = undefined;

    parser.init(&reader.interface, alloc);
    defer parser.deinit();

    var count: f64 = 0.0;
    var haversine_t: u64 = 0;
    defer {
        std.debug.print("haversine time: {d}ms\n", .{(@as(f64, @floatFromInt(haversine_t)) / cpu_freq) * 1000.0});
    }

    while (parser.next()) |p| {
        const s = cpu.readCpuTimer();
        count += reference.referenceHaversine(p.x0, p.y0, p.x1, p.y1, 6372.8);
        const e = cpu.readCpuTimer();

        haversine_t += e - s;
    }

    const res = count / @as(f64, @floatFromInt(size));

    if (expected_res != res) {
        std.debug.print("expected: {}, got: {}", .{ expected_res, res });
    }
}
