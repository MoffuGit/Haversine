const std = @import("std");
const GPA = std.heap.GeneralPurposeAllocator(.{});
const ArrayList = std.ArrayList;
const mem = std.mem;
const json = @import("json.zig");
const reference = @import("reference.zig");

pub fn main() !void {
    var gpa: GPA = .{};
    const alloc = gpa.allocator();

    const args = std.os.argv;

    if (args.len != 2) return error.WrongArgs;

    const path_arg: []u8 = mem.span(args[1]);

    const points = try json.read(alloc, path_arg);
    defer alloc.free(points);

    var count: f64 = 0.0;

    for (points) |p| {
        count += reference.referenceHaversine(p.x0, p.y0, p.x1, p.y1, 6372.8);
    }

    const res = count / @as(f64, @floatFromInt(points.len));

    std.log.debug("{}", .{res});
}
