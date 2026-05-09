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
        .{ .points = coords },
        .{ .whitespace = .indent_2 },
    );
    defer alloc.free(data);

    try dir.writeFile(.{ .sub_path = filename, .data = data });

    std.log.debug("{s}", .{filename});
}

pub fn read(alloc: Allocator, path: []const u8) ![]Points {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var buffer: [1024]u8 = undefined;
    var reader = file.reader(&buffer);

    var parser: Parser = undefined;
    parser.init(&reader.interface, alloc);

    return parser.parse();
}
