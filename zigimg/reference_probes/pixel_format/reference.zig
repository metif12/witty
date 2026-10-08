const std = @import("std");
const p = @import("src/pixel_format.zig");
const W = std.Io.Writer;
const formats = [_]p.PixelFormat{ .invalid, .indexed1, .indexed2, .indexed4, .indexed8, .indexed16, .grayscale1, .grayscale2, .grayscale4, .grayscale8, .grayscale16, .grayscale8Alpha, .grayscale16Alpha, .rgb332, .rgb555, .rgb565, .rgb24, .rgba32, .bgr555, .bgr24, .bgra32, .rgb48, .rgba64, .float32 };
const packed_values = blk: {
    @setEvalBranchQuota(10000);
    var values: [1024]u32 = undefined;
    for (0..values.len) |index| {
        const info: p.PixelFormatInfo = .{
            .bits_per_channel = @truncate(index * 37),
            .channel_count = @truncate(index / 4),
            .variant = @enumFromInt(@as(u4, @truncate(index / 64))),
            .padding = @truncate(index * 257),
        };
        values[index] = p.toPixelFormatValue(info);
    }
    break :blk values;
};

fn writeInfo(out: *W, value: p.PixelFormatInfo) !void {
    try out.print("{d}|{d},{d},{d},{d}", .{ @as(u32, @bitCast(value)), value.bits_per_channel, value.channel_count, @intFromEnum(value.variant), value.padding });
}
fn record(out: *W, fields: []const []const u8) !void {
    const raw = try std.fmt.parseInt(u32, fields[1], 10);
    if (fields[0][0] == 'F') {
        const f: p.PixelFormat = @enumFromInt(raw);
        const copied: p.PixelFormat = @enumFromInt(@as(u32, @bitCast(f.info())));
        try out.print("F|{d}|", .{@intFromEnum(copied)});
        try writeInfo(out, f.info());
        try out.print("|{d},{d},{d},{d},{d}|{d}|{d}|", .{ @intFromBool(f.isGrayscale()), @intFromBool(f.isIndexed()), @intFromBool(f.isStandardRgb()), @intFromBool(f.isRgba()), @intFromBool(f.is16Bit()), f.pixelStride(), f.channelCount() });
        if (f == .rgb332 or f == .rgb565) try out.writeAll("-") else try out.print("{d}", .{f.bitsPerChannel()});
    } else {
        // All backing bits form valid PixelFormatInfo values: its variant is non-exhaustive.
        var value: p.PixelFormatInfo = @bitCast(raw);
        const copied = value;
        const borrowed: *u32 = @ptrCast(&value);
        try out.writeAll("I|");
        try writeInfo(out, value);
        const mutation = try std.fmt.parseInt(u32, fields[2], 10);
        borrowed.* = mutation;
        try out.writeAll("|");
        try writeInfo(out, value);
        try out.writeAll("|");
        try writeInfo(out, copied);
    }
    try out.writeAll("\n");
}
fn defaults(out: *W) !void {
    var value: p.PixelFormatInfo = .{};
    try out.writeAll("D|");
    try writeInfo(out, value);
    value.bits_per_channel = 201;
    value.channel_count = 15;
    value.variant = @enumFromInt(15);
    value.padding = 65535;
    try out.writeAll("|");
    try writeInfo(out, value);
    const copied = value;
    value.bits_per_channel = 0;
    value.channel_count = 0;
    value.variant = .none;
    value.padding = 0;
    try out.writeAll("|");
    try writeInfo(out, value);
    try out.writeAll("|");
    try writeInfo(out, copied);
    try out.print("|{d}|{d},{d}\n", .{ p.toPixelFormatValue(.{}), @sizeOf(p.PixelFormatInfo), @alignOf(p.PixelFormatInfo) });
    for (packed_values, 0..) |raw, index| try out.print("P|{d}|{d}\n", .{ index, raw });
    for (formats, 0..) |format, index| try out.print("V|{d}|{d}\n", .{ index, @intFromEnum(format.info().variant) });
}
pub fn main() !void {
    const a = std.heap.page_allocator;
    const args = try std.process.argsAlloc(a);
    if (args.len > 2 and std.mem.eql(u8, args[1], "--trap")) {
        const f: p.PixelFormat = if (std.mem.eql(u8, args[2], "rgb332")) .rgb332 else .rgb565;
        std.mem.doNotOptimizeAway(f.bitsPerChannel());
        @panic("UNEXPECTED returned bitsPerChannel");
    }
    var buffer: [65536]u8 = undefined;
    var output = std.fs.File.stdout().writer(&buffer);
    try defaults(&output.interface);
    const contents = try std.fs.cwd().readFileAlloc(a, args[1], 128 * 1024 * 1024);
    var lines = std.mem.tokenizeScalar(u8, contents, '\n');
    while (lines.next()) |line| {
        var fields: [3][]const u8 = undefined;
        var count: usize = 0;
        var parts = std.mem.splitScalar(u8, line, '|');
        while (parts.next()) |field| {
            fields[count] = field;
            count += 1;
        }
        try record(&output.interface, fields[0..count]);
    }
    try output.interface.flush();
}
