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

/// Sentinel byte that, when found at the start of a sub-line within a text
/// row, marks the line as a fill line whose remaining byte is the fill char.
/// Use the `fill` helper to construct one.
pub const fill_marker: u8 = 0x01;

/// Build a 2-byte fill-line marker (sentinel + char) suitable for embedding
/// inside a text row passed to `printResult`. The line will render as
/// `│cccc…cccc│` extending the full inner table width.
pub fn fill(c: u8) [2]u8 {
    return .{ fill_marker, c };
}

/// Print a row that may span multiple physical lines (separated by `\n`).
/// All sub-lines share the same width and no divider is drawn between them.
/// A sub-line of the form `[fill_marker, c]` renders as a fill line of `c`.
pub fn printRowUnit(text: []const u8, width: usize) void {
    var it = std.mem.splitScalar(u8, text, '\n');
    while (it.next()) |line| {
        if (line.len == 2 and line[0] == fill_marker) {
            printFillRow(line[1], width);
        } else {
            printRow(line, width);
        }
    }
}

/// Print a row whose inner content is `c` repeated to fill the table width.
pub fn printFillRow(c: u8, width: usize) void {
    if (width < 2) return;
    print("│", .{});
    var i: usize = 0;
    while (i < width - 2) : (i += 1) print("{c}", .{c});
    print("│\n", .{});
}

fn maxLineLen(text: []const u8) usize {
    var max: usize = 0;
    var it = std.mem.splitScalar(u8, text, '\n');
    while (it.next()) |line| {
        if (line.len == 2 and line[0] == fill_marker) continue;
        max = @max(max, line.len);
    }
    return max;
}

/// A row in `printResult`. `text` rows may contain `\n` and render as a
/// single divisible unit. `fill` rows are filled with the given byte across
/// the full inner width of the table.
pub const Row = union(enum) {
    text: []const u8,
    fill: u8,
};

/// Print a plain row that may span multiple physical lines (separated by
/// `\n`). Fill-marker sub-lines render as the fill char repeated `width`
/// times. No surrounding borders are drawn.
pub fn printPlainUnit(text: []const u8, width: usize) void {
    var it = std.mem.splitScalar(u8, text, '\n');
    while (it.next()) |line| {
        if (line.len == 2 and line[0] == fill_marker) {
            printPlainFill(line[1], width);
        } else {
            print("{s}\n", .{line});
        }
    }
}

/// Print a plain row of `c` repeated `width` times. No borders.
pub fn printPlainFill(c: u8, width: usize) void {
    var i: usize = 0;
    while (i < width) : (i += 1) print("{c}", .{c});
    print("\n", .{});
}

/// Print a result. The `headers` are rendered inside a box, each as its own
/// row separated by a `.middle` divider. All `rows` are printed plain
/// (without borders) below the box. The table width is computed from the
/// longest sub-line across `headers` and `rows`, plus 2 for the borders.
/// Pass an empty slice for `headers` to omit the box.
pub fn printResult(headers: []const []const u8, rows: []const Row) void {
    var max_len: usize = 0;
    for (headers) |h| max_len = @max(max_len, maxLineLen(h));
    for (rows) |r| switch (r) {
        .text => |t| max_len = @max(max_len, maxLineLen(t)),
        .fill => {},
    };
    if (max_len == 0) return;
    const width = max_len + 2;

    if (headers.len > 0) {
        printDivider(.top, width);
        for (headers, 0..) |h, i| {
            printRowUnit(h, width);
            if (i + 1 < headers.len) printDivider(.middle, width);
        }
        printDivider(.bottom, width);
    }

    for (rows) |r| switch (r) {
        .text => |t| printPlainUnit(t, width),
        .fill => |c| printPlainFill(c, width),
    };
}
