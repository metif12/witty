const std = @import("std");
const Image = @import("src/Image.zig");
const ImageUnmanaged = @import("src/ImageUnmanaged.zig");
const PixelFormat = @import("src/pixel_format.zig").PixelFormat;
const allocator = std.heap.page_allocator;
const W = std.Io.Writer;
const c = @cImport({
    @cInclude("fixture_shims.h");
});
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_read: c_int = -1;
var observed_write: c_int = -1;
var observed_supplied: c_int = -1;
var observed_image: ?*const ImageUnmanaged = null;
var observed_buffer: []const u8 = &.{};
var observed_wire: W.Allocating = undefined;
var observed_drain: isize = -3;
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

fn snapshot(out: *W, drain: bool) !void {
    if (drain) {
        var bytes: [4096]u8 = undefined;
        while (true) {
            const n = c.witty_image_pipe_read(observed_read, &bytes, bytes.len);
            if (n <= 0) {
                observed_drain = n;
                break;
            }
            try observed_wire.writer.writeAll(bytes[0..@intCast(n)]);
        }
    }
    const image = observed_image.?;
    try out.print("{d}:{d}:{d}:{d}|{x}|{d}:{d}:{d}:{d}:{x}|", .{ c.witty_image_pipe_valid(observed_read), c.witty_image_pipe_valid(observed_write), c.witty_image_pipe_valid(observed_supplied), observed_drain, observed_buffer, image.width, image.height, @intFromEnum(image.pixelFormat()), image.pixels.len(), image.rawBytes() });
    if (image.pixels.getPalette()) |pal| try out.print("{x}", .{std.mem.sliceAsBytes(pal)}) else try out.writeByte('-');
    try out.print("|{x}", .{observed_wire.written()});
}
fn observe(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| {
        var state = W.Allocating.init(allocator);
        snapshot(&state.writer, true) catch {};
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            file.writeAll(state.written()) catch {};
        } else |_| {}
    }
    std.debug.defaultPanic(message, address);
}
fn detect(file: std.fs.File, buffer: []u8, managed: bool) !Image.Format {
    return if (managed) Image.detectFormatFromFile(file, buffer) else ImageUnmanaged.detectFormatFromFile(file, buffer);
}
fn decode(file: std.fs.File, buffer: []u8, managed: bool) !ImageUnmanaged {
    return if (managed) (try Image.fromFile(allocator, file, buffer)).toUnmanaged() else ImageUnmanaged.fromFile(allocator, file, buffer);
}
fn number(comptime T: type, value: []const u8) !T {
    return std.fmt.parseInt(T, value, 10);
}
fn record(line: []const u8, out: *W) !void {
    var f: [10][]const u8 = undefined;
    var it = std.mem.splitScalar(u8, line, '|');
    for (&f) |*field| field.* = it.next().?;
    const op = try number(u8, f[0]);
    var backing = try source(try number(usize, f[2]));
    defer backing.deinit(allocator);
    var image = backing;
    if (std.mem.eql(u8, f[6], "1")) image.width = 0;
    if (std.mem.eql(u8, f[6], "2")) image.height = 0;
    if (std.mem.eql(u8, f[6], "3") and image.pixels.len() > 0) image.pixels = image.pixels.slice(0, 1);
    const managed = image.toManaged(allocator);
    observed_image = &image;
    const buffer = try allocator.alloc(u8, try number(usize, f[4]));
    defer allocator.free(buffer);
    @memset(buffer, 165);
    observed_buffer = buffer;
    var fds: [2]c_int = undefined;
    if (c.witty_image_pipe_open(&fds) != 0) return error.PipeSetupFailed;
    defer {
        _ = c.witty_image_pipe_close(fds[0]);
        _ = c.witty_image_pipe_close(fds[1]);
    }
    const seed = try allocator.alloc(u8, f[9].len / 2);
    defer allocator.free(seed);
    _ = try std.fmt.hexToBytes(seed, f[9]);
    if (seed.len > 0 and c.witty_image_pipe_write(fds[1], seed.ptr, seed.len) != seed.len) return error.PipeSeedFailed;
    observed_read = fds[0];
    observed_write = fds[1];
    observed_supplied = if (std.mem.eql(u8, f[8], "1")) -1 else if (op == 0) fds[1] else fds[0];
    observed_wire = W.Allocating.init(allocator);
    defer observed_wire.deinit();
    observed_drain = -3;
    const file = std.fs.File{ .handle = observed_supplied };
    const opts = options(@enumFromInt(try number(u8, f[1])), try number(usize, f[3]));
    try snapshot(out, false);
    try out.writeByte('~');
    for (0..try number(usize, f[7])) |_| {
        var status: []const u8 = "ok";
        var result = W.Allocating.init(allocator);
        defer result.deinit();
        if (op == 0) {
            if (std.mem.eql(u8, f[5], "1")) managed.writeToFile(file, buffer, opts) catch |err| {
                status = @errorName(err);
            } else image.writeToFile(allocator, file, buffer, opts) catch |err| {
                status = @errorName(err);
            };
        } else if (op == 1) {
            if (detect(file, buffer, std.mem.eql(u8, f[5], "1"))) |value| {
                try result.writer.print("{s}", .{@tagName(value)});
            } else |err| {
                status = @errorName(err);
            }
        } else {
            if (decode(file, buffer, std.mem.eql(u8, f[5], "1"))) |value| {
                var decoded = value;
                defer decoded.deinit(allocator);
                try result.writer.print("{d}:{d}:{d}", .{ decoded.width, decoded.height, @intFromEnum(decoded.pixelFormat()) });
            } else |err| {
                status = @errorName(err);
            }
        }
        try out.print("{s}:{s}|", .{ status, if (op != 0 and std.mem.eql(u8, status, "ok")) result.written() else "-" });
        try snapshot(out, true);
        try out.writeByte('~');
    }
}
pub fn main() !void {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    var row = W.Allocating.init(allocator);
    defer row.deinit();
    var output = std.fs.File.stdout().writer(&.{});
    if (std.mem.eql(u8, args[1], "--trap")) {
        observed_path = args[2];
        try record(args[3], &row.writer);
        try output.interface.print("{s}\n", .{row.written()});
        return;
    }
    const data = try std.fs.cwd().readFileAlloc(allocator, args[1], 32 * 1024 * 1024);
    defer allocator.free(data);
    var lines = std.mem.splitScalar(u8, data, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        row.clearRetainingCapacity();
        try record(line, &row.writer);
        try output.interface.print("{s}\n", .{row.written()});
    }
}
