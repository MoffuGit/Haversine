const std = @import("std");
const GPA = std.heap.GeneralPurposeAllocator(.{});
const ArrayList = std.ArrayList;
const mem = std.mem;
const reference = @import("reference.zig");
const Parser = @import("parser.zig");

pub fn main() !void {
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

    const file = try std.fs.cwd().openFile(path_arg, .{});
    defer file.close();

    var buffer: [1024 * 1024 * 8]u8 = undefined;
    var reader = file.reader(&buffer);

    var parser: Parser = undefined;

    parser.init(&reader.interface, alloc);
    defer parser.deinit();

    var count: f64 = 0.0;
    while (parser.next()) |p| {
        count += reference.referenceHaversine(p.x0, p.y0, p.x1, p.y1, 6372.8);
    }

    const res = count / @as(f64, @floatFromInt(size));

    std.debug.print("{}\n", .{res});
}
