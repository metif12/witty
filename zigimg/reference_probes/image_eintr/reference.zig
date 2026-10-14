const std = @import("std");
const Image = @import("src/Image.zig");
const ImageUnmanaged = @import("src/ImageUnmanaged.zig");
const PixelFormat = @import("src/pixel_format.zig").PixelFormat;
const allocator = std.heap.page_allocator;
const W = std.Io.Writer;
const c = @cImport({
    @cDefine("WITTY_IMAGE_EINTR_DECLARATIONS", "1");
    @cInclude("fixture_shims.h");
});
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_fd: c_int = -1;
var observed_fifo: [:0]const u8 = undefined;
var observed_image: ?*const ImageUnmanaged = null;
var observed_buffer: []const u8 = &.{};
var observed_wire: W.Allocating = undefined;
var observed_drain: isize = -3;
var observed_pending: bool = false;
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

fn signalState(out: *W) !void {
    try out.print("{d}:{d}:{d}:{d}:{d}:{d}", .{ c.witty_image_eintr_metric(0), c.witty_image_eintr_metric(1), c.witty_image_eintr_metric(2), c.witty_image_eintr_metric(3), c.witty_image_eintr_metric(4), c.witty_image_eintr_metric(5) });
}
fn finish() void {
    if (observed_pending) {
        observed_fd = c.witty_image_eintr_finish();
        observed_pending = false;
    }
}
fn snapshot(out: *W, drain: bool) !void {
    if (drain) {
        var bytes: [4096]u8 = undefined;
        while (true) {
            const n = c.witty_image_eintr_read(observed_fd, &bytes, bytes.len);
            if (n <= 0) {
                observed_drain = n;
                break;
            }
            try observed_wire.writer.writeAll(bytes[0..@intCast(n)]);
        }
    }
    const image = observed_image.?;
    try out.print("{d}:{d}:{d}:{d}|{x}|{d}:{d}:{d}:{d}:{x}|", .{ c.witty_image_eintr_kind(observed_fifo), c.witty_image_eintr_valid(observed_fd), c.witty_image_eintr_refs(observed_fd), observed_drain, observed_buffer, image.width, image.height, @intFromEnum(image.pixelFormat()), image.pixels.len(), image.rawBytes() });
    if (image.pixels.getPalette()) |pal| try out.print("{x}", .{std.mem.sliceAsBytes(pal)}) else try out.writeByte('-');
    try out.print("|{x}|", .{observed_wire.written()});
    try signalState(out);
}
fn observe(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| {
        finish();
        var state = W.Allocating.init(allocator);
        snapshot(&state.writer, true) catch {};
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            file.writeAll(state.written()) catch {};
        } else |_| {}
    }
    _ = c.witty_image_eintr_remove(observed_fifo);
    std.debug.defaultPanic(message, address);
}
fn detect(path: []const u8, buffer: []u8, managed: bool) !Image.Format {
    return if (managed) Image.detectFormatFromFilePath(path, buffer) else ImageUnmanaged.detectFormatFromFilePath(path, buffer);
}
fn decode(path: []const u8, buffer: []u8, managed: bool) !ImageUnmanaged {
    return if (managed) (try Image.fromFilePath(allocator, path, buffer)).toUnmanaged() else ImageUnmanaged.fromFilePath(allocator, path, buffer);
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
    observed_fd = -1;
    if (c.witty_image_eintr_create(observed_fifo) != 0) return error.FifoSetupFailed;
    defer _ = c.witty_image_eintr_remove(observed_fifo);
    const seed = try allocator.alloc(u8, f[8].len / 2);
    defer allocator.free(seed);
    _ = try std.fmt.hexToBytes(seed, f[8]);
    observed_wire = W.Allocating.init(allocator);
    defer observed_wire.deinit();
    observed_drain = -3;
    const opts = options(@enumFromInt(try number(u8, f[1])), try number(usize, f[3]));
    try out.print("1:0:0:-3|{x}|{d}:{d}:{d}:{d}:{x}|", .{ buffer, image.width, image.height, @intFromEnum(image.pixelFormat()), image.pixels.len(), image.rawBytes() });
    if (image.pixels.getPalette()) |pal| try out.print("{x}", .{std.mem.sliceAsBytes(pal)}) else try out.writeByte('-');
    try out.writeAll("||0:0:0:0:0:0~");
    for (0..try number(usize, f[7])) |_| {
        if (c.witty_image_eintr_begin(observed_fifo, try number(c_int, f[9]), seed.ptr, seed.len) != 0) return error.SignalSetupFailed;
        observed_pending = true;
        var status: []const u8 = "ok";
        var result = W.Allocating.init(allocator);
        defer result.deinit();
        if (op == 0) {
            if (std.mem.eql(u8, f[5], "1")) managed.writeToFilePath(observed_fifo, buffer, opts) catch |err| {
                status = @errorName(err);
            } else image.writeToFilePath(allocator, observed_fifo, buffer, opts) catch |err| {
                status = @errorName(err);
            };
        } else if (op == 1) {
            if (detect(observed_fifo, buffer, std.mem.eql(u8, f[5], "1"))) |value| {
                try result.writer.print("{s}", .{@tagName(value)});
            } else |err| {
                status = @errorName(err);
            }
        } else {
            if (decode(observed_fifo, buffer, std.mem.eql(u8, f[5], "1"))) |value| {
                var decoded = value;
                defer decoded.deinit(allocator);
                try result.writer.print("{d}:{d}:{d}", .{ decoded.width, decoded.height, @intFromEnum(decoded.pixelFormat()) });
            } else |err| {
                status = @errorName(err);
            }
        }
        finish();
        try out.print("{s}:{s}|", .{ status, if (op != 0 and std.mem.eql(u8, status, "ok")) result.written() else "-" });
        try snapshot(out, true);
        try out.writeByte('~');
        _ = c.witty_image_eintr_close(observed_fd);
        observed_fd = -1;
    }
}
pub fn main() !void {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    var row = W.Allocating.init(allocator);
    defer row.deinit();
    var output = std.fs.File.stdout().writer(&.{});
    if (std.mem.eql(u8, args[1], "--calibrate")) {
        const path = try std.fmt.allocPrintSentinel(allocator, "{s}.fifo", .{args[2]}, 0);
        defer allocator.free(path);
        for (0..2) |writing| {
            for ([_]c_int{ 1, 3 }) |signals| {
                if (c.witty_image_eintr_create(path) != 0 or c.witty_image_eintr_begin(path, signals, null, 0) != 0) return error.CalibrationSetup;
                const interrupted = c.witty_image_eintr_raw(path, @intCast(writing));
                const fd = c.witty_image_eintr_finish();
                row.clearRetainingCapacity();
                try row.writer.print("{d}:{d}|{d}|", .{ writing, signals, interrupted });
                try signalState(&row.writer);
                try output.interface.print("{s}\n", .{row.written()});
                _ = c.witty_image_eintr_close(fd);
                _ = c.witty_image_eintr_remove(path);
            }
        }
        return;
    }
    if (std.mem.eql(u8, args[1], "--trap")) {
        observed_path = args[2];
        observed_fifo = try std.fmt.allocPrintSentinel(allocator, "{s}.fifo", .{args[2]}, 0);
        defer allocator.free(observed_fifo);
        try record(args[3], &row.writer);
        try output.interface.print("{s}\n", .{row.written()});
        return;
    }
    observed_fifo = try std.fmt.allocPrintSentinel(allocator, "{s}.fifo", .{args[1]}, 0);
    defer allocator.free(observed_fifo);
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
