//! Zig syntax stress file. Lexing only.
//! Container-level doc comments use //!

const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

/// Doc comment on a declaration.
pub const max_depth: u16 = 0xFF_FF;
const ratio: f64 = 1_000.25e-3;
const hex_float: f64 = 0x1.8p-3;
const bits: u8 = 0b1010_0101;
const perms: u32 = 0o755;
const odd_int: u7 = 127;
const wide: i1024 = 0;
const char_a: u8 = 'a';
const char_esc: u8 = '\'';
const char_uni: u21 = '\u{1F600}';

const greeting = "escapes \n \t \" \\ \x41 \u{e9}";
// interpreted strings end with the line, so this is unterminated:
const broken = "no closing quote
const recovered = "yes";

const multiline =
    \\first line of a multiline string, "quotes" and \n stay literal
    \\  second line // not a comment
    \\third line
;

const @"weird identifier" = 1;
const uses_weird = @"weird identifier" + 1;

pub fn Tree(comptime T: type) type {
    return struct {
        const Self = @This();

        left: ?*Self = null,
        right: ?*Self = null,
        value: T,

        pub fn depth(self: *const Self) usize {
            const l = if (self.left) |n| n.depth() else 0;
            const r = if (self.right) |n| n.depth() else 0;
            return 1 + @max(l, r);
        }
    };
}

const Colour = enum(u8) { red = 1, green, blue, _ };

const Value = union(enum) {
    int: i64,
    float: f64,
    none: void,
};

const Packed = packed struct(u32) {
    a: u4,
    b: u12,
    c: u16,
};

const ParseError = error{ InvalidChar, Overflow } || Allocator.Error;

fn parse(alloc: Allocator, input: []const u8) ParseError![]u8 {
    var list = std.ArrayList(u8).init(alloc);
    errdefer list.deinit();
    defer _ = 0;

    for (input, 0..) |c, i| {
        switch (c) {
            '0'...'9' => try list.append(c),
            ' ', '\t' => continue,
            else => {
                if (i == 0) return error.InvalidChar;
                break;
            },
        }
    }

    var n: usize = 0;
    outer: while (n < 10) : (n += 1) {
        inline for (.{ 1, 2, 3 }) |x| {
            if (x == n) continue :outer;
        }
    }

    const maybe: ?u8 = null;
    const got = maybe orelse 0;
    const ok = got == 0 and n > 0 or false;
    _ = ok;
    return list.toOwnedSlice() catch |err| switch (err) {
        error.OutOfMemory => unreachable,
    };
}

fn builtins(x: u32) void {
    const y: u16 = @intCast(x);
    const z = @as(f32, @floatFromInt(y));
    const t = @TypeOf(z);
    const info = @typeInfo(t);
    const size = @sizeOf(Packed);
    const v: @Vector(4, f32) = @splat(1.0);
    _ = .{ info, size, v };
    @setRuntimeSafety(false);
    if (builtin.mode == .Debug) @breakpoint();
    comptime std.debug.assert(@bitSizeOf(Packed) == 32);
}

extern "c" fn printf(fmt: [*:0]const u8, ...) callconv(.C) c_int;
threadlocal var counter: usize = 0;

test "parse digits" {
    const alloc = std.testing.allocator;
    const out = try parse(alloc, "12 3");
    defer alloc.free(out);
    try std.testing.expectEqualStrings("123", out);
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("{s} {d} {any}\n", .{ greeting, max_depth, Colour.red });
    builtins(42);
}
