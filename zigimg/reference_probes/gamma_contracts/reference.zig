const std = @import("std");
const c = @import("src/color.zig");
const data = @import("cases.zig");
const W = std.Io.Writer;
fn scalar(raw: u32) f32 {
    return @bitCast(raw);
}
fn params(comptime kind: usize) c.GammaFunctionsParameters {
    if (kind == 0) return .{};
    const v = data.raw_params[kind];
    return .{ .alpha = scalar(v[0]), .beta = scalar(v[1]), .delta = scalar(v[2]), .gamma = scalar(v[3]), .transition_point = scalar(v[4]), .display_gamma = scalar(v[5]) };
}
fn record(out: *W, value: c.GammaFunctionsParameters) !void {
    inline for (@typeInfo(c.GammaFunctionsParameters).@"struct".fields) |field| try out.print("{d},", .{@as(u32, @bitCast(@field(value, field.name)))});
    try out.writeByte('|');
}
fn changed(value: c.GammaFunctionsParameters, index: u8, raw: u32) c.GammaFunctionsParameters {
    var result = value;
    inline for (@typeInfo(c.GammaFunctionsParameters).@"struct".fields, 0..) |field, i| if (index == i) {
        @field(result, field.name) = scalar(raw);
    };
    return result;
}
fn methods(comptime N: type, comptime G: type, out: *W, value: f32, initial: c.GammaFunctionsParameters) !void {
    const results = [_]f32{ N.toGamma(value), N.toGammaFast(value), N.toLinear(value), N.toLinearFast(value), G.toGamma(value), G.toGammaFast(value), G.toLinear(value), G.toLinearFast(value), c.applyGamma(value, initial.gamma), c.removeGamma(value, initial.gamma), c.applyGamma(value, initial.display_gamma), c.removeGamma(value, initial.display_gamma) };
    for (results) |result| {
        const raw: u32 = if (std.math.isNan(result)) 0x7fc00000 else @bitCast(result);
        try out.print("{d},", .{raw});
    }
    try out.writeByte('|');
}
fn run(comptime kind: usize, out: *W, operation: u8, field: u8, raw: u32, value: f32) !void {
    const initial = comptime params(kind);
    const N = c.NonLinearGammaTransferFunctions(initial);
    const G = c.CurveGammaTransferFunctions(initial.gamma);
    var original = initial;
    var copy = original;
    var returned = original;
    switch (operation) {
        0 => {},
        1 => copy = changed(copy, field, raw),
        2 => original = changed(original, field, raw),
        3 => {
            copy = changed(copy, field, raw);
            returned = changed(copy, field, @as(u32, @bitCast(@field(initial, @typeInfo(c.GammaFunctionsParameters).@"struct".fields[0].name))));
            copy = original;
        },
        else => unreachable,
    }
    try record(out, original);
    try record(out, copy);
    try record(out, returned);
    try methods(N, G, out, value, initial);
    const CopyN = N;
    const CopyG = G;
    try methods(CopyN, CopyG, out, value, initial);
}
pub fn main() !void {
    const a = std.heap.page_allocator;
    const argv = try std.process.argsAlloc(a);
    const contents = try std.fs.cwd().readFileAlloc(a, argv[1], 16 * 1024 * 1024);
    var lines = std.mem.tokenizeScalar(u8, contents, '\n');
    var buffer: [64 * 1024]u8 = undefined;
    var output = std.fs.File.stdout().writer(&buffer);
    while (lines.next()) |line| {
        var parts = std.mem.splitScalar(u8, line, '|');
        const kind = try std.fmt.parseInt(usize, parts.next().?, 10);
        const operation = try std.fmt.parseInt(u8, parts.next().?, 10);
        const field = try std.fmt.parseInt(u8, parts.next().?, 10);
        const replacement = try std.fmt.parseInt(u32, parts.next().?, 10);
        const value = scalar(try std.fmt.parseInt(u32, parts.next().?, 10));
        inline for (data.raw_params, 0..) |_, i| if (kind == i) try run(i, &output.interface, operation, field, replacement, value);
        try output.interface.writeByte('\n');
    }
    try output.interface.flush();
}
