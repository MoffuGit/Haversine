const std = @import("std");

const profilerpkg = @import("../profiler.zig");
const Profiler = profilerpkg.Profiler;
const Allocator = std.mem.Allocator;
const Tester = @import("../tester.zig");
const Processor = @import("../processor.zig");
const Parser = @import("../parser.zig");
const reference = @import("../reference.zig");

const Context = struct {
    io: std.Io,
    alloc: Allocator,
    path: [:0]const u8,
};

test "Bench Processor" {
    const io = std.testing.io;
    const gpa = std.testing.allocator;

    const path = "./generated/43564768_1000000_10011.998232663716.json";

    var ctx: Context = .{
        .io = io,
        .alloc = gpa,
        .path = path,
    };

    try Tester.runAll(gpa, .{
        .min_runs = 3,
        .stop_after_no_new_min_ms = 10000,
        .max_runs = 200,
        .log_profiler = true,
    }, Context, &ctx, .{
        processReference,
    });
}

fn processReference(_ctx: ?*Context, profiler: *Profiler) !void {
    const ctx = _ctx orelse return;

    const info = try Parser.parse_path(ctx.path, profiler);

    var processor: Processor = undefined;
    try processor.init(ctx.io, ctx.alloc, ctx.path, profiler);
    defer processor.deinit();

    const count = processor.process(reference.referenceHaversine);
    const res = count / @as(f64, @floatFromInt(info.size));

    if (info.res != res) return error.WrongResult;
}
