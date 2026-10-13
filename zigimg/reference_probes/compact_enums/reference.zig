const std = @import("std");
const c = @import("src/color.zig");
const n = @import("src/formats/netpbm.zig");
const pam = @import("src/formats/pam.zig");
const io = @import("src/io.zig");
fn emit(writer: *std.Io.Writer, values: anytype) !void {
    try writer.print("{x}|", .{std.mem.sliceAsBytes(values)});
    for (values) |value| try writer.print("{s},{d};", .{ @tagName(value), @intFromEnum(value) });
    try writer.writeByte('|');
}
fn changed(value: anytype, comptime T: type, raw: u8) T {
    _ = value;
    return @enumFromInt(raw);
}
fn run(comptime T: type, writer: *std.Io.Writer, count: usize, seed: usize) !void {
    const variants = @typeInfo(T).@"enum".fields.len;
    const values = try std.heap.page_allocator.alloc(T, count);
    for (values, 0..) |*value, index| value.* = @enumFromInt((index + seed) % variants);
    const copy = try std.heap.page_allocator.dupe(T, values);
    var original: T = @enumFromInt(seed % variants);
    const returned = changed(original, T, @intCast((seed + 1) % variants));
    const old = original;
    original = returned;
    try writer.print("{d},{d}|{s},{d},{s},{d},{s},{d}|", .{ @sizeOf(T), @alignOf(T), @tagName(old), @intFromEnum(old), @tagName(original), @intFromEnum(original), @tagName(returned), @intFromEnum(returned) });
    try emit(writer, values);
    try emit(writer, copy);
    if (count != 0) {
        const index = seed % count;
        values[index] = @enumFromInt((seed + 1) % variants);
        std.mem.sliceAsBytes(copy)[index] = @intCast((seed + 2) % variants);
    }
    try emit(writer, values);
    try emit(writer, copy);
}
pub fn main() !void {
    const argv = try std.process.argsAlloc(std.heap.page_allocator);
    if (std.mem.eql(u8, argv[1], "pam")) {
        var stream = io.ReadStream.initMemory(argv[2]);
        const image = try pam.PAM.readImage(std.heap.page_allocator, &stream);
        std.debug.print("{d}\n", .{image.width});
        return;
    }
    const contents = try std.fs.cwd().readFileAlloc(std.heap.page_allocator, argv[1], 16 * 1024 * 1024);
    var buffer: [64 * 1024]u8 = undefined;
    var output = std.fs.File.stdout().writer(&buffer);
    var lines = std.mem.tokenizeScalar(u8, contents, '\n');
    while (lines.next()) |line| {
        var parts = std.mem.splitScalar(u8, line, '|');
        const kind = try std.fmt.parseInt(u8, parts.next().?, 10);
        const count = try std.fmt.parseInt(usize, parts.next().?, 10);
        const seed = try std.fmt.parseInt(usize, parts.next().?, 10);
        if (kind == 0) try run(c.RgbColorspace.PostConversionBehavior, &output.interface, count, seed) else try run(n.Format, &output.interface, count, seed);
        try output.interface.writeByte('\n');
    }
    try output.interface.flush();
}
