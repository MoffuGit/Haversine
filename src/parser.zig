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
    const points: ArrayList(json.Points) = .{};

    while (self.lexer.next_token()) |token| {
        switch (token) {
            .String => |s| {
                std.log.err("{s}", .{s});
                self.alloc.free(s);
            },
            .Illegal => {
                break;
            },
            else => {
                std.log.err("{}", .{token});
            },
        }
    }

    return points.allocatedSlice();
}

const Token = union(enum) {
    LBraket,
    RBraket,

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
            '[' => .LBraket,
            ']' => .RBraket,
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
