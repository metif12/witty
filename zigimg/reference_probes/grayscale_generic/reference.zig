const std = @import("std");
const c = @import("src/color.zig");
const AliasU32 = u32;
const AliasF32 = f32;
fn scalar(comptime T: type, raw: u64) T {
    if (T == f32) return @bitCast(@as(u32, @truncate(raw)));
    if (T == f64) return @bitCast(raw);
    return @intCast(raw);
}
fn record(writer: *std.Io.Writer, value: anytype) !void {
    inline for (@typeInfo(@TypeOf(value)).@"struct".fields) |field| {
        if (@typeInfo(field.type) == .float or @typeInfo(field.type) == .int) {
            const v = @field(value, field.name);
            const raw: u64 = if (field.type == f32) @as(u32, @bitCast(v)) else if (field.type == f64) @bitCast(v) else @intCast(v);
            try writer.print("{d},", .{raw});
        }
    }
}
fn changed(value: anytype, field_index: usize, raw: u64) @TypeOf(value) {
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
fn run(comptime T: type, comptime alpha: bool, writer: *std.Io.Writer, args: [6]u64) !void {
    const G = if (alpha) c.GrayscaleAlpha(T) else c.Grayscale(T);
    var original: G = .{ .value = scalar(T, args[3]) };
    if (alpha and args[0] == 1) original.alpha = scalar(T, args[4]);
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
    if (std.mem.eql(u8, argv[1], "omitted")) {
        var buffer: [4096]u8 = undefined;
        var output = std.fs.File.stdout().writer(&buffer);
        inline for (.{ u8, u16, u32, u64, usize, f32, f64, AliasU32, AliasF32 }) |T| {
            const value = c.GrayscaleAlpha(T){ .value = 0 };
            try observe(&output.interface, value);
            try output.interface.writeByte('\n');
        }
        try output.interface.flush();
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
        const alpha = try std.fmt.parseInt(u8, parts.next().?, 10);
        var args: [6]u64 = undefined;
        for (&args) |*value| value.* = try std.fmt.parseInt(u64, parts.next().?, 10);
        inline for (.{ u8, u16, u32, u64, usize, f32, f64, AliasU32, AliasF32 }, 0..) |T, index| {
            if (kind == index) {
                if (alpha == 0) try run(T, false, writer, args) else try run(T, true, writer, args);
            }
        }
        try writer.writeByte('\n');
    }
    try writer.flush();
}
