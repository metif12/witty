const std = @import("std");
const Image = @import("src/Image.zig");
const io = @import("src/io.zig");
const ImageUnmanaged = @import("src/ImageUnmanaged.zig");
const PixelFormat = @import("src/pixel_format.zig").PixelFormat;
const allocator = std.heap.page_allocator;
const W = std.Io.Writer;
const c = @cImport({
    @cDefine("WITTY_IMAGE_TTY_DECLARATIONS", "1");
    @cInclude("fixture_shims.h");
});
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_drain_input: isize = -3;
var observed_tty: []const u8 = undefined;
var observed_image: ?*const ImageUnmanaged = null;
var observed_buffer: []const u8 = &.{};
var observed_wire: W.Allocating = undefined;
var observed_input: W.Allocating = undefined;
var observed_drain: isize = -3;
var observed_output: []u8 = &.{};
var observed_pos: u64 = 0;
var observed_pending: []const u8 = &.{};
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
            const n = c.witty_image_tty_read(0, &bytes, bytes.len);
            if (n <= 0) {
                observed_drain = n;
                break;
            }
            try observed_wire.writer.writeAll(bytes[0..@intCast(n)]);
        }
        while (true) {
            const n = c.witty_image_tty_read(1, &bytes, bytes.len);
            if (n <= 0) {
                observed_drain_input = n;
                break;
            }
            try observed_input.writer.writeAll(bytes[0..@intCast(n)]);
        }
    }
    const image = observed_image.?;
    try out.print("{d}:{d}:{d}:{d}:{d}|{x}|{d}:{d}:{d}:{d}:{x}|", .{ c.witty_image_tty_state(), c.witty_image_tty_session(), c.witty_image_tty_refs(), observed_drain, observed_drain_input, observed_buffer, image.width, image.height, @intFromEnum(image.pixelFormat()), image.pixels.len(), image.rawBytes() });
    if (image.pixels.getPalette()) |pal| try out.print("{x}", .{std.mem.sliceAsBytes(pal)}) else try out.writeByte('-');
    try out.print("|{x}|{x}|{x}|{d}:{x}", .{ observed_wire.written(), observed_input.written(), observed_output, observed_pos, observed_pending });
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
    _ = c.witty_image_tty_cleanup();
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
    var f: [9][]const u8 = undefined;
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
    if (c.witty_image_tty_setup() != 0) return error.PtySetupFailed;
    observed_tty = std.mem.span(c.witty_image_tty_path());
    defer {
        if (c.witty_image_tty_cleanup() != 0) @panic("PTY cleanup failed");
    }
    const seed = try allocator.alloc(u8, f[8].len / 2);
    defer allocator.free(seed);
    _ = try std.fmt.hexToBytes(seed, f[8]);
    if (seed.len > 0 and c.witty_image_tty_seed(seed.ptr, seed.len) != seed.len) return error.PtySeedFailed;
    observed_wire = W.Allocating.init(allocator);
    defer observed_wire.deinit();
    observed_input = W.Allocating.init(allocator);
    defer observed_input.deinit();
    observed_drain = -3;
    observed_drain_input = -3;
    observed_output = try allocator.alloc(u8, if (op > 2) try number(usize, f[1]) else 0);
    defer allocator.free(observed_output);
    @memset(observed_output, 182);
    observed_pos = 0;
    var pending = W.Allocating.init(allocator);
    defer pending.deinit();
    observed_pending = &.{};
    const opts = options(@enumFromInt(try number(u8, f[1])), try number(usize, f[3]));
    try snapshot(out, false);
    try out.writeByte('~');
    for (0..try number(usize, f[7])) |_| {
        var status: []const u8 = "ok";
        var result = W.Allocating.init(allocator);
        defer result.deinit();
        if (op == 0) {
            if (std.mem.eql(u8, f[5], "1")) managed.writeToFilePath(observed_tty, buffer, opts) catch |err| {
                status = @errorName(err);
            } else image.writeToFilePath(allocator, observed_tty, buffer, opts) catch |err| {
                status = @errorName(err);
            };
        } else if (op == 1) {
            if (detect(observed_tty, buffer, std.mem.eql(u8, f[5], "1"))) |value| {
                try result.writer.print("{s}", .{@tagName(value)});
            } else |err| {
                status = @errorName(err);
            }
        } else if (op == 2) {
            if (decode(observed_tty, buffer, std.mem.eql(u8, f[5], "1"))) |value| {
                var decoded = value;
                defer decoded.deinit(allocator);
                try result.writer.print("{d}:{d}:{d}", .{ decoded.width, decoded.height, @intFromEnum(decoded.pixelFormat()) });
            } else |err| {
                status = @errorName(err);
            }
        }
        if (op > 2) {
            const file = std.fs.File{ .handle = c.witty_image_tty_keeper_fd() };
            var stream = io.ReadStream.initFile(file, buffer);
            if (op == 3) {
                stream.reader().readSliceAll(observed_output) catch |err| {
                    status = @errorName(err);
                };
            } else {
                if (stream.reader().take(observed_output.len)) |value| {
                    @memcpy(observed_output, value);
                } else |err| {
                    status = @errorName(err);
                }
            }
            observed_pos = stream.getPos();
            pending.clearRetainingCapacity();
            try pending.writer.writeAll(stream.reader().buffered());
            observed_pending = pending.written();
        }
        try out.print("{s}:{s}|", .{ status, if ((op == 1 or op == 2) and std.mem.eql(u8, status, "ok")) result.written() else "-" });
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
    if (std.mem.eql(u8, args[1], "--calibrate")) {
        const writing = try number(c_int, args[2]);
        const noctty = try number(c_int, args[3]);
        if (c.witty_image_tty_setup() != 0) return error.CalibrationSetup;
        const fd = c.witty_image_tty_raw(writing, noctty);
        if (fd < 0) return error.CalibrationOpen;
        const opened = c.witty_image_tty_state();
        if (c.witty_image_tty_raw_close(fd) != 0) return error.CalibrationClose;
        const closed = c.witty_image_tty_state();
        const position_error = c.witty_image_tty_positional_error(writing);
        if (c.witty_image_tty_cleanup() != 0) return error.CalibrationCleanup;
        try output.interface.print("{d}:{d}|{d}:{d}:{d}:{d}\n", .{ writing, noctty, opened, closed, c.witty_image_tty_session(), position_error });
        return;
    }
    if (std.mem.eql(u8, args[1], "--trap")) {
        observed_path = args[2];
        try record(args[3], &row.writer);
        try output.interface.print("{s}\n", .{row.written()});
        return;
    }
    try record(args[1], &row.writer);
    try output.interface.print("{s}\n", .{row.written()});
}
