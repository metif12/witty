const std = @import("std");
const color = @import("src/color.zig");

const AliasRgb332 = color.Rgb332;
const AliasRgb555 = color.Rgb555;
const AliasRgb565 = color.Rgb565;
const AliasBgr555 = color.Bgr555;
const AliasGray2 = color.Grayscale2;

const CustomTarget = struct {
    value: u8,
    pub const from = struct {
        pub fn color(_: anytype) CustomTarget { return .{ .value = 17 }; }
    };
};
const TaggedTarget = struct {
    value: u64,
    pub const from = struct {
        pub fn color(value: anytype) TaggedTarget { return .{ .value = value.to.u64Rgba() ^ 0xfedcba9876543210 }; }
    };
};

fn emitFloat(writer: *std.Io.Writer, value: f32) !void {
    const bits: u32 = if (std.math.isNan(value)) 0x7fc00000 else @bitCast(value);
    try writer.print("{d},", .{bits});
}
fn emitDouble(writer: *std.Io.Writer, value: f64) !void {
    const bits: u64 = if (std.math.isNan(value)) 0x7ff8000000000000 else @bitCast(value);
    try writer.print("{d},", .{bits});
}
fn emit(comptime T: type, writer: *std.Io.Writer, value: T) !void {
    try writer.print("{d},{d},{d},{d},", .{ value.to.u32Rgba(), value.to.u32Rgb(), value.to.u64Rgba(), value.to.u64Rgb() });
    for (0..4) |index| try emitFloat(writer, value.to.float4()[index]);
    const premultiplied = value.to.premultipliedAlpha();
    try writer.print("{d},{d},", .{ premultiplied.to.u32Rgba(), premultiplied.to.u64Rgba() });
    for (0..4) |index| try emitFloat(writer, premultiplied.to.float4()[index]);
}
fn array(comptime T: type, writer: *std.Io.Writer, value: T) !void {
    if (T == color.Rgb332 or T == color.Rgb565) return;
    const values = value.to.array();
    for (values) |channel| {
        if (T == color.Colorf32) try emitFloat(writer, channel)
        else try writer.print("{d},", .{channel});
    }
    try emit(T, writer, T.from.array(values));
}
fn constructors(comptime T: type, writer: *std.Io.Writer, value: T) !void {
    try emit(T, writer, T.from.rgb(value.r, value.g, value.b));
    const alpha = if (@hasField(T, "a")) value.a else {};
    try emit(T, writer, T.from.rgba(value.r, value.g, value.b, alpha));
    try array(T, writer, value);
}
fn converted(comptime S: type, writer: *std.Io.Writer, value: S) !void {
    try emit(color.Rgb332, writer, value.to.color(color.Rgb332));
    try emit(color.Rgb555, writer, value.to.color(color.Rgb555));
    try emit(color.Rgb565, writer, value.to.color(color.Rgb565));
    try emit(color.Bgr555, writer, value.to.color(color.Bgr555));
    try emit(color.Rgb24, writer, value.to.color(color.Rgb24));
    try emit(color.Rgba32, writer, value.to.color(color.Rgba32));
    try emit(color.Bgr24, writer, value.to.color(color.Bgr24));
    try emit(color.Bgra32, writer, value.to.color(color.Bgra32));
    try emit(color.Rgb48, writer, value.to.color(color.Rgb48));
    try emit(color.Rgba64, writer, value.to.color(color.Rgba64));
    try emit(color.Colorf32, writer, value.to.color(color.Colorf32));
}
fn gray(comptime S: type, writer: *std.Io.Writer, value: S) !void {
    try emit(color.Rgb332, writer, color.Rgb332.from.grayscale(value));
    try emit(color.Rgb555, writer, color.Rgb555.from.grayscale(value));
    try emit(color.Rgb565, writer, color.Rgb565.from.grayscale(value));
    try emit(color.Bgr555, writer, color.Bgr555.from.grayscale(value));
    try emit(color.Rgb24, writer, color.Rgb24.from.grayscale(value));
    try emit(color.Rgba32, writer, color.Rgba32.from.grayscale(value));
    try emit(color.Bgr24, writer, color.Bgr24.from.grayscale(value));
    try emit(color.Bgra32, writer, color.Bgra32.from.grayscale(value));
    try emit(color.Rgb48, writer, color.Rgb48.from.grayscale(value));
    try emit(color.Rgba64, writer, color.Rgba64.from.grayscale(value));
    try emit(color.Colorf32, writer, color.Colorf32.from.grayscale(value));
}
fn scale(comptime I: type, writer: *std.Io.Writer, value: I) !void {
    inline for (.{u8, u16, u32, u64}) |O| try writer.print("{d},", .{color.ScaleValue(O)(value)});
    try emitFloat(writer, color.ScaleValue(f32)(value));
    try emitDouble(writer, color.ScaleValue(f64)(value));
}
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    const contents = try std.fs.cwd().readFileAlloc(allocator, args[1], 32 * 1024 * 1024);
    var lines = std.mem.tokenizeScalar(u8, contents, '\n');
    var output = std.fs.File.stdout().writer(&.{});
    const writer = &output.interface;
    while (lines.next()) |line| {
        var parts = std.mem.splitScalar(u8, line, '|');
        const mode = try std.fmt.parseInt(u8, parts.next().?, 10);
        if (mode == 5) {
            const text = parts.next().?;
            if (color.Rgb24.from.htmlHex(text)) |value| { try emit(color.Rgb24, writer, value); } else |_| { try writer.writeAll("InvalidHtmlHexString,"); }
            if (color.Rgba32.from.htmlHex(text)) |value| { try emit(color.Rgba32, writer, value); } else |_| { try writer.writeAll("InvalidHtmlHexString,"); }
            if (color.Bgr24.from.htmlHex(text)) |value| { try emit(color.Bgr24, writer, value); } else |_| { try writer.writeAll("InvalidHtmlHexString,"); }
            if (color.Bgra32.from.htmlHex(text)) |value| { try emit(color.Bgra32, writer, value); } else |_| { try writer.writeAll("InvalidHtmlHexString,"); }
            try writer.writeByte('\n');
            continue;
        }
        var inputs: [4]u64 = undefined;
        for (&inputs) |*value| value.* = try std.fmt.parseInt(u64, parts.next().?, 10);
        var values: [4]f32 = undefined;
        for (&values, inputs) |*value, bits| value.* = @bitCast(@as(u32, @truncate(bits)));
        switch (mode) {
            0 => {
                const value = inputs[0];
                try emit(color.Rgb332, writer, color.Rgb332.from.u32Rgba(@as(u32, @truncate(value))));
                try emit(color.Rgb332, writer, color.Rgb332.from.u32Rgb(@as(u32, @truncate(value))));
                try emit(color.Rgb332, writer, color.Rgb332.from.u64Rgba(value));
                try emit(color.Rgb332, writer, color.Rgb332.from.u64Rgb(value));
                try emit(color.Rgb555, writer, color.Rgb555.from.u32Rgba(@as(u32, @truncate(value))));
                try emit(color.Rgb555, writer, color.Rgb555.from.u32Rgb(@as(u32, @truncate(value))));
                try emit(color.Rgb555, writer, color.Rgb555.from.u64Rgba(value));
                try emit(color.Rgb555, writer, color.Rgb555.from.u64Rgb(value));
                try emit(color.Rgb565, writer, color.Rgb565.from.u32Rgba(@as(u32, @truncate(value))));
                try emit(color.Rgb565, writer, color.Rgb565.from.u32Rgb(@as(u32, @truncate(value))));
                try emit(color.Rgb565, writer, color.Rgb565.from.u64Rgba(value));
                try emit(color.Rgb565, writer, color.Rgb565.from.u64Rgb(value));
                try emit(color.Bgr555, writer, color.Bgr555.from.u32Rgba(@as(u32, @truncate(value))));
                try emit(color.Bgr555, writer, color.Bgr555.from.u32Rgb(@as(u32, @truncate(value))));
                try emit(color.Bgr555, writer, color.Bgr555.from.u64Rgba(value));
                try emit(color.Bgr555, writer, color.Bgr555.from.u64Rgb(value));
                try emit(color.Rgb24, writer, color.Rgb24.from.u32Rgba(@as(u32, @truncate(value))));
                try emit(color.Rgb24, writer, color.Rgb24.from.u32Rgb(@as(u32, @truncate(value))));
                try emit(color.Rgb24, writer, color.Rgb24.from.u64Rgba(value));
                try emit(color.Rgb24, writer, color.Rgb24.from.u64Rgb(value));
                try emit(color.Rgba32, writer, color.Rgba32.from.u32Rgba(@as(u32, @truncate(value))));
                try emit(color.Rgba32, writer, color.Rgba32.from.u32Rgb(@as(u32, @truncate(value))));
                try emit(color.Rgba32, writer, color.Rgba32.from.u64Rgba(value));
                try emit(color.Rgba32, writer, color.Rgba32.from.u64Rgb(value));
                try emit(color.Bgr24, writer, color.Bgr24.from.u32Rgba(@as(u32, @truncate(value))));
                try emit(color.Bgr24, writer, color.Bgr24.from.u32Rgb(@as(u32, @truncate(value))));
                try emit(color.Bgr24, writer, color.Bgr24.from.u64Rgba(value));
                try emit(color.Bgr24, writer, color.Bgr24.from.u64Rgb(value));
                try emit(color.Bgra32, writer, color.Bgra32.from.u32Rgba(@as(u32, @truncate(value))));
                try emit(color.Bgra32, writer, color.Bgra32.from.u32Rgb(@as(u32, @truncate(value))));
                try emit(color.Bgra32, writer, color.Bgra32.from.u64Rgba(value));
                try emit(color.Bgra32, writer, color.Bgra32.from.u64Rgb(value));
                try emit(color.Rgb48, writer, color.Rgb48.from.u32Rgba(@as(u32, @truncate(value))));
                try emit(color.Rgb48, writer, color.Rgb48.from.u32Rgb(@as(u32, @truncate(value))));
                try emit(color.Rgb48, writer, color.Rgb48.from.u64Rgba(value));
                try emit(color.Rgb48, writer, color.Rgb48.from.u64Rgb(value));
                try emit(color.Rgba64, writer, color.Rgba64.from.u32Rgba(@as(u32, @truncate(value))));
                try emit(color.Rgba64, writer, color.Rgba64.from.u32Rgb(@as(u32, @truncate(value))));
                try emit(color.Rgba64, writer, color.Rgba64.from.u64Rgba(value));
                try emit(color.Rgba64, writer, color.Rgba64.from.u64Rgb(value));
                try emit(color.Colorf32, writer, color.Colorf32.from.u32Rgba(@as(u32, @truncate(value))));
                try emit(color.Colorf32, writer, color.Colorf32.from.u32Rgb(@as(u32, @truncate(value))));
                try emit(color.Colorf32, writer, color.Colorf32.from.u64Rgba(value));
                try emit(color.Colorf32, writer, color.Colorf32.from.u64Rgb(value));
            },
            1 => {
                try emit(color.Rgb332, writer, color.Rgb332.from.float4(values));
                try emit(color.Rgb555, writer, color.Rgb555.from.float4(values));
                try emit(color.Rgb565, writer, color.Rgb565.from.float4(values));
                try emit(color.Bgr555, writer, color.Bgr555.from.float4(values));
                try emit(color.Rgb24, writer, color.Rgb24.from.float4(values));
                try emit(color.Rgba32, writer, color.Rgba32.from.float4(values));
                try emit(color.Bgr24, writer, color.Bgr24.from.float4(values));
                try emit(color.Bgra32, writer, color.Bgra32.from.float4(values));
                try emit(color.Rgb48, writer, color.Rgb48.from.float4(values));
                try emit(color.Rgba64, writer, color.Rgba64.from.float4(values));
                try emit(color.Colorf32, writer, color.Colorf32.from.float4(values));
            },
            2 => switch (inputs[0]) {
                0 => try gray(color.Grayscale1, writer, .{ .value = @as(u1, @truncate(inputs[1])) }),
                1 => try gray(color.Grayscale2, writer, .{ .value = @as(u2, @truncate(inputs[1])) }),
                2 => try gray(color.Grayscale4, writer, .{ .value = @as(u4, @truncate(inputs[1])) }),
                3 => try gray(color.Grayscale8, writer, .{ .value = @as(u8, @truncate(inputs[1])) }),
                4 => try gray(color.Grayscale16, writer, .{ .value = @as(u16, @truncate(inputs[1])) }),
                5 => try gray(color.Grayscale8Alpha, writer, .{ .value = @as(u8, @truncate(inputs[1])), .alpha = @as(u8, @truncate(inputs[2])) }),
                6 => try gray(color.Grayscale16Alpha, writer, .{ .value = @as(u16, @truncate(inputs[1])), .alpha = @as(u16, @truncate(inputs[2])) }),
                7 => try gray(color.Grayscalef32, writer, .{ .value = values[1] }),
                8 => try gray(color.Grayscalef32Alpha, writer, .{ .value = values[1], .alpha = values[2] }),
                else => return error.InvalidGray,
            },
            3 => switch (inputs[0]) {
                0 => try converted(color.Rgb332, writer, color.Rgb332.from.u64Rgba(inputs[1])),
                1 => try converted(color.Rgb555, writer, color.Rgb555.from.u64Rgba(inputs[1])),
                2 => try converted(color.Rgb565, writer, color.Rgb565.from.u64Rgba(inputs[1])),
                3 => try converted(color.Bgr555, writer, color.Bgr555.from.u64Rgba(inputs[1])),
                4 => try converted(color.Rgb24, writer, color.Rgb24.from.u64Rgba(inputs[1])),
                5 => try converted(color.Rgba32, writer, color.Rgba32.from.u64Rgba(inputs[1])),
                6 => try converted(color.Bgr24, writer, color.Bgr24.from.u64Rgba(inputs[1])),
                7 => try converted(color.Bgra32, writer, color.Bgra32.from.u64Rgba(inputs[1])),
                8 => try converted(color.Rgb48, writer, color.Rgb48.from.u64Rgba(inputs[1])),
                9 => try converted(color.Rgba64, writer, color.Rgba64.from.u64Rgba(inputs[1])),
                10 => try converted(color.Colorf32, writer, color.Colorf32.from.u64Rgba(inputs[1])),
                else => return error.InvalidColor,
            },
            4 => {
                inline for (.{u8, u16, u32, u64}) |I| try scale(I, writer, @as(I, @truncate(inputs[0])));
                inline for (.{u8, u16}) |O| {
                    try writer.print("{d},", .{color.ScaleValue(O)(values[1])});
                    try writer.print("{d},", .{color.ScaleValue(O)(@as(f64, @bitCast(inputs[2])))});
                }
                try emitFloat(writer, color.ScaleValue(f32)(values[1]));
                try emitDouble(writer, color.ScaleValue(f64)(values[1]));
                try emitFloat(writer, color.ScaleValue(f32)(@as(f64, @bitCast(inputs[2]))));
                try emitDouble(writer, color.ScaleValue(f64)(@as(f64, @bitCast(inputs[2]))));
            },
            6 => {
                try constructors(color.Rgb332, writer, color.Rgb332.from.u64Rgba(inputs[0]));
                try constructors(color.Rgb555, writer, color.Rgb555.from.u64Rgba(inputs[0]));
                try constructors(color.Rgb565, writer, color.Rgb565.from.u64Rgba(inputs[0]));
                try constructors(color.Bgr555, writer, color.Bgr555.from.u64Rgba(inputs[0]));
                try constructors(color.Rgb24, writer, color.Rgb24.from.u64Rgba(inputs[0]));
                try constructors(color.Rgba32, writer, color.Rgba32.from.u64Rgba(inputs[0]));
                try constructors(color.Bgr24, writer, color.Bgr24.from.u64Rgba(inputs[0]));
                try constructors(color.Bgra32, writer, color.Bgra32.from.u64Rgba(inputs[0]));
                try constructors(color.Rgb48, writer, color.Rgb48.from.u64Rgba(inputs[0]));
                try constructors(color.Rgba64, writer, color.Rgba64.from.u64Rgba(inputs[0]));
                try constructors(color.Colorf32, writer, color.Colorf32.from.u64Rgba(inputs[0]));
            },
            7 => {
                switch (inputs[0]) {
                    3 => try emit(color.Rgb555, writer, color.Rgb555.from.rgb(@intCast(inputs[1]), 0, 0)),
                    4 => try emit(color.Rgb332, writer, color.Rgb332.from.rgb(0, 0, @intCast(inputs[1]))),
                    5 => try emit(color.Rgb555, writer, color.Rgb555.from.array(.{ 0, 0, 0, @intCast(inputs[1]) })),
                    6 => try gray(color.Grayscale2, writer, .{ .value = @intCast(inputs[1]) }),
                    else => return error.InvalidTrap,
                }
            },
            8 => {
                const mixed = .{ .r = @as(u8, @truncate(inputs[0])), .g = @as(u16, @truncate(inputs[1])), .b = @as(f64, @bitCast(inputs[2])), .a = values[3] };
                const ignored = .{ .r = mixed.r, .g = mixed.g, .b = mixed.b, .a = "unused" };
                const ignored_gray = .{ .value = mixed.b, .alpha = "unused" };
                try emit(color.Rgb332, writer, color.Rgb332.from.color(mixed));
                try emit(color.Rgb555, writer, color.Rgb555.from.color(mixed));
                try emit(color.Rgb565, writer, color.Rgb565.from.color(mixed));
                try emit(color.Bgr555, writer, color.Bgr555.from.color(mixed));
                try emit(color.Rgb24, writer, color.Rgb24.from.color(mixed));
                try emit(color.Rgba32, writer, color.Rgba32.from.color(mixed));
                try emit(color.Bgr24, writer, color.Bgr24.from.color(mixed));
                try emit(color.Bgra32, writer, color.Bgra32.from.color(mixed));
                try emit(color.Rgb48, writer, color.Rgb48.from.color(mixed));
                try emit(color.Rgba64, writer, color.Rgba64.from.color(mixed));
                try emit(color.Colorf32, writer, color.Colorf32.from.color(mixed));
                try emit(color.Rgb332, writer, color.Rgb332.from.color(ignored));
                try emit(color.Rgb332, writer, color.Rgb332.from.grayscale(ignored_gray));
                try emit(color.Rgb555, writer, color.Rgb555.from.color(ignored));
                try emit(color.Rgb555, writer, color.Rgb555.from.grayscale(ignored_gray));
                try emit(color.Rgb565, writer, color.Rgb565.from.color(ignored));
                try emit(color.Rgb565, writer, color.Rgb565.from.grayscale(ignored_gray));
                try emit(color.Bgr555, writer, color.Bgr555.from.color(ignored));
                try emit(color.Bgr555, writer, color.Bgr555.from.grayscale(ignored_gray));
                try emit(color.Rgb24, writer, color.Rgb24.from.color(ignored));
                try emit(color.Rgb24, writer, color.Rgb24.from.grayscale(ignored_gray));
                try emit(color.Bgr24, writer, color.Bgr24.from.color(ignored));
                try emit(color.Bgr24, writer, color.Bgr24.from.grayscale(ignored_gray));
                try emit(color.Rgb48, writer, color.Rgb48.from.color(ignored));
                try emit(color.Rgb48, writer, color.Rgb48.from.grayscale(ignored_gray));
            },
            9 => {
                {
                    const value = color.Rgb332.from.u64Rgba(inputs[0]);
                    try writer.print("{d},{d},", .{ value.to.color(CustomTarget).value, value.to.color(TaggedTarget).value });
                }
                {
                    const value = color.Rgb555.from.u64Rgba(inputs[0]);
                    try writer.print("{d},{d},", .{ value.to.color(CustomTarget).value, value.to.color(TaggedTarget).value });
                }
                {
                    const value = color.Rgb565.from.u64Rgba(inputs[0]);
                    try writer.print("{d},{d},", .{ value.to.color(CustomTarget).value, value.to.color(TaggedTarget).value });
                }
                {
                    const value = color.Bgr555.from.u64Rgba(inputs[0]);
                    try writer.print("{d},{d},", .{ value.to.color(CustomTarget).value, value.to.color(TaggedTarget).value });
                }
                {
                    const value = color.Rgb24.from.u64Rgba(inputs[0]);
                    try writer.print("{d},{d},", .{ value.to.color(CustomTarget).value, value.to.color(TaggedTarget).value });
                }
                {
                    const value = color.Rgba32.from.u64Rgba(inputs[0]);
                    try writer.print("{d},{d},", .{ value.to.color(CustomTarget).value, value.to.color(TaggedTarget).value });
                }
                {
                    const value = color.Bgr24.from.u64Rgba(inputs[0]);
                    try writer.print("{d},{d},", .{ value.to.color(CustomTarget).value, value.to.color(TaggedTarget).value });
                }
                {
                    const value = color.Bgra32.from.u64Rgba(inputs[0]);
                    try writer.print("{d},{d},", .{ value.to.color(CustomTarget).value, value.to.color(TaggedTarget).value });
                }
                {
                    const value = color.Rgb48.from.u64Rgba(inputs[0]);
                    try writer.print("{d},{d},", .{ value.to.color(CustomTarget).value, value.to.color(TaggedTarget).value });
                }
                {
                    const value = color.Rgba64.from.u64Rgba(inputs[0]);
                    try writer.print("{d},{d},", .{ value.to.color(CustomTarget).value, value.to.color(TaggedTarget).value });
                }
                {
                    const value = color.Colorf32.from.u64Rgba(inputs[0]);
                    try writer.print("{d},{d},", .{ value.to.color(CustomTarget).value, value.to.color(TaggedTarget).value });
                }
            },
            10 => {
                {
                    const value = AliasRgb332.from.u64Rgba(inputs[0]);
                    try emit(color.Rgba32, writer, color.Rgba32.from.color(value));
                    try emit(color.Rgba32, writer, value.to.color(color.Rgba32));
                    try emit(AliasBgr555, writer, value.to.color(AliasBgr555));
                    try emit(AliasBgr555, writer, AliasBgr555.from.color(value));
                }
                {
                    const value = AliasRgb555.from.u64Rgba(inputs[0]);
                    try emit(color.Rgba32, writer, color.Rgba32.from.color(value));
                    try emit(color.Rgba32, writer, value.to.color(color.Rgba32));
                    try emit(AliasBgr555, writer, value.to.color(AliasBgr555));
                    try emit(AliasBgr555, writer, AliasBgr555.from.color(value));
                }
                {
                    const value = AliasRgb565.from.u64Rgba(inputs[0]);
                    try emit(color.Rgba32, writer, color.Rgba32.from.color(value));
                    try emit(color.Rgba32, writer, value.to.color(color.Rgba32));
                    try emit(AliasBgr555, writer, value.to.color(AliasBgr555));
                    try emit(AliasBgr555, writer, AliasBgr555.from.color(value));
                }
                {
                    const value = AliasBgr555.from.u64Rgba(inputs[0]);
                    try emit(color.Rgba32, writer, color.Rgba32.from.color(value));
                    try emit(color.Rgba32, writer, value.to.color(color.Rgba32));
                    try emit(AliasBgr555, writer, value.to.color(AliasBgr555));
                    try emit(AliasBgr555, writer, AliasBgr555.from.color(value));
                }
                const arr: [4]u5 = .{ @truncate(inputs[0]), @truncate(inputs[0] >> 5), @truncate(inputs[0] >> 10), @truncate(inputs[0] >> 15) };
                try emit(AliasBgr555, writer, AliasBgr555.from.array(arr));
                try emit(color.Rgba32, writer, color.Rgba32.from.grayscale(AliasGray2{ .value = @truncate(inputs[0]) }));
            },
            else => return error.InvalidMode,
        }
        try writer.writeByte('\n');
    }
}
