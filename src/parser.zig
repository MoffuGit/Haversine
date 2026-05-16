const std = @import("std");
const Allocator = std.mem.Allocator;
const json = @import("json.zig");
const ascii = std.ascii;
const ArrayList = std.ArrayList;
const GlobalProfiler = &@import("global.zig").GlobalProfiler;
const Profiler = @import("profiler.zig");

const Parser = @This();

lexer: Lexer,
alloc: Allocator,

pub fn init(self: *Parser, reader: *std.Io.Reader, alloc: Allocator) void {
    self.* = .{
        .lexer = undefined,
        .alloc = alloc,
    };

    self.lexer.init(reader, alloc);
}

pub fn deinit(self: *Parser) void {
    self.lexer.deinit();
}

pub fn next(self: *Parser) ?json.Points {
    while (self.lexer.next_token()) |token| {
        if (token == .LBrace) break;
    }

    var points: json.Points = .{};
    var point: u2 = 0;

    while (self.lexer.next_token()) |token| {
        switch (token) {
            .String => |s| {
                if (std.mem.eql(u8, s, "x0")) point = 0b00;
                if (std.mem.eql(u8, s, "x1")) point = 0b01;
                if (std.mem.eql(u8, s, "y0")) point = 0b10;
                if (std.mem.eql(u8, s, "y1")) point = 0b11;
            },
            .Float => |f| {
                switch (point) {
                    0b00 => points.x0 = f,
                    0b01 => points.x1 = f,
                    0b10 => points.y0 = f,
                    0b11 => points.y1 = f,
                }
            },
            .RBrace => {
                return points;
            },
            .Illegal, .RBracket => {
                return null;
            },
            else => {},
        }
    }

    return null;
}

const Token = union(enum) {
    LBracket,
    RBracket,

    LBrace,
    RBrace,

    Dot,
    Comma,
    Colon,

    String: []u8,
    Float: f64,

    Minus,
    Illegal,
};

const Lexer = struct {
    const Self = @This();

    reader: *std.Io.Reader,
    alloc: Allocator,
    char: ?u8,
    zone: Profiler.Zone,

    list: ArrayList(u8) = .empty,

    pub fn init(self: *Self, reader: *std.Io.Reader, alloc: Allocator) void {
        self.* = .{
            .char = null,
            .reader = reader,
            .alloc = alloc,
            .zone = .empty,
        };

        self.read_char();
    }

    pub fn deinit(self: *Self) void {
        self.list.deinit(self.alloc);
    }

    pub fn read_char(self: *Self) void {
        self.char = self.reader.takeByte() catch null;
    }

    pub fn peak_char(self: *Self) ?u8 {
        return self.reader.peekByte() catch null;
    }

    pub fn skip_whitespace(self: *Self) void {
        while (self.char) |c| {
            if (!ascii.isWhitespace(c)) break;
            self.read_char();
        }
    }

    pub fn read_number(self: *Self) Token {
        self.list.clearRetainingCapacity();
        while (self.char) |char| {
            if (!ascii.isDigit(char) and char != '.' and char != '-') break;
            self.list.append(self.alloc, char) catch return .Illegal;
            self.read_char();
        }

        const _float = std.fmt.parseFloat(f64, self.list.items);
        return .{ .Float = _float catch return .Illegal };
    }

    pub fn read_string(self: *Self) Token {
        self.read_char();
        self.list.clearRetainingCapacity();

        while (self.char) |char| {
            if (char == '"') break;
            self.list.append(self.alloc, char) catch return .Illegal;
            self.read_char();
        }

        self.read_char();
        return .{ .String = self.list.items };
    }

    pub fn next_token(self: *Self) ?Token {
        self.zone = .empty;
        self.zone.init(@src(), GlobalProfiler, .{ .label = "lexer" });
        defer self.zone.deinit(GlobalProfiler);

        self.skip_whitespace();

        const c = self.char orelse return null;

        const token: Token = switch (c) {
            '"' => self.read_string(),
            '{' => .LBrace,
            '}' => .RBrace,
            '[' => .LBracket,
            ']' => .RBracket,
            ':' => .Colon,
            ',' => .Comma,
            '.' => .Dot,
            '-' => self.read_number(),
            else => if (ascii.isDigit(c)) self.read_number() else .Illegal,
        };

        self.read_char();

        return token;
    }
};

pub const PathInfo = struct {
    seed: u64,
    size: u64,
    res: f64,
};

const Error =
    std.fmt.ParseFloatError ||
    std.fmt.ParseIntError ||
    error{
        WrongJsonFile,
    };

pub fn parse_path(path: [:0]const u8) Error!PathInfo {
    var zone: Profiler.Zone = .empty;
    zone.init(@src(), GlobalProfiler, .{ .label = "parsePath" });
    defer zone.deinit(GlobalProfiler);

    const basename = std.fs.path.basename(path);
    const stem = std.fs.path.stem(basename);

    var parts = std.mem.splitScalar(u8, stem, '_');

    const seed_arg = parts.next() orelse return Error.WrongJsonFile;
    const seed = try std.fmt.parseInt(u64, seed_arg, 10);

    const size_arg = parts.next() orelse return Error.WrongJsonFile;
    const size = try std.fmt.parseInt(u64, size_arg, 10);

    const res_arg = parts.next() orelse return Error.WrongJsonFile;
    const res = try std.fmt.parseFloat(f64, res_arg);

    return .{
        .size = size,
        .seed = seed,
        .res = res,
    };
}
