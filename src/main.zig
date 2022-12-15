const std = @import("std");

const allocator = std.heap.c_allocator;
const Tag = enum { list, int };

const Expr =
    union(Tag) {
    list: []Expr,
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

fn parseInt(str: []const u8, state: *ParseState) anyerror!i32 {
    var res: i32 = 0;
    while (hasNextChar(str, state) and '0' <= state.currentChar and state.currentChar <= '9') {
        res = res * 10 + (state.currentChar - '0');
        nextChar(str, state);
    }
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
        const res = try parseInt(str, state);
        //std.log.debug("{}", .{res});
        return Expr{ .int = res };
    } else {
        var buf: Buffer = .{ .items = try allocator.alloc(Expr, 10), .size = 0, .capacity = 10 };
        while (hasNextChar(str, state) and state.currentChar != ')') {
            const item = try parseExpression(str, state);
            skipWS(str, state);

            if (buf.size >= buf.capacity) {
                const newCapacity = buf.capacity * 2;
                buf = .{ .items = try allocator.realloc(buf.items, newCapacity), .size = buf.size, .capacity = newCapacity };
            }

            buf.items[buf.size] = item;
            buf.size += 1;
            nextChar(str, state);
        }

        const res = Expr{ .list = try allocator.dupe(Expr, buf.items) };

        allocator.free(buf.items);
        return res;
    }
}

fn parse(str: []const u8) anyerror!Expr {
    return try parseExpression(str, initState(str));
}

pub fn main() anyerror!void {
    const input: []const u8 = "123";
    std.log.info("{}", .{try parse(input)});
    std.log.info("All your codebase are belong to us.", .{});
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
