const std = @import("std");
const c = @import("src/color.zig");
fn scalar(comptime T: type, raw: u32) T {
    if (T == f32) return @bitCast(raw);
    return @intCast(raw);
}
fn record(writer: *std.Io.Writer, value: anytype) !void {
    inline for (@typeInfo(@TypeOf(value)).@"struct".fields) |field| {
        if (field.type == f32 or @typeInfo(field.type) == .int) {
            const v = @field(value, field.name);
            const raw: u32 = if (field.type == f32) @bitCast(v) else @intCast(v);
            try writer.print("{d},", .{raw});
        }
    }
}
fn changed(value: anytype, field_index: usize, raw: u32) @TypeOf(value) {
    var result = value;
    inline for (@typeInfo(@TypeOf(value)).@"struct".fields, 0..) |field, index| {
        if (index == field_index) @field(result, field.name) = scalar(field.type, raw);
    }
    return result;
}
fn observe(writer: *std.Io.Writer, value: anytype) !void {
    try record(writer, value);
    try record(writer, value.toColorf32());
}
fn run(comptime T: type, writer: *std.Io.Writer, args: [6]u32) !void {
    var original: T = .{ .value = scalar(@FieldType(T, "value"), args[3]) };
    if (@hasField(T, "alpha") and args[0] == 1) original.alpha = scalar(@FieldType(T, "alpha"), args[4]);
    var copy = original;
    var returned = original;
    switch (args[1]) {
        0 => {},
        1 => copy = changed(copy, args[2], args[5]),
        2 => original = changed(original, args[2], args[5]),
        3 => {
            copy = changed(copy, args[2], args[5]);
            returned = changed(copy, args[2], args[3]);
            copy = original;
        },
        else => unreachable,
    }
    try observe(writer, original);
    try observe(writer, copy);
    try observe(writer, returned);
}
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const argv = try std.process.argsAlloc(allocator);
    // Source rejects oversized channels while constructing its sub-byte record.
    // V uses a wider carrier and checks it at the conversion call instead.
    if (std.mem.eql(u8, argv[1], "trap")) {
        const kind = try std.fmt.parseInt(u8, argv[2], 10);
        const raw = try std.fmt.parseInt(u8, argv[3], 10);
        const result = switch (kind) {
            0 => (c.Grayscale1{ .value = @intCast(raw) }).toColorf32(),
            1 => (c.Grayscale2{ .value = @intCast(raw) }).toColorf32(),
            2 => (c.Grayscale4{ .value = @intCast(raw) }).toColorf32(),
            else => unreachable,
        };
        std.debug.print("UNEXPECTED {d}\n", .{result.r});
        return;
    }
    const contents = try std.fs.cwd().readFileAlloc(allocator, argv[1], 16 * 1024 * 1024);
    var lines = std.mem.tokenizeScalar(u8, contents, '\n');
    var buffer: [64 * 1024]u8 = undefined;
    var output = std.fs.File.stdout().writer(&buffer);
    const writer = &output.interface;
    while (lines.next()) |line| {
        var parts = std.mem.splitScalar(u8, line, '|');
        const kind = try std.fmt.parseInt(u8, parts.next().?, 10);
        var args: [6]u32 = undefined;
        for (&args) |*value| value.* = try std.fmt.parseInt(u32, parts.next().?, 10);
        inline for (.{ c.Grayscale1, c.Grayscale2, c.Grayscale4, c.Grayscale8, c.Grayscale16, c.Grayscale8Alpha, c.Grayscale16Alpha, c.Grayscalef32, c.Grayscalef32Alpha }, 0..) |T, index| {
            if (kind == index) try run(T, writer, args);
        }
        try writer.writeByte('\n');
    }
    try writer.flush();
}
