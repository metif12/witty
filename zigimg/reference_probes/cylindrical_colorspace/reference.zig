const std = @import("std");
const color = @import("src/color.zig");
fn emit(writer: *std.Io.Writer, value: f32, canonical: bool) !void {
    const raw: u32 = if (canonical and std.math.isNan(value)) 0x7fc00000 else @bitCast(value);
    try writer.print("{d},", .{raw});
}
fn rgba(writer: *std.Io.Writer, value: color.Colorf32) !void {
    try emit(writer, value.r, true);
    try emit(writer, value.g, true);
    try emit(writer, value.b, true);
    try emit(writer, value.a, true);
}
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    const contents = try std.fs.cwd().readFileAlloc(allocator, args[1], 16 * 1024 * 1024);
    var lines = std.mem.tokenizeScalar(u8, contents, '\n');
    var buffer: [64 * 1024]u8 = undefined;
    var output = std.fs.File.stdout().writer(&buffer);
    const writer = &output.interface;
    const presets = [_]color.RgbColorspace{ color.BT601_NTSC, color.BT601_PAL, color.BT709, color.sRGB, color.DCIP3.Display, color.DCIP3.Theater, color.DCIP3.ACES, color.BT2020, color.AdobeRGB, color.AdobeWideGamutRGB, color.ProPhotoRGB, color.RgbColorspace.init(.{}) };
    while (lines.next()) |line| {
        var parts = std.mem.splitScalar(u8, line, '|');
        const space = presets[try std.fmt.parseInt(usize, parts.next().?, 10)];
        const kind = try std.fmt.parseInt(u8, parts.next().?, 10);
        const alpha = try std.fmt.parseInt(u8, parts.next().?, 10) != 0;
        const behavior: color.RgbColorspace.PostConversionBehavior = if (try std.fmt.parseInt(u8, parts.next().?, 10) == 0) .none else .clamp;
        var values: [4]f32 = undefined;
        for (&values) |*value| value.* = @bitCast(try std.fmt.parseInt(u32, parts.next().?, 10));
        const result = switch (kind) {
            0 => if (alpha) space.fromLCHabAlpha(.{ .l = values[0], .c = values[1], .h = values[2], .alpha = values[3] }, behavior) else space.fromLCHab(.{ .l = values[0], .c = values[1], .h = values[2] }, behavior),
            1 => if (alpha) space.fromLCHuvAlpha(.{ .l = values[0], .c = values[1], .h = values[2], .alpha = values[3] }, behavior) else space.fromLCHuv(.{ .l = values[0], .c = values[1], .h = values[2] }, behavior),
            2 => if (alpha) space.fromOkLChAlpha(.{ .l = values[0], .c = values[1], .h = values[2], .alpha = values[3] }, behavior) else space.fromOkLCh(.{ .l = values[0], .c = values[1], .h = values[2] }, behavior),
            else => return error.InvalidKind,
        };
        try rgba(writer, result);
        // Conversion must leave every caller input bit unchanged.
        for (values) |value| try emit(writer, value, false);
        try writer.writeByte('\n');
    }
    try writer.flush();
}
