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

    var file = try dir.createFile(io, filename, .{});
    defer file.close(io);

    // Stream the JSON directly to the file instead of buffering the whole
    // document in memory. With 14 GiB outputs, `valueAlloc` would either OOM
    // or fail at the single-allocation limit; a fixed-size write buffer keeps
    // memory use bounded regardless of the output size.
    const buffer = try alloc.alloc(u8, 1 << 20); // 1 MiB
    defer alloc.free(buffer);

    var fw = file.writer(io, buffer);

    try std.json.Stringify.value(
        .{ .points = coords },
        .{ .whitespace = .indent_2 },
        &fw.interface,
    );

    try fw.end();

    std.log.debug("{s}", .{filename});
}
