const std = @import("std");
const color = @import("src/color.zig");
const Colors = @import("src/predefined_colors.zig").Colors;

fn emit(writer: *std.Io.Writer, value: f32) !void {
    const bits: u32 = if (std.math.isNan(value)) 0x7fc00000 else @bitCast(value);
    try writer.print("{d},", .{bits});
}

fn rgb(writer: *std.Io.Writer, value: color.Colorf32) !void {
    try emit(writer, value.r);
    try emit(writer, value.g);
    try emit(writer, value.b);
    try emit(writer, value.a);
}

fn hsl(writer: *std.Io.Writer, value: color.Hsl) !void {
    try emit(writer, value.hue);
    try emit(writer, value.saturation);
    try emit(writer, value.luminance);
}

fn hsv(writer: *std.Io.Writer, value: color.Hsv) !void {
    try emit(writer, value.hue);
    try emit(writer, value.saturation);
    try emit(writer, value.value);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    const contents = try std.fs.cwd().readFileAlloc(allocator, args[1], 16 * 1024 * 1024);
    var lines = std.mem.tokenizeScalar(u8, contents, '\n');
    var output = std.fs.File.stdout().writer(&.{});
    const writer = &output.interface;
    while (lines.next()) |line| {
        var parts = std.mem.splitScalar(u8, line, '|');
        const mode = try std.fmt.parseInt(u8, parts.next().?, 10);
        var values: [4]f32 = undefined;
        for (&values) |*value| value.* = @bitCast(try std.fmt.parseInt(u32, parts.next().?, 10));
        switch (mode) {
            0 => {
                const value = color.Colorf32{ .r = values[0], .g = values[1], .b = values[2], .a = values[3] };
                const s = color.Hsl.fromRgb(value);
                try hsl(writer, s);
                try rgb(writer, s.toRgb());
                try hsv(writer, s.toHsv());
                const v = color.Hsv.fromRgb(value);
                try hsv(writer, v);
                try rgb(writer, v.toRgb());
                try hsl(writer, v.toHsl());
                const c = color.Cmykf32.fromColorf32(value);
                for ([_]f32{ c.c, c.m, c.y, c.k }) |channel| try emit(writer, channel);
                try rgb(writer, c.toColorF32());
                try rgb(writer, (color.Grayscalef32{ .value = values[0] }).toColorf32());
                try rgb(writer, (color.Grayscalef32Alpha{ .value = values[0], .alpha = values[3] }).toColorf32());
            },
            1 => {
                const s = color.Hsl{ .hue = values[0], .saturation = values[1], .luminance = values[2] };
                try rgb(writer, s.toRgb());
                try hsv(writer, s.toHsv());
                const v = color.Hsv{ .hue = values[0], .saturation = values[1], .value = values[2] };
                try rgb(writer, v.toRgb());
                try hsl(writer, v.toHsl());
            },
            2 => try rgb(writer, (color.Cmykf32{ .c = values[0], .m = values[1], .y = values[2], .k = values[3] }).toColorF32()),
            3 => {
                inline for (.{ color.Rgb24, color.Rgba32, color.Bgr24, color.Bgra32, color.Rgb48, color.Rgba64, color.Colorf32, color.Rgb332, color.Rgb555, color.Bgr555, color.Rgb565 }) |T| {
                    const C = Colors(T);
                    inline for (.{ C.Red, C.Green, C.Blue, C.White, C.Black, C.Cyan, C.Magenta, C.Yellow }) |value| {
                        const components = value.to.float4();
                        inline for (0..4) |channel| try emit(writer, components[channel]);
                    }
                }
            },
            else => return error.InvalidMode,
        }
        try writer.writeByte('\n');
    }
}
