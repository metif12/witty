const std = @import("std");
const p = @import("src/formats/sgi.zig");
const settings = @import("settings");
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const std_options: std.Options = .{ .log_level = if (settings.enabled) .debug else .info, .logFn = capture };
var messages: [4]?[]u8 = @splat(null);
var message_count: usize = 0;
fn capture(comptime level: std.log.Level, comptime scope: @Type(.enum_literal), comptime format: []const u8, args: anytype) void {
    if (level != .debug or scope != .default) @panic("unexpected log classification");
    messages[message_count] = std.fmt.allocPrint(a, format, args) catch @panic("allocation failed");
    message_count += 1;
}
const H = @TypeOf(@as(p.SGI, undefined).header);
fn scalar(out: *W, h: H) !void {
    try out.print("{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}:", .{ @intFromEnum(h.compression), h.bytes_per_channel, @intFromEnum(h.dimension), h.x_size, h.y_size, h.z_size, h.pix_min, h.pix_max, h.dummy1 });
    for (h.image_name) |byte| try out.print("{x:0>2}", .{byte});
    try out.print(":{d}:", .{@intFromEnum(h.pixel_format)});
    for (h.dummy2) |byte| try out.print("{x:0>2}", .{byte});
}
fn logOutput(out: *W) !void {
    try out.print("{d}|", .{message_count});
    for (messages[0..message_count]) |text| {
        try out.writeAll("debug:default:");
        for (text.?) |byte| try out.print("{x:0>2}", .{byte});
        try out.writeByte(';');
    }
    try out.writeByte('|');
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
        var f: [11]u32 = undefined;
        for (&f) |*value| value.* = try std.fmt.parseInt(u32, parts.next().?, 10);
        var h = H{ .compression = @enumFromInt(f[1]), .bytes_per_channel = @intCast(f[2]), .dimension = @enumFromInt(f[3]), .x_size = @intCast(f[4]), .y_size = @intCast(f[5]), .z_size = @intCast(f[6]), .pix_min = f[7], .pix_max = f[8], .dummy1 = f[9], .image_name = @splat(0), .pixel_format = @enumFromInt(f[10]), .dummy2 = @splat(0) };
        const name = try std.fmt.hexToBytes(&h.image_name, parts.next().?);
        const padding = try std.fmt.hexToBytes(&h.dummy2, parts.next().?);
        if (name.len != 80 or padding.len != 404 or parts.next() != null) @panic("malformed row");
        message_count = 0;
        var before: [4096]u8 = undefined;
        var before_writer = W.fixed(&before);
        try scalar(&before_writer, h);
        for (0..f[0]) |_| h.debug();
        try logOutput(out);
        try out.writeAll(before_writer.buffered());
        try out.writeByte('|');
        try scalar(out, h);
        try out.writeByte('\n');
        for (messages[0..message_count]) |message| a.free(message.?);
    }
    try out.flush();
}
