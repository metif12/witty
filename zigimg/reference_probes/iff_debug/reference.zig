const std = @import("std");
const p = @import("src/formats/iff.zig");
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
fn bmhdScalar(out: *W, h: p.BmhdHeader) !void {
    try out.print("{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}", .{ h.width, h.height, h.x, h.y, h.planes, @intFromEnum(h.mask_type), @intFromEnum(h.compression_type), h.pad, h.transparent_color, h.x_asoect, h.y_aspect, h.page_width, h.page_height });
}
fn dgblScalar(out: *W, h: p.DgblHeader) !void {
    try out.print("{d}:{d}:{d}:{d}:{d}", .{ h.width, h.height, @intFromEnum(h.compression_type), h.x_aspect, h.y_aspect });
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
        var f: [15]i32 = @splat(0);
        var i: usize = 0;
        while (parts.next()) |part| {
            f[i] = try std.fmt.parseInt(i32, part, 10);
            i += 1;
        }
        message_count = 0;
        if (f[0] == 0) {
            const h = p.BmhdHeader{ .width = @intCast(f[2]), .height = @intCast(f[3]), .x = @intCast(f[4]), .y = @intCast(f[5]), .planes = @intCast(f[6]), .mask_type = @enumFromInt(f[7]), .compression_type = @enumFromInt(f[8]), .pad = @intCast(f[9]), .transparent_color = @intCast(f[10]), .x_asoect = @intCast(f[11]), .y_aspect = @intCast(f[12]), .page_width = @intCast(f[13]), .page_height = @intCast(f[14]) };
            var before: [4096]u8 = undefined;
            var before_writer = W.fixed(&before);
            try bmhdScalar(&before_writer, h);
            for (0..@as(usize, @intCast(f[1]))) |_| h.debug();
            try logOutput(out);
            try out.writeAll(before_writer.buffered());
            try out.writeByte('|');
            try bmhdScalar(out, h);
        } else {
            const h = p.DgblHeader{ .width = @intCast(f[2]), .height = @intCast(f[3]), .compression_type = @enumFromInt(f[4]), .x_aspect = @intCast(f[5]), .y_aspect = @intCast(f[6]) };
            var before: [4096]u8 = undefined;
            var before_writer = W.fixed(&before);
            try dgblScalar(&before_writer, h);
            for (0..@as(usize, @intCast(f[1]))) |_| h.debug();
            try logOutput(out);
            try out.writeAll(before_writer.buffered());
            try out.writeByte('|');
            try dgblScalar(out, h);
        }
        try out.writeByte('\n');
        for (messages[0..message_count]) |message| a.free(message.?);
    }
    try out.flush();
}
