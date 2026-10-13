const std = @import("std");
const c = @import("src/color.zig");
const pc = @import("src/predefined_colors.zig");
const custom = @import("custom.zig");
const Types = .{ c.Rgb24, c.Rgba32, c.Bgr24, c.Bgra32, c.Rgb48, c.Rgba64, c.Colorf32, c.Rgb332, c.Rgb555, c.Bgr555, c.Rgb565, custom.Encoded, custom.Swizzled, custom.Snapshot, custom.Marked, c.Rgb24, c.Colorf32 };
const W = std.Io.Writer;
fn choose(comptime T: type, index: u8) T {
    const P = pc.Colors(T);
    return switch (index) {
        0 => P.Red,
        1 => P.Green,
        2 => P.Blue,
        3 => P.White,
        4 => P.Black,
        5 => P.Cyan,
        6 => P.Magenta,
        7 => P.Yellow,
        else => unreachable,
    };
}
fn record(out: *W, value: anytype) !void {
    const T = @TypeOf(value);
    if (T == c.Rgb332 or T == c.Rgb555 or T == c.Bgr555 or T == c.Rgb565) {
        try out.print("{d},|", .{@as(std.meta.Int(.unsigned, @bitSizeOf(T)), @bitCast(value))});
        return;
    }
    inline for (@typeInfo(T).@"struct".fields) |field| {
        const v = @field(value, field.name);
        switch (@typeInfo(field.type)) {
            .float => try out.print("{d},", .{@as(u32, @bitCast(v))}),
            .int => try out.print("{d},", .{v}),
            .bool => try out.print("{},", .{v}),
            .array => for (v) |element| try out.print("{d},", .{element}),
            else => {},
        }
    }
    try out.writeByte('|');
}
fn changed(value: anytype, replacement: @TypeOf(value)) @TypeOf(value) {
    if (@TypeOf(value) == custom.Snapshot) {
        var result = value;
        result.channel_bits[0] = replacement.channel_bits[0];
        return result;
    }
    return replacement;
}
fn run(comptime T: type, out: *W, index: u8, replacement: u8, operation: u8) !void {
    var original = choose(T, index);
    var copy = original;
    var returned = original;
    const other = choose(T, replacement);
    switch (operation) {
        0 => {},
        1 => copy = changed(copy, other),
        2 => original = changed(original, other),
        3 => {
            copy = changed(copy, other);
            returned = changed(copy, original);
            copy = original;
        },
        else => unreachable,
    }
    try record(out, original);
    try record(out, copy);
    try record(out, returned);
    try record(out, choose(T, index));
}
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const argv = try std.process.argsAlloc(allocator);
    const contents = try std.fs.cwd().readFileAlloc(allocator, argv[1], 16 * 1024 * 1024);
    var buffer: [64 * 1024]u8 = undefined;
    var output = std.fs.File.stdout().writer(&buffer);
    var lines = std.mem.tokenizeScalar(u8, contents, '\n');
    while (lines.next()) |line| {
        var parts = std.mem.splitScalar(u8, line, '|');
        const kind = try std.fmt.parseInt(u8, parts.next().?, 10);
        const index = try std.fmt.parseInt(u8, parts.next().?, 10);
        const replacement = try std.fmt.parseInt(u8, parts.next().?, 10);
        const operation = try std.fmt.parseInt(u8, parts.next().?, 10);
        inline for (Types, 0..) |T, i| if (kind == i) try run(T, &output.interface, index, replacement, operation);
        try output.interface.writeByte('\n');
    }
    try output.interface.flush();
}
