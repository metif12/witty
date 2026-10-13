const std = @import("std");
const p = @import("src/formats/tiff.zig");
const io = @import("src/io.zig");
const color = @import("src/color.zig");
const F = @import("src/pixel_format.zig").PixelFormat;
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var observed_codec: ?*p.TIFF = null;
var observed_stream: ?*io.ReadStream = null;
var observed_pixels: ?*color.PixelStorage = null;
var observed_palette: []color.Rgba32 = &.{};
var observed_path: ?[]const u8 = null;
var observed_buffer: []const u8 = &.{};

fn list(out: *W, values: ?[]u32) !void {
    if (values) |vs| {
        try out.writeByte('P');
        for (vs) |v| try out.print("{d},", .{v});
    } else try out.writeByte('N');
}
fn snapshot(out: *W, codec: *p.TIFF, stream: *io.ReadStream, pixels: color.PixelStorage, palette: []color.Rgba32, buffer: []const u8) !void {
    const b = &codec.bitmap;
    try out.print("{d}|{d}|{x}|{d}:{d}:", .{ stream.getPos(), stream.reader().bufferedLen(), buffer, @intFromEnum(std.meta.activeTag(pixels)), pixels.len() });
    if (pixels == .grayscale1) {
        for (pixels.grayscale1) |v| try out.print("{x:0>2}", .{@as(u8, v.value)});
    } else try out.print("{x}", .{pixels.asBytes()});
    try out.print("|{d}|{x}|", .{ if (pixels == .indexed8) pixels.indexed8.palette.len else @as(usize, 0), std.mem.sliceAsBytes(palette) });
    try out.print("{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}|", .{ @intFromEnum(b.compression), b.image_width, b.image_height, b.rows_per_strip, b.photometric_interpretation, b.samples_per_pixel, b.fill_order, b.planar_configuration, b.predictor, @intFromEnum(b.resolution_unit), b.new_subfile_type, b.x_resolution[0], b.x_resolution[1], b.y_resolution[0], b.y_resolution[1] });
    try list(out, b.strip_offsets);
    try out.writeByte('|');
    try list(out, b.strip_byte_counts);
    try out.print("|{d}|", .{b.bits_per_sample.data.len});
    for (b.bits_per_sample.storage) |v| try out.print("{d},", .{v});
    try out.print("|{d}|", .{b.extra_samples.data.len});
    for (b.extra_samples.storage) |v| try out.print("{d},", .{v});
    try out.print("|{d}|{x}", .{ b.color_map.data.len, std.mem.sliceAsBytes(&b.color_map.storage) });
}
fn observe(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var buffer: [8192]u8 = undefined;
            var writer = file.writer(&buffer);
            snapshot(&writer.interface, observed_codec.?, observed_stream.?, observed_pixels.?.*, observed_palette, observed_buffer) catch {};
            writer.interface.flush() catch {};
        } else |_| {}
    }
    std.debug.defaultPanic(message, address);
}
fn numbers(text: []const u8, allocator: std.mem.Allocator) ![]u32 {
    var values: std.ArrayList(u32) = .{};
    var it = std.mem.splitScalar(u8, text, ',');
    while (it.next()) |v| if (v.len > 0) {
        try values.append(allocator, try std.fmt.parseInt(u32, v, 10));
    };
    return values.toOwnedSlice(allocator);
}
fn record(out: *W, line: []const u8, path: []const u8, allocator: std.mem.Allocator) !void {
    var it = std.mem.splitScalar(u8, line, '|');
    var args: [12]u32 = undefined;
    for (&args) |*v| v.* = try std.fmt.parseInt(u32, it.next().?, 10);
    const bits = try numbers(it.next().?, allocator);
    const off_text = it.next().?;
    const count_text = it.next().?;
    const encoded = it.next().?;
    const data = try allocator.alloc(u8, encoded.len / 2);
    _ = try std.fmt.hexToBytes(data, encoded);
    const buffer = try allocator.alloc(u8, args[0]);
    @memset(buffer, 165);
    var stream = io.ReadStream.initMemory(data);
    var file: ?std.fs.File = null;
    if (args[0] > 0) {
        try std.fs.cwd().writeFile(.{ .sub_path = path, .data = data });
        file = try std.fs.cwd().openFile(path, .{});
        stream = io.ReadStream.initFile(file.?, buffer);
    }
    defer if (file) |f| f.close();
    var codec: p.TIFF = .{ .bitmap = .{ .image_width = args[2], .image_height = args[3], .rows_per_strip = args[4], .compression = @enumFromInt(args[11]), .photometric_interpretation = @intCast(args[8]), .predictor = @intCast(args[9]), .samples_per_pixel = @intCast(args[10]), .x_resolution = .{ 23, 29 }, .y_resolution = .{ 31, 37 }, .new_subfile_type = 41, .resolution_unit = .cm, .fill_order = 2, .planar_configuration = 2 } };
    codec.bitmap.strip_offsets = if (std.mem.eql(u8, off_text, "N")) null else try numbers(off_text, allocator);
    codec.bitmap.strip_byte_counts = if (std.mem.eql(u8, count_text, "N")) null else try numbers(count_text, allocator);
    codec.bitmap.bits_per_sample.resize(8);
    codec.bitmap.extra_samples.resize(8);
    codec.bitmap.color_map.resize(256);
    for (0..8) |i| {
        codec.bitmap.bits_per_sample.data[i] = @intCast(100 + i);
        codec.bitmap.extra_samples.data[i] = @intCast(200 + i);
    }
    codec.bitmap.bits_per_sample.resize(bits.len);
    for (bits, 0..) |v, i| codec.bitmap.bits_per_sample.data[i] = @intCast(v);
    codec.bitmap.extra_samples.resize(2);
    for (codec.bitmap.color_map.data, 0..) |*v, i| v.* = .{ .r = @truncate(i * 17), .g = @truncate(i * 59), .b = @truncate(i * 97), .a = 201 };
    codec.bitmap.color_map.resize(args[7]);
    const formats = [_]F{ .grayscale1, .grayscale8, .indexed8, .rgb24, .rgba32, .grayscale16 };
    var pixels = try color.PixelStorage.init(allocator, formats[args[1]], args[5]);
    var palette: []color.Rgba32 = &.{};
    if (pixels == .grayscale1) {
        for (pixels.grayscale1) |*v| v.value = 1;
    } else @memset(pixels.asBytes(), 165);
    if (pixels == .indexed8) {
        palette = pixels.indexed8.palette;
        for (palette, 0..) |*v, i| v.* = .{ .r = @truncate(i * 31), .g = @truncate(i * 71), .b = @truncate(i * 47), .a = 99 };
        pixels.indexed8.resizePalette(args[6]);
    }
    if (observed_path != null) {
        observed_codec = &codec;
        observed_stream = &stream;
        observed_pixels = &pixels;
        observed_palette = palette;
        observed_buffer = buffer;
    }
    const status: []const u8 = blk: {
        codec.readStrips(allocator, &stream, &pixels) catch |err| break :blk @errorName(err);
        break :blk "ok";
    };
    try out.print("{s}|", .{status});
    try snapshot(out, &codec, &stream, pixels, palette, buffer);
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    var buffer: [8192]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&buffer);
    const out = &stdout.interface;
    if (args.len == 4 and std.mem.eql(u8, args[1], "--trap")) {
        observed_path = args[2];
        try record(out, args[3], try std.fmt.allocPrint(a, "{s}.bin", .{args[2]}), a);
        try out.writeByte('\n');
        try out.flush();
        return;
    }
    const input = try std.fs.cwd().readFileAlloc(a, args[1], 64 * 1024 * 1024);
    var lines = std.mem.splitScalar(u8, input, '\n');
    const path = try std.fmt.allocPrint(a, "{s}.zig.bin", .{args[1]});
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var arena = std.heap.ArenaAllocator.init(a);
        defer arena.deinit();
        try record(out, line, path, arena.allocator());
        try out.writeByte('\n');
    }
    try out.flush();
}
