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
    return &.{ .currentIndex = 0, .currentChar = str[0] };
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
    std.log.debug("parseint end {}", .{state.currentIndex});
    return res;
}

const Buffer = struct {
    items: []Expr,
    size: usize,
    capacity: usize,
};

fn parseExpression(str: []const u8, state: *ParseState) anyerror!Expr {
    skipWS(str, state);
    if (isInt(state)) {
        const res = parseInt(str, state);
        return Expr{ .int = res };
    } else {
        var buf: Buffer = .{ .items = try allocator.alloc(Expr, 10), .size = 0, .capacity = 10 };
        defer allocator.free(buf.items);

        debug("bufsize {}", .{buf.size});
        while (isNotEnded(str, state) and state.currentChar != ')') {
            const item = try parseExpression(str, state);
            skipWS(str, state);

            debug("bufsize {}", .{buf.size});
            // bufにparseStateが入っている？？？
            if (buf.size >= buf.capacity) {
                const newCapacity = buf.capacity * 2;
                buf = .{ .items = try allocator.realloc(buf.items, newCapacity), .size = buf.size, .capacity = newCapacity };
            }

            debug("bufsize {}", .{buf.size});
            buf.items[buf.size] = item;
            buf.size += 1;
            if (!hasNextChar(str, state)) {
                break;
            }
            nextChar(str, state);
        }

        std.log.debug("parseExpr end {}", .{state.currentIndex});
        return Expr{ .list = try allocator.dupe(Expr, buf.items) };
    }
}

const debug = std.log.debug;

fn parse(str: []const u8) anyerror!Expr {
    return try parseExpression(str, initState(str));
}

pub fn main() anyerror!void {
    // const input = std.os.argv[1];
    const input = "(123)";
    std.log.info("{}", .{try parse(input)});
}

test "int test" {
    try std.testing.expectEqual(Expr{ .int = 123 }, try parse("123"));
}

test "expr test" {
    try std.testing.expectEqual(Expr{ .list = &.{Expr{ .int = 123 }} }, try parse("(123)"));
}
