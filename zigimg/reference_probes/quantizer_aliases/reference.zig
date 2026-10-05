const std = @import("std");
const color = @import("src/color.zig");
const Quantizer = @import("src/OctTreeQuantizer.zig");

const AliasRgb24 = color.Rgb24;
const AliasBgr24 = color.Bgr24;
const AliasRgb48 = color.Rgb48;
const AliasRgb332 = color.Rgb332;
const AliasRgb555 = color.Rgb555;
const AliasBgr555 = color.Bgr555;
const AliasRgb565 = color.Rgb565;
const AliasRgba32 = color.Rgba32;
const AliasBgra32 = color.Bgra32;
const AliasRgba64 = color.Rgba64;
const AliasColorf32 = color.Colorf32;

fn emit(writer: *std.Io.Writer, kind: u32, sample: u32, value: anytype) !void {
    var quantizer = Quantizer.init(std.heap.page_allocator);
    defer quantizer.deinit();
    try quantizer.addColor(value);
    try quantizer.addColor(value);
    var storage: [256]color.Rgba32 = undefined;
    const palette = quantizer.makePalette(256, &storage);
    const rgb = palette[0];
    const index = try quantizer.getPaletteIndex(value);
    const root_index = try quantizer.root_node.getPaletteIndex(value, 0);
    const Node = @TypeOf(quantizer.root_node);
    var node = Node{};
    try node.addColor(value, 8, &quantizer);
    try node.addColor(value, 100, &quantizer);
    const average = node.getColor();
    const leaf_index = try node.getPaletteIndex(value, 100);
    try writer.print("{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}\n", .{
        kind, sample, palette.len, rgb.r, rgb.g, rgb.b, rgb.a, index, root_index,
        average.r, average.g, average.b, average.a, node.reference_count, leaf_index, node.countLeafNodes(),
    });
}

fn sample16(value: u8, offset: u32) u16 {
    return @intCast(@min(@as(u32, value) * 257 + offset, 65535));
}

pub fn main() !void {
    var buffer: [4096]u8 = undefined;
    var output = std.fs.File.stdout().writer(&buffer);
    const writer = &output.interface;
    for (0..256) |i| {
        const sample: u32 = @intCast(i);
        const r: u8 = @truncate(sample);
        const g: u8 = @truncate(sample * 7);
        const b: u8 = @truncate(sample * 13);
        const a: u8 = @truncate(sample * 31);
        try emit(writer, 0, sample, AliasRgb24.from.rgb(r, g, b));
        try emit(writer, 1, sample, AliasBgr24.from.rgb(r, g, b));
        try emit(writer, 2, sample, AliasRgb48.from.rgb(sample16(r, 13), sample16(g, 17), sample16(b, 19)));
        try emit(writer, 3, sample, AliasRgb332.from.rgb(@as(u3, @truncate(r)), @as(u3, @truncate(g)), @as(u2, @truncate(b))));
        try emit(writer, 4, sample, AliasRgb555.from.rgb(@as(u5, @truncate(r)), @as(u5, @truncate(g)), @as(u5, @truncate(b))));
        try emit(writer, 5, sample, AliasBgr555.from.rgb(@as(u5, @truncate(r)), @as(u5, @truncate(g)), @as(u5, @truncate(b))));
        try emit(writer, 6, sample, AliasRgb565.from.rgb(@as(u5, @truncate(r)), @as(u6, @truncate(g)), @as(u5, @truncate(b))));
        try emit(writer, 7, sample, AliasRgba32.from.rgba(r, g, b, a));
        try emit(writer, 8, sample, AliasBgra32.from.rgba(r, g, b, a));
        try emit(writer, 9, sample, AliasRgba64.from.rgba(sample16(r, 13), sample16(g, 17), sample16(b, 19), sample16(a, 23)));
        const float_color = switch (sample) {
            254 => AliasColorf32.from.rgba(-2, std.math.nan(f32), std.math.inf(f32), 1),
            255 => AliasColorf32.from.rgba(-std.math.inf(f32), 0.5, 2, 0),
            else => AliasColorf32.from.rgba(@as(f32, @floatFromInt(r)) / 255, @as(f32, @floatFromInt(g)) / 255,
                @as(f32, @floatFromInt(b)) / 255, @as(f32, @floatFromInt(a)) / 255),
        };
        try emit(writer, 10, sample, float_color);
    }
    try writer.flush();
}
