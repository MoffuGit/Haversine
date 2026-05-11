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
zone: Profiler.Zone,

pub fn init(self: *Parser, reader: *std.Io.Reader, alloc: Allocator) void {
    self.* = .{
        .zone = .empty,
        .lexer = undefined,
        .alloc = alloc,
    };

    self.zone.init("parser", @src(), GlobalProfiler);

    self.lexer.init(reader, alloc);

    //advance to the [points];
    while (self.lexer.next_token()) |token| {
        if (token == .LBracket) break;
    }
}

pub fn deinit(self: *Parser) void {
    self.lexer.deinit();
    self.zone.deinit(GlobalProfiler);
}

pub fn next(self: *Parser) ?json.Points {
    var points: json.Points = .{};

    var point: u2 = 0;
    while (self.lexer.next_token()) |token| {
        if (token == .LBrace) break;
    }

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

    list: ArrayList(u8) = .empty,

    pub fn init(self: *Self, reader: *std.Io.Reader, alloc: Allocator) void {
        self.* = .{
            .char = null,
            .reader = reader,
            .alloc = alloc,
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
