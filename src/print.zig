const std = @import("std");
const print = std.debug.print;

pub const Divider = enum { top, middle, bottom };

pub fn printDivider(kind: Divider, width: usize) void {
    if (width < 2) return;

    if (kind == .top) {
        // Top decoration: two-line ridge (┌┬┬┬┐ over ├┴┴┴┤).
        print("┌", .{});
        var i: usize = 0;
        while (i < width - 2) : (i += 1) print("┬", .{});
        print("┐\n", .{});

        print("├", .{});
        i = 0;
        while (i < width - 2) : (i += 1) print("┴", .{});
        print("┤\n", .{});
        return;
    }

    const left, const right = switch (kind) {
        .top => unreachable,
        .middle => .{ "├", "┤" },
        .bottom => .{ "└", "┘" },
    };
    print("{s}", .{left});
    var i: usize = 0;
    while (i < width - 2) : (i += 1) print("─", .{});
    print("{s}\n", .{right});
}

pub fn printRow(text: []const u8, width: usize) void {
    if (width < 2) return;
    const inner = width - 2;
    print("│{s}", .{text});
    if (text.len < inner) {
        var i: usize = text.len;
        while (i < inner) : (i += 1) print(" ", .{});
    }
    print("│\n", .{});
}

/// Print a row that may span multiple physical lines (separated by `\n`).
/// All sub-lines share the same width and no divider is drawn between them.
pub fn printRowUnit(text: []const u8, width: usize) void {
    var it = std.mem.splitScalar(u8, text, '\n');
    while (it.next()) |line| printRow(line, width);
}

/// Print a plain row (no borders) of `c` repeated `width` times.
pub fn printPlainFill(c: u8, width: usize) void {
    var i: usize = 0;
    while (i < width) : (i += 1) print("{c}", .{c});
    print("\n", .{});
}

/// Return the longest sub-line length within `text` (split on `\n`).
pub fn maxLineLen(text: []const u8) usize {
    var max: usize = 0;
    var it = std.mem.splitScalar(u8, text, '\n');
    while (it.next()) |line| max = @max(max, line.len);
    return max;
}

/// Print a boxed result containing the given `headers`, each as its own row
/// separated by a `.middle` divider. The table width is `max(longest header
/// sub-line + 2, min_width)`. Pass an empty slice to omit the box entirely.
pub fn printResult(headers: []const []const u8, min_width: usize) void {
    if (headers.len == 0) return;

    var max_len: usize = 0;
    for (headers) |h| max_len = @max(max_len, maxLineLen(h));
    var width = max_len + 2;
    if (min_width > width) width = min_width;
    if (width < 2) return;

    printDivider(.top, width);
    for (headers, 0..) |h, i| {
        printRowUnit(h, width);
        if (i + 1 < headers.len) printDivider(.middle, width);
    }
    printDivider(.bottom, width);
}
