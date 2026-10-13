const std = @import("std");
const color = @import("src/color.zig");
const math = @import("src/math.zig");
fn emit(writer: *std.Io.Writer, value: f32, canonical: bool) !void {
    const raw: u32 = if (canonical and std.math.isNan(value)) 0x7fc00000 else @bitCast(value);
    try writer.print("{d},", .{raw});
}
fn record(writer: *std.Io.Writer, value: anytype, canonical: bool) !void {
    inline for (@typeInfo(@TypeOf(value)).@"struct".fields) |field| try emit(writer, @field(value, field.name), canonical);
}
fn changed(value: anytype, field: usize, raw: u32) @TypeOf(value) {
    var result = value;
    inline for (@typeInfo(@TypeOf(value)).@"struct".fields, 0..) |entry, index| {
        if (field == index) @field(result, entry.name) = @bitCast(raw);
    }
    return result;
}
fn copies(writer: *std.Io.Writer, original: anytype, field: usize) !void {
    var copy = changed(original, field, 0x7fc01234);
    const returned = changed(original, field, 0x80000000);
    try record(writer, original, false);
    try record(writer, copy, false);
    try record(writer, returned, false);
    copy = original;
    try record(writer, copy, false);
    try record(writer, original, false);
}
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    const contents = try std.fs.cwd().readFileAlloc(allocator, args[1], 16 * 1024 * 1024);
    var lines = std.mem.tokenizeScalar(u8, contents, '\n');
    var buffer: [64 * 1024]u8 = undefined;
    var output = std.fs.File.stdout().writer(&buffer);
    const writer = &output.interface;
    while (lines.next()) |line| {
        var parts = std.mem.splitScalar(u8, line, '|');
        const kind = try std.fmt.parseInt(u8, parts.next().?, 10);
        const field = try std.fmt.parseInt(usize, parts.next().?, 10);
        var values: [20]f32 = undefined;
        for (&values) |*value| value.* = @bitCast(try std.fmt.parseInt(u32, parts.next().?, 10));
        const plain = color.HSLuv{ .h = values[0], .s = values[1], .l = values[2] };
        const alpha = color.HSLuvAlpha{ .h = values[0], .s = values[1], .l = values[2], .alpha = values[3] };
        if (kind == 0) try copies(writer, plain, field) else try copies(writer, alpha, field);
        const matrix = math.float4x4.fromArray(values[4..20].*);
        const lch = color.CIELCHuv{ .l = values[2], .c = values[1], .h = values[0] };
        const lcha = color.CIELCHuvAlpha{ .l = values[2], .c = values[1], .h = values[0], .alpha = values[3] };
        try record(writer, color.HSLuv.fromCIELChuv(lch, matrix), true);
        try record(writer, color.HSLuvAlpha.fromCIELChuvAlpha(lcha, matrix), true);
        try record(writer, plain.toCIELCHuv(matrix), true);
        try record(writer, alpha.toCIELCHuvAlpha(matrix), true);
        try record(writer, alpha.toHSLuv(), false);
        const vector: math.float4 = values[0..4].*;
        const wrong_factory = color.HSLuvAlpha.fromFloat4(vector);
        try record(writer, wrong_factory, false);
        const roundtrip = color.HSLuvAlpha.toFloat4(wrong_factory);
        inline for (0..4) |index| try emit(writer, roundtrip[index], false);
        try record(writer, plain, false);
        try record(writer, alpha, false);
        try writer.writeByte('\n');
    }
    try writer.flush();
}
