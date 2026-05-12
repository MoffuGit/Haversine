const std = @import("std");
const print = std.debug.print;

pub fn printFooter(length: u64) void {
    print("└", .{});
    var i: usize = 0;
    while (i < length - 2) : (i += 1) {
        print("─", .{});
    }
    print("┘\n", .{});
}

pub fn printDivider(length: u64) void {
    print("├", .{});
    var i: usize = 0;
    while (i < length - 2) : (i += 1) {
        print("─", .{});
    }
    print("┤\n", .{});
}

pub fn printHeader(length: usize) void {
    if (length < 2) return;

    print("┌", .{});
    var i: usize = 0;
    while (i < length - 2) : (i += 1) {
        print("┬", .{});
    }
    print("┐\n", .{});

    print("├", .{});
    i = 0;
    while (i < length - 2) : (i += 1) {
        print("┴", .{});
    }
    print("┤\n", .{});
}

pub fn printCentered(text: []const u8, width: usize) void {
    if (width < 2) return;
    const inner = width - 2;
    const pad: usize = if (text.len < inner) inner - text.len else 0;
    const left = pad / 2;
    const right = pad - left;

    print("│", .{});
    var i: usize = 0;
    while (i < left) : (i += 1) print(" ", .{});
    print("{s}", .{text});
    i = 0;
    while (i < right) : (i += 1) print(" ", .{});
    print("│\n", .{});
}
