const std = @import("std");
const ArrayList = std.ArrayList;
const mem = std.mem;
const reference = @import("reference.zig");
const Parser = @import("parser.zig");
const Profiler = @import("profiler.zig");
const json = @import("json.zig");
const GlobalProfiler = &@import("global.zig").GlobalProfiler;

const Processor = @This();

io: std.Io,
file: std.Io.File,
reader: std.Io.File.Reader,
buffer: [1024 * 1024 * 8]u8,
parser: Parser,
file_size: u64,

pub fn init(self: *Processor, io: std.Io, gpa: mem.Allocator, path: [:0]const u8) !void {
    var z_file: Profiler.Zone = .empty;
    z_file.init(@src(), GlobalProfiler, .{ .label = "prepareFile" });
    defer z_file.deinit(GlobalProfiler);

    self.io = io;
    self.file = try std.Io.Dir.cwd().openFile(io, path, .{});
    self.file_size = (try self.file.stat(io)).size;
    self.reader = self.file.reader(io, &self.buffer);

    self.parser.init(&self.reader.interface, gpa);
}

pub fn deinit(self: *Processor) void {
    self.parser.deinit();
    self.file.close(self.io);
}

pub fn process(self: *Processor) f64 {
    var z_read: Profiler.Zone = .empty;
    z_read.init(@src(), GlobalProfiler, .{ .label = "reader", .bytes = self.file_size });
    defer z_read.deinit(GlobalProfiler);

    var count: f64 = 0.0;

    var zone: Profiler.Zone = .empty;
    while (self.parser.next()) |p| {
        zone = .empty;

        zone.init(@src(), GlobalProfiler, .{ .label = "haversineFn", .bytes = @sizeOf(json.Points) });
        defer zone.deinit(GlobalProfiler);

        count += reference.referenceHaversine(p.x0, p.y0, p.x1, p.y1, 6372.8);
    }

    return count;
}
