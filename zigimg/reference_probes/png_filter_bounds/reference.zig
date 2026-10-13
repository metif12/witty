const std = @import("std");
const filtering = @import("src/formats/png/filtering.zig");
const png = @import("src/formats/png/types.zig");
const color = @import("src/color.zig");
const PixelFormat = @import("src/pixel_format.zig").PixelFormat;
const a = std.heap.page_allocator;
const formats = [_]PixelFormat{ .indexed1, .indexed2, .indexed4, .indexed8, .grayscale1, .grayscale2, .grayscale4, .grayscale8, .grayscale16, .grayscale8Alpha, .grayscale16Alpha, .rgb24, .rgb48, .rgba32, .rgba64, .indexed16, .invalid, .rgb332, .rgb565 };

fn pixelsFor(format: PixelFormat, count: usize, seed: usize) !color.PixelStorage {
    if (format == .invalid) return .invalid;
    const pixels = try color.PixelStorage.init(a, format, count);
    const bytes = pixels.asBytes();
    const depth: u8 = switch (format) {
        .indexed1, .grayscale1 => 1,
        .indexed2, .grayscale2 => 2,
        .indexed4, .grayscale4 => 4,
        else => 8,
    };
    for (bytes, 0..) |*byte, i| {
        byte.* = @truncate(i * 37 + seed * 19 + i / 7);
        if (depth < 8) byte.* &= (@as(u8, 1) << @intCast(depth)) - 1;
    }
    return pixels;
}

pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_writer: ?*std.Io.Writer = null;
var observed_pixels: ?*const color.PixelStorage = null;
var observed_output: []const u8 = &.{};
fn snapshot(out: *std.Io.Writer, writer: *std.Io.Writer, pixels: color.PixelStorage, output: []const u8) !void {
    try out.print("{d}|{x}|{x}", .{ writer.end, output, pixels.asConstBytes() });
}
fn observe(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var buffer: [8192]u8 = undefined;
            var writer = file.writer(&buffer);
            snapshot(&writer.interface, observed_writer.?, observed_pixels.?.*, observed_output) catch {};
            writer.interface.flush() catch {};
        } else |_| {}
    }
    std.debug.defaultPanic(message, address);
}
fn record(out: *std.Io.Writer, line: []const u8, allocator: std.mem.Allocator) !void {
    var it = std.mem.splitScalar(u8, line, '|');
    var p: [9]usize = undefined;
    for (&p) |*value| value.* = try std.fmt.parseInt(usize, it.next().?, 10);
    const pixels = try pixelsFor(formats[p[0]], p[3], p[6]);
    defer pixels.deinit(a);
    const header = png.HeaderData{ .width = @intCast(p[1]), .height = @intCast(p[2]), .bit_depth = @intCast(p[4]), .color_type = @enumFromInt(p[5]), .compression_method = .deflate, .filter_method = .adaptive, .interlace_method = .none };
    const choice: filtering.FilterChoice = if (p[7] == 6) .try_all else if (p[7] == 5) .heuristic else .{ .specified = @enumFromInt(p[7]) };
    const bytes = try allocator.alloc(u8, p[8]);
    @memset(bytes, 165);
    var writer = std.Io.Writer.fixed(bytes);
    if (observed_path != null) {
        observed_writer = &writer;
        observed_pixels = &pixels;
        observed_output = bytes;
    }
    filtering.filter(allocator, &writer, pixels, choice, header) catch |err| {
        try out.print("E{s}|", .{@errorName(err)});
        try snapshot(out, &writer, pixels, bytes);
        return;
    };
    try out.writeAll("ok|");
    try snapshot(out, &writer, pixels, bytes);
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    var buffer: [8192]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&buffer);
    const out = &stdout.interface;
    if (args.len == 4 and std.mem.eql(u8, args[1], "--trap")) {
        observed_path = args[2];
        try record(out, args[3], a);
        try out.writeByte('\n');
        try out.flush();
        return;
    }
    const input = try std.fs.cwd().readFileAlloc(a, args[1], 64 * 1024 * 1024);
    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var arena = std.heap.ArenaAllocator.init(a);
        defer arena.deinit();
        try record(out, line, arena.allocator());
        try out.writeByte('\n');
    }
    try out.flush();
}
