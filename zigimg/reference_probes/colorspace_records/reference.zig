const std = @import("std");
const color = @import("src/color.zig");
const math = @import("src/math.zig");
var events: [12]u64 = undefined;
var event_count: usize = 0;
fn log(id: u32, value: f32) void {
    events[event_count] = (@as(u64, id) << 32) | @as(u32, @bitCast(value));
    event_count += 1;
}
fn cb0(x: f32) f32 {
    log(0, x);
    return x;
}
fn cb1(x: f32) f32 {
    log(1, x);
    return -x;
}
fn cb2(x: f32) f32 {
    log(2, x);
    return x + 1;
}
fn cb3(x: f32) f32 {
    log(3, x);
    return x * 2;
}
fn callback(index: usize) *const fn (f32) f32 {
    return switch (index % 4) {
        0 => cb0,
        1 => cb1,
        2 => cb2,
        else => cb3,
    };
}
fn emit(writer: *std.Io.Writer, value: f32, canonical: bool) !void {
    const raw: u32 = if (canonical and std.math.isNan(value)) 0x7fc00000 else @bitCast(value);
    try writer.print("{d},", .{raw});
}
fn matrix(seed: u8) math.float4x4 {
    var flat: [16]f32 = undefined;
    for (&flat, 0..) |*value, i| value.* = if (i % 5 == 0) 1 else @as(f32, @floatFromInt((i + seed) % 16)) / 16;
    return math.float4x4.fromArray(flat);
}
fn argsFor(seed: u8) color.RgbColorspace.InitArgs {
    return .{ .red = .{ .x = 0.64, .y = 0.33 }, .green = .{ .x = 0.3, .y = 0.6 }, .blue = .{ .x = 0.15, .y = 0.06 }, .white = .{ .x = 0.3127, .y = 0.3290 }, .to_gamma = callback(seed), .to_gamma_fast = callback(seed +% 1), .to_linear = callback(seed +% 2), .to_linear_fast = callback(seed +% 3) };
}
fn direct(args: color.RgbColorspace.InitArgs, seed: u8) color.RgbColorspace {
    return .{ .red = args.red, .green = args.green, .blue = args.blue, .white = args.white, .rgba_to_xyza = matrix(seed), .xyza_to_rgba = matrix(seed +% 1), .to_gamma = args.to_gamma, .to_gamma_fast = args.to_gamma_fast, .to_linear = args.to_linear, .to_linear_fast = args.to_linear_fast };
}
fn changed(value: color.RgbColorspace, field: u8, seed: u8, whole: bool) color.RgbColorspace {
    var result = value;
    const xy = color.CIExyY{ .x = @as(f32, @floatFromInt(seed)) / 256, .y = 0.5 };
    switch (field) {
        0 => result.red = xy,
        1 => result.green = xy,
        2 => result.blue = xy,
        3 => result.white = xy,
        4 => {
            if (whole) result.rgba_to_xyza = matrix(seed) else result.rgba_to_xyza.matrix[seed % 4][(seed / 4) % 4] = xy.x;
        },
        5 => {
            if (whole) result.xyza_to_rgba = matrix(seed) else result.xyza_to_rgba.matrix[seed % 4][(seed / 4) % 4] = xy.x;
        },
        6 => result.to_gamma = callback(seed),
        7 => result.to_gamma_fast = callback(seed),
        8 => result.to_linear = callback(seed),
        9 => result.to_linear_fast = callback(seed),
        else => unreachable,
    }
    return result;
}
fn observe(writer: *std.Io.Writer, space: color.RgbColorspace, value: color.Colorf32) !void {
    for ([_]color.CIExyY{ space.red, space.green, space.blue, space.white }) |xy| {
        try emit(writer, xy.x, false);
        try emit(writer, xy.y, false);
    }
    for ([_]math.float4x4{ space.rgba_to_xyza, space.xyza_to_rgba }) |m| for (m.matrix) |row| inline for (0..4) |i| try emit(writer, row[i], true);
    event_count = 0;
    const results = [_]color.Colorf32{ space.toGamma(value), space.toGammaFast(value), space.toLinear(value), space.toLinearFast(value) };
    for (results) |rgba| {
        try emit(writer, rgba.r, true);
        try emit(writer, rgba.g, true);
        try emit(writer, rgba.b, true);
        try emit(writer, rgba.a, false);
    }
    try writer.print("{d}:", .{event_count});
    for (events[0..event_count]) |event| try writer.print("{d},", .{event});
    try writer.writeByte(';');
}
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const argv = try std.process.argsAlloc(allocator);
    const contents = try std.fs.cwd().readFileAlloc(allocator, argv[1], 16 * 1024 * 1024);
    var lines = std.mem.tokenizeScalar(u8, contents, '\n');
    var buffer: [64 * 1024]u8 = undefined;
    var output = std.fs.File.stdout().writer(&buffer);
    const writer = &output.interface;
    while (lines.next()) |line| {
        var parts = std.mem.splitScalar(u8, line, '|');
        var controls: [4]u8 = undefined;
        for (&controls) |*v| v.* = try std.fmt.parseInt(u8, parts.next().?, 10);
        const form = controls[0];
        const operation = controls[1];
        const field = controls[2];
        const seed = controls[3];
        var pixel: [4]f32 = undefined;
        for (&pixel) |*v| v.* = @bitCast(try std.fmt.parseInt(u32, parts.next().?, 10));
        const value = color.Colorf32{ .r = pixel[0], .g = pixel[1], .b = pixel[2], .a = pixel[3] };
        var args = if (form == 2) color.RgbColorspace.InitArgs{} else argsFor(seed);
        var original = if (form == 0) direct(args, seed) else color.RgbColorspace.init(args);
        var copy = original;
        var returned = original;
        switch (operation) {
            0 => {},
            1 => copy = changed(copy, field, seed +% 1, false),
            2 => original = changed(original, field, seed +% 1, false),
            3 => {
                copy = changed(copy, field, seed +% 1, true);
                returned = changed(copy, (field + 1) % 10, seed +% 2, true);
            },
            4 => original = direct(argsFor(seed +% 1), seed +% 1),
            5 => {
                args.red.x = -99;
                args.to_gamma = callback(seed +% 1);
            },
            else => unreachable,
        }
        try observe(writer, original, value);
        try observe(writer, copy, value);
        try observe(writer, returned, value);
        try emit(writer, args.red.x, false);
        for (pixel) |v| try emit(writer, v, false);
        try writer.writeByte('\n');
    }
    try writer.flush();
}
