const Hex = @This();

const std = @import("std");

const Allocator = std.mem.Allocator;

const Encoder = struct {
    const HexTableLowercase = "0123456789abcdef";
    const HexTableUppercase = "0123456789ABCDEF";

    const Format = enum {
        lower,
        upper,
    };

    const Output = struct {
        a: u8,
        b: u8,
    };

    const Iterator = struct {
        format: Format,
        slice: []const u8,
        index: usize = 0,

        fn next(self: *Iterator) ?Output {
            const index = self.index;

            const table = switch (self.format) {
                .lower => HexTableLowercase,
                .upper => HexTableUppercase,
            };

            for (self.slice[index..]) |byte| {
                self.index += 1;

                const a = table[byte >> 4];
                const b = table[byte & 0x0f];

                return Output{ .a = a, .b = b };
            }

            return null;
        }
    };

    iterator: Iterator,

    fn iterate(self: *Encoder, buffer: []u8) void {
        var iter = self.iterator;

        var j: usize = 0;
        while (iter.next()) |pair| : (j += 2) {
            buffer[j] = pair.a;
            buffer[j + 1] = pair.b;
        }
    }
};

fn internalEncode(slice: []const u8, buffer: []u8, format: Encoder.Format) void {
    var encoder: Encoder = .{
        .iterator = .{
            .slice = slice,
            .format = format,
        },
    };
    encoder.iterate(buffer);
}

pub fn encode(allocator: Allocator, data: []const u8) ![]const u8 {
    var buffer = try allocator.alloc(u8, data.len * 2);
    internalEncode(data, buffer, .lower);
    return buffer;
}

pub fn encodeUpper(allocator: Allocator, data: []const u8) ![]const u8 {
    var buffer = try allocator.alloc(u8, data.len * 2);
    internalEncode(data, buffer, .upper);
    return buffer;
}

fn getValue(c: u8) !u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'a'...'z' => c - 'a' + 10,
        'A'...'Z' => c - 'A' + 10,

        else => error.Unknown,
    };
}

pub fn decode(allocator: Allocator, data: []const u8) ![]const u8 {
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    var i: usize = 0;
    while (i < data.len + 0) : (i += 2) {
        const a: u8 = try getValue(data[i]);
        const b: u8 = try getValue(data[i + 1]);

        try buffer.append(a << 4 | b);
    }

    var string = try allocator.alloc(u8, buffer.items.len);

    for (buffer.items, 0..) |char, j| {
        string[j] = char;
    }

    return string;
}

test "encode" {
    const allocator = std.testing.allocator;

    const hex = try encode(allocator, "zig");
    try std.testing.expect(std.mem.eql(u8, hex, "7a6967"));
    allocator.free(hex);
}

test "decode" {
    const allocator = std.testing.allocator;

    const hex = try decode(allocator, "7a6967");
    try std.testing.expect(std.mem.eql(u8, hex, "zig"));
    allocator.free(hex);
}
