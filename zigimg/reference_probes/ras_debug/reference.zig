const std = @import("std");
const p = @import("src/formats/ras.zig");
const settings = @import("settings");
const a = std.heap.page_allocator;
const W = std.Io.Writer;
const H = @TypeOf(@as(p.RAS, undefined).header);
pub const std_options: std.Options = .{ .log_level = if (settings.enabled) .debug else .info, .logFn = reject };
fn reject(comptime _: std.log.Level, comptime _: @Type(.enum_literal), comptime _: []const u8, _: anytype) void {
    @panic("RAS debug unexpectedly used the logger");
}
fn scalar(out: *W, h: H) !void {
    try out.print("{d}:{d}:{d}:{d}:{d}:{d}:{d}", .{ h.width, h.height, h.depth, h.length, @intFromEnum(h.type), @intFromEnum(h.color_map_type), h.color_map_length });
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args);
    const text = try std.fs.cwd().readFileAlloc(a, args[1], 16 * 1024 * 1024);
    defer a.free(text);
    var buffer: [8192]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&buffer);
    const out = &writer.interface;
    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    while (lines.next()) |line| {
        var parts = std.mem.splitScalar(u8, line, '|');
        var f: [8]u32 = undefined;
        for (&f) |*v| v.* = try std.fmt.parseInt(u32, parts.next().?, 10);
        if (parts.next() != null) @panic("malformed row");
        const h = H{ .width = f[1], .height = f[2], .depth = f[3], .length = f[4], .type = @enumFromInt(f[5]), .color_map_type = @enumFromInt(f[6]), .color_map_length = f[7] };
        var before: [256]u8 = undefined;
        var before_writer = W.fixed(&before);
        try scalar(&before_writer, h);
        for (0..f[0]) |_| h.debug();
        try out.print("{d}|", .{f[0]});
        try out.writeAll(before_writer.buffered());
        try out.writeByte('|');
        try scalar(out, h);
        try out.writeByte('\n');
    }
    try out.flush();
}
