const std = @import("std");
const ArrayList = std.ArrayList;
const mem = std.mem;
const Parser = @import("parser.zig");
const Profiler = @import("profiler.zig");
const json = @import("json.zig");
const GlobalProfiler = &@import("global.zig").GlobalProfiler;

pub const HaversineFn = *const fn (x0: f64, y0: f64, x1: f64, y1: f64, earth: f64) f64;

const Processor = @This();

io: std.Io,
file: std.Io.File,
reader: std.Io.File.Reader,
buffer: []u8,
parser: Parser,
file_size: u64,

pub fn init(self: *Processor, io: std.Io, gpa: mem.Allocator, path: [:0]const u8) !void {
    var z_file: Profiler.Zone = .empty;
    z_file.init(@src(), GlobalProfiler, .{ .label = "prepareProcessor" });
    defer z_file.deinit(GlobalProfiler);

    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    errdefer file.close(io);

    const stat = try file.stat(io);

    const buffer = try gpa.alloc(u8, 1024 * 1024 * 8);
    errdefer gpa.free(buffer);

    self.* = .{
        .file = file,
        .io = io,
        .file_size = stat.size,
        .buffer = buffer,
        .reader = undefined,
        .parser = undefined,
    };
    self.reader = self.file.reader(io, self.buffer);
    self.parser.init(&self.reader.interface, gpa);
}

pub fn deinit(self: *Processor) void {
    self.parser.deinit();
    self.file.close(self.io);
}

pub fn process(self: *Processor, haversine_fn: HaversineFn) f64 {
    var count: f64 = 0.0;

    var parser_zone: Profiler.Zone = .empty;
    parser_zone.init(@src(), GlobalProfiler, .{
        .label = "parser",
        .bytes = self.file_size,
        .flags = .{ .page_faults = true },
    });
    defer parser_zone.deinit(GlobalProfiler);

    var haversine_zone: Profiler.Zone = .empty;

    while (self.parser.next()) |p| {
        haversine_zone = .empty;

        haversine_zone.init(@src(), GlobalProfiler, .{ .label = "haversineFn", .bytes = @sizeOf(json.Points) });
        defer haversine_zone.deinit(GlobalProfiler);

        count += haversine_fn(p.x0, p.y0, p.x1, p.y1, 6372.8);
    }

    return count;
}
