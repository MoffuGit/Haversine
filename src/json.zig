const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Parser = @import("parser.zig");

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

pub fn write(alloc: Allocator, io: std.Io, gen: Gen, coords: []Points) !void {
    var cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, "generated");

    var dir = try cwd.openDir(io, "generated", .{});
    defer dir.close(io);

    const filename = try std.fmt.allocPrint(
        alloc,
        "{d}_{d}_{d}.json",
        .{ gen.seed, gen.size, gen.expected },
    );
    defer alloc.free(filename);

    const data = try std.json.Stringify.valueAlloc(
        alloc,
        .{ .points = coords },
        .{ .whitespace = .indent_2 },
    );
    defer alloc.free(data);

    try dir.writeFile(io, .{ .sub_path = filename, .data = data });

    std.log.debug("{s}", .{filename});
}
