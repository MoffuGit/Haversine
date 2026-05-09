const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Gen = struct {
    seed: u64,
    size: u64,
    expected: f64,
};

pub const Points = struct {
    x0: f64 = 0.0,
    y0: f64 = 0.0,
    x1: f64 = 0.0,
    y1: f64 = 0.0,
};

pub fn write(alloc: Allocator, gen: Gen, coords: []Points) !void {
    var cwd = std.fs.cwd();
    try cwd.makePath("generated");

    var dir = try cwd.openDir("generated", .{});
    defer dir.close();

    const filename = try std.fmt.allocPrint(
        alloc,
        "{d}_{d}_{d}.json",
        .{ gen.seed, gen.size, gen.expected },
    );
    defer alloc.free(filename);

    const data = try std.json.Stringify.valueAlloc(
        alloc,
        .{ .gen = gen, .points = coords },
        .{ .whitespace = .indent_2 },
    );
    defer alloc.free(data);

    try dir.writeFile(.{ .sub_path = filename, .data = data });
}
