const std = @import("std");
const ArrayList = std.ArrayList;
const mem = std.mem;
const json = @import("json.zig");
const reference = @import("reference.zig");

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const io = init.io;

    var arg_it = init.minimal.args.iterate();

    _ = arg_it.next() orelse return error.WrongArgs;
    const seed_arg = arg_it.next() orelse return error.WrongArgs;
    const size_arg = arg_it.next() orelse return error.WrongArgs;
    if (arg_it.next() != null) return error.WrongArgs;

    const seed = try std.fmt.parseInt(u64, seed_arg, 10);
    const size = try std.fmt.parseInt(u64, size_arg, 10);

    var prng: std.Random.DefaultPrng = .init(seed);
    const rand = prng.random();

    var coords: ArrayList(json.Points) = .empty;
    defer coords.deinit(alloc);

    try coords.ensureTotalCapacity(alloc, size);

    var count: f64 = 0.0;

    while (coords.items.len < size) {
        const x0 = genX(rand);
        const y0 = genY(rand);

        const x1 = genX(rand);
        const y1 = genY(rand);

        coords.appendAssumeCapacity(.{
            .x0 = x0,
            .x1 = x1,
            .y0 = y0,
            .y1 = y1,
        });

        count += reference.referenceHaversine(x0, y0, x1, y1, 6372.8);
    }

    try json.write(alloc, io, .{ .expected = count / @as(f64, @floatFromInt(size)), .seed = seed, .size = size }, coords.items);
}

pub fn genY(rand: std.Random) f64 {
    return rand.float(f64) * 180 - 90;
}

pub fn genX(rand: std.Random) f64 {
    return rand.float(f64) * 360 - 180;
}
