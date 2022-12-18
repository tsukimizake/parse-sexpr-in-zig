const std = @import("std");

const allocator = std.heap.c_allocator;
const Tag = enum { list, int };

const Expr =
    union(Tag) {
    list: []const Expr,
    int: i32,
};

const ParseState = struct {
    currentIndex: usize,
    currentChar: u8,
};

fn initState(str: []const u8) *ParseState {
    return &ParseState{ .currentIndex = 0, .currentChar = str[0] };
}

fn hasNextChar(str: []const u8, state: *ParseState) bool {
    return str.len - 1 > state.currentIndex;
}

fn isNotEnded(str: []const u8, state: *ParseState) bool {
    return str.len > state.currentIndex;
}

fn nextChar(str: []const u8, state: *ParseState) void {
    state.currentIndex += 1;
    state.currentChar = str[state.currentIndex];
}

fn skipWS(str: []const u8, state: *ParseState) void {
    while (hasNextChar(str, state) and (state.currentChar == ' ' or state.currentChar == '\n')) {
        nextChar(str, state);
    }
    debug("skipWS end", state.currentIndex);
}

fn isInt(state: *ParseState) bool {
    return '0' <= state.currentChar and state.currentChar <= '9';
}

fn parseInt(str: []const u8, state: *ParseState) i32 {
    var res: i32 = 0;

    while (isNotEnded(str, state) and isInt(state)) {
        res = res * 10 + (state.currentChar - '0');
        if (!hasNextChar(str, state)) {
            break;
        }
        nextChar(str, state);
    }
    debug("parseint end", state.currentIndex);
    return res;
}

const Buffer = struct {
    items: []Expr,
    size: usize,
    capacity: usize,
};

const Error = error{parseError};

fn parseExpression(str: []const u8, state: *ParseState) anyerror!Expr {
    skipWS(str, state);
    if (isInt(state)) {
        const res = parseInt(str, state);
        return Expr{ .int = res };
    } else if (state.currentChar == '(') {
        nextChar(str, state);
        var buf: Buffer = .{ .items = try allocator.alloc(Expr, 10), .size = 0, .capacity = 10 };
        defer allocator.free(buf.items);

        while (isNotEnded(str, state) and state.currentChar != ')') {
            const item = try parseExpression(str, state);
            skipWS(str, state);

            if (buf.size >= buf.capacity) {
                const newCapacity = buf.capacity * 2;
                buf = .{ .items = try allocator.realloc(buf.items, newCapacity), .size = buf.size, .capacity = newCapacity };
            }

            buf.items[buf.size] = item;
            buf.size += 1;
        }

        debug("parseExpr end", state.currentIndex);
        return Expr{ .list = try allocator.dupe(Expr, buf.items[0..buf.size]) };
    } else {
        return Error.parseError;
    }
}

fn debug(str: []const u8, x: anytype) void {
    std.log.debug("{s}: {any}", .{ str, x });
}

fn parse(str: []const u8) anyerror!Expr {
    return try parseExpression(str, initState(str));
}

fn hoge(_: []u8) void {}

pub fn main() anyerror!void {
    const input = std.os.argv[1];
    std.log.info("{}", .{try parse(input[0..strlen(input)])});
}

fn strlen(str: [*:0]const u8) usize {
    var count: usize = 0;
    while (str[count] != 0) {
        count += 1;
    }
    return count;
}

fn exprEqual(lhs: Expr, rhs: Expr) bool {
    return switch (lhs) {
        Tag.int => switch (rhs) {
            Tag.int => lhs.int == rhs.int,
            Tag.list => false,
        },
        Tag.list => switch (rhs) {
            Tag.list => {
                if (lhs.list.len != rhs.list.len) {
                    return false;
                } else {
                    var res: bool = true;
                    for (lhs.list) |v, i| {
                        res = res and exprEqual(v, rhs.list[i]);
                    }
                    return res;
                }
            },
            Tag.int => false,
        },
    };
}

test "int test" {
    try std.testing.expectEqual(Expr{ .int = 123 }, try parse("123"));
}

test "expr test" {
    try std.testing.expect(exprEqual(.{ .list = &.{.{ .int = 123 }} }, try parse("(123)")));
    try std.testing.expect(exprEqual(.{ .int = 123 }, try parse("123")));
    try std.testing.expect(exprEqual(Expr{ .list = &.{Expr{ .int = 123 }} }, try parse("(123)")));
    try std.testing.expect(exprEqual(Expr{ .list = &.{ .{ .int = 1 }, .{ .int = 2 }, .{ .int = 3 } } }, try parse("(1 2 3)")));
    try std.testing.expect(exprEqual(Expr{ .list = &.{ Expr{ .int = 1 }, Expr{ .list = &.{ .{ .int = 2 }, Expr{ .list = &.{Expr{ .int = 3 }} } } } } }, try parse("(1(2(3)))")));
    try std.testing.expect(exprEqual(Expr{ .list = &.{Expr{ .list = &.{ .{ .int = 12 }, .{ .int = 3 } } }} }, try parse("( (12 3) )")));
}
