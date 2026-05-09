const std = @import("std");
const Allocator = std.mem.Allocator;
const json = @import("json.zig");
const ascii = std.ascii;
const ArrayList = std.ArrayList;

const Parser = @This();

lexer: Lexer,
alloc: Allocator,

pub fn init(self: *Parser, reader: *std.io.Reader, alloc: Allocator) void {
    self.* = .{
        .lexer = undefined,
        .alloc = alloc,
    };

    self.lexer.init(reader, alloc);
}

pub fn parse(self: *Parser) ![]json.Points {
    var res: ArrayList(json.Points) = .{};
    var points: json.Points = .{};

    while (self.lexer.next_token()) |token| {
        if (token == .LBracket) break;
        if (token == .String) self.alloc.free(token.String);
    }

    while (self.lexer.next_token()) |token| {
        //NOTE:
        //00 -> x0,
        //01 -> x1,
        //10 -> y0
        //11 -> y1
        var point: u2 = 0;
        switch (token) {
            .LBrace => points = .{},
            .String => |s| {
                defer self.alloc.free(s);
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
            .RBracket => {
                res.append(self.alloc, points) catch break;
            },
            .Illegal => {
                break;
            },
            else => {},
        }
    }

    return res.allocatedSlice();
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

    reader: *std.io.Reader,
    alloc: Allocator,
    char: ?u8,

    pub fn init(self: *Self, reader: *std.io.Reader, alloc: Allocator) void {
        self.* = .{
            .char = null,
            .reader = reader,
            .alloc = alloc,
        };

        self.read_char();
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
        var float: ArrayList(u8) = .{};
        defer float.deinit(self.alloc);

        while (self.char) |char| {
            if (!ascii.isDigit(char) and char != '.' and char != '-') break;
            float.append(self.alloc, char) catch return .Illegal;
            self.read_char();
        }

        const _float = std.fmt.parseFloat(f64, float.items);
        return .{ .Float = _float catch return .Illegal };
    }

    pub fn read_string(self: *Self) Token {
        self.read_char();
        var string: ArrayList(u8) = .{};

        while (self.char) |char| {
            if (char == '"') break;
            string.append(self.alloc, char) catch return .Illegal;
            self.read_char();
        }

        self.read_char();
        return .{ .String = string.toOwnedSlice(self.alloc) catch &.{} };
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
