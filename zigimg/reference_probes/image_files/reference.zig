const std = @import("std");
const Image = @import("src/Image.zig");
const ImageUnmanaged = @import("src/ImageUnmanaged.zig");
const PixelFormat = @import("src/pixel_format.zig").PixelFormat;
const allocator = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_disk: []const u8 = "";
var observed_file: std.fs.File = undefined;
var observed_image: ?*const ImageUnmanaged = null;
var observed_buffer: []const u8 = &.{};
fn options(format: Image.Format, variant: usize) Image.EncoderOptions {
    return switch (format) {
        .bmp => .{ .bmp = .{} },
        .farbfeld => .{ .farbfeld = {} },
        .gif => .{ .gif = {} },
        .iff => .{ .iff = {} },
        .jpeg => .{ .jpeg = {} },
        .pam => .{ .pam = .{ .comments = if (variant == 1) &.{ "one", "two" } else &.{} } },
        .pbm => .{ .pbm = .{ .binary = variant != 1 } },
        .pcx => .{ .pcx = .{} },
        .pgm => .{ .pgm = .{ .binary = variant != 1 } },
        .png => .{ .png = .{ .interlaced = variant == 1 } },
        .ppm => .{ .ppm = .{ .binary = variant != 1 } },
        .qoi => .{ .qoi = .{ .colorspace = if (variant == 1) .linear else .srgb } },
        .ras => .{ .ras = {} },
        .sgi => .{ .sgi = {} },
        .tga => .{ .tga = .{
            .rle_compressed = variant != 1,
            .top_to_bottom_image = variant == 0,
            .image_id = if (variant == 2) &.{ 7, 8, 9 } else &.{},
            .author_name = if (variant == 2) "author" else "",
        } },
        .tiff => .{ .tiff = {} },
        .xbm => .{ .xbm = {} },
    };
}

fn source(profile: usize) !ImageUnmanaged {
    const formats = [_]PixelFormat{ .grayscale8, .rgb24, .rgba32, .bgr24, .bgra32, .rgba64, .indexed8, .invalid };
    var image = try ImageUnmanaged.create(allocator, 4, 2, formats[profile]);
    for (image.pixels.asBytes(), 0..) |*byte, i| byte.* = @truncate(i * 37 + profile * 19);
    if (profile == 6) {
        image.pixels.resizePalette(4);
        for (image.pixels.indexed8.indices, 0..) |*index, i| index.* = @intCast(i % 4);
        for (image.pixels.indexed8.palette, 0..) |*entry, i| entry.* = .{ .r = @intCast(i * 71), .g = @intCast(i * 53), .b = @intCast(i * 37), .a = 255 };
    }
    return image;
}

fn snapshot(out: *W) !void {
    const image = observed_image.?;
    try out.print("{d}|{x}|{d}:{d}:{d}:{d}:{x}|", .{ try observed_file.getPos(), observed_buffer, image.width, image.height, @intFromEnum(std.meta.activeTag(image.pixels)), image.pixels.len(), image.pixels.asBytes() });
    if (image.pixels.getPalette()) |pal| try out.print("{x}", .{std.mem.sliceAsBytes(pal)}) else try out.writeByte('-');
    const disk = try std.fs.cwd().readFileAlloc(allocator, observed_disk, 65536);
    defer allocator.free(disk);
    try out.print("|{x}", .{disk});
}
fn observe(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var buffer: [8192]u8 = undefined;
            var writer = file.writer(&buffer);
            snapshot(&writer.interface) catch {};
            writer.interface.flush() catch {};
        } else |_| {}
    }
    std.debug.defaultPanic(message, address);
}
fn number(comptime T: type, value: []const u8) !T {
    return std.fmt.parseInt(T, value, 10);
}
fn record(line: []const u8, path: []const u8, out: *W) !void {
    var f: [7][]const u8 = undefined;
    var it = std.mem.splitScalar(u8, line, '|');
    for (&f) |*field| field.* = it.next().?;
    const format: Image.Format = @enumFromInt(try number(u8, f[0]));
    const profile = try number(usize, f[1]);
    const variant = try number(usize, f[2]);
    const cap = try number(usize, f[3]);
    const route = try number(u8, f[4]);
    const shape = try number(u8, f[5]);
    var backing = try source(profile);
    defer backing.deinit(allocator);
    var image = backing;
    if (shape == 1) image.width = 0;
    if (shape == 2) image.height = 0;
    if (shape == 3 and image.pixels.len() > 0) image.pixels = image.pixels.slice(0, 1);
    const managed = image.toManaged(allocator);
    observed_image = &image;
    const buffer = try allocator.alloc(u8, cap);
    defer allocator.free(buffer);
    @memset(buffer, 165);
    observed_buffer = buffer;
    const initial = [_]u8{165} ** 256;
    try std.fs.cwd().writeFile(.{ .sub_path = path, .data = &initial });
    const file = try std.fs.cwd().openFile(path, .{ .mode = .read_write });
    defer file.close();
    try file.seekTo(256);
    observed_file = file;
    observed_disk = path;
    const opts = options(format, variant);
    try snapshot(out);
    try out.writeByte('~');
    for (0..try number(usize, f[6])) |_| {
        var status: []const u8 = "ok";
        switch (route) {
            0 => image.writeToFile(allocator, file, buffer, opts) catch |err| {
                status = @errorName(err);
            },
            1 => managed.writeToFile(file, buffer, opts) catch |err| {
                status = @errorName(err);
            },
            2 => image.writeToFilePath(allocator, path, buffer, opts) catch |err| {
                status = @errorName(err);
            },
            else => managed.writeToFilePath(path, buffer, opts) catch |err| {
                status = @errorName(err);
            },
        }
        try out.print("{s}|", .{status});
        try snapshot(out);
        try out.writeByte('~');
    }
}
pub fn main() !void {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    // Buffer stdout until a record returns, so panics have no partial stdout.
    var row = W.Allocating.init(allocator);
    defer row.deinit();
    var output = std.fs.File.stdout().writer(&.{});
    if (std.mem.eql(u8, args[1], "--trap")) {
        observed_path = args[2];
        const path = try std.fmt.allocPrint(allocator, "{s}.bin", .{args[2]});
        defer allocator.free(path);
        try record(args[3], path, &row.writer);
        try output.interface.print("{s}\n", .{row.written()});
        return;
    }
    const data = try std.fs.cwd().readFileAlloc(allocator, args[1], 32 * 1024 * 1024);
    defer allocator.free(data);
    const path = try std.fmt.allocPrint(allocator, "{s}.zig.bin", .{args[1]});
    defer allocator.free(path);
    var lines = std.mem.splitScalar(u8, data, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        row.clearRetainingCapacity();
        try record(line, path, &row.writer);
        try output.interface.print("{s}\n", .{row.written()});
    }
}
