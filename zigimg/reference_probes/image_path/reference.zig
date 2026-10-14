const std = @import("std");
const Image = @import("src/Image.zig");
const ImageUnmanaged = @import("src/ImageUnmanaged.zig");
const PixelFormat = @import("src/pixel_format.zig").PixelFormat;
const allocator = std.heap.page_allocator;
const W = std.Io.Writer;
const c = @cImport({
    @cDefine("WITTY_IMAGE_PATH_DECLARATIONS", "1");
    @cInclude("fixture_shims.h");
});
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_fd: c_int = -1;
var observed_root: [:0]const u8 = undefined;
var observed_count: c_int = 0;
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
    var bytes: [4096]u8 = undefined;
    const n = c.witty_image_path_bytes(observed_fd, &bytes, bytes.len);
    if (n < 0) return error.ObserverReadFailed;
    const image = observed_image.?;
    try out.print("{d}:{d}:{d}|{x}|{d}:{d}:{d}:{d}:{x}|", .{ c.witty_image_path_valid(observed_fd), c.witty_image_path_count() - observed_count, c.witty_image_path_mode(observed_fd), observed_buffer, image.width, image.height, @intFromEnum(image.pixelFormat()), image.pixels.len(), image.rawBytes() });
    if (image.pixels.getPalette()) |pal| try out.print("{x}", .{std.mem.sliceAsBytes(pal)}) else try out.writeByte('-');
    try out.print("|{x}", .{bytes[0..@intCast(n)]});
}
fn observe(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |state_path| {
        var state = W.Allocating.init(allocator);
        snapshot(&state.writer) catch {};
        if (std.fs.cwd().createFile(state_path, .{})) |file| {
            defer file.close();
            file.writeAll(state.written()) catch {};
        } else |_| {}
    }
    if (c.witty_image_path_cleanup(observed_root, observed_fd) != 0) std.debug.print("OBSERVER CLEANUP ERROR\n", .{});
    std.debug.defaultPanic(message, address);
}
fn path_for_kind(kind: u8) ![]const u8 {
    return switch (kind) {
        0 => std.fmt.allocPrint(allocator, "{s}/missing/child", .{observed_root}),
        1 => std.fmt.allocPrint(allocator, "{s}/seed/child", .{observed_root}),
        2 => std.fmt.allocPrint(allocator, "{s}/dir", .{observed_root}),
        3 => std.fmt.allocPrint(allocator, "{s}/seed", .{observed_root}),
        4 => std.fmt.allocPrint(allocator, "{s}/denied/child", .{observed_root}),
        5 => std.fmt.allocPrint(allocator, "{s}/loop", .{observed_root}),
        6 => std.fmt.allocPrint(allocator, "{s}/dangling", .{observed_root}),
        7 => std.fmt.allocPrint(allocator, "{s}/{s}", .{ observed_root, [_]u8{'a'} ** 256 }),
        8 => allocator.dupe(u8, &([_]u8{'a'} ** 1024)),
        9 => allocator.dupe(u8, ""),
        10 => std.fmt.allocPrint(allocator, "{s}/missing", .{observed_root}),
        11 => std.fmt.allocPrint(allocator, "{s}/seed\x00junk", .{observed_root}),
        12 => allocator.dupe(u8, "\x00"),
        13 => std.fmt.allocPrint(allocator, "{s}/missing/child\x00junk", .{observed_root}),
        14 => allocator.dupe(u8, &(([_]u8{'a'} ** 1024) ++ [_]u8{0})),
        15 => allocator.dupe(u8, &([_]u8{'a'} ** 1023)),
        else => error.InvalidPathKind,
    };
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
    var f: [8][]const u8 = undefined;
    var it = std.mem.splitScalar(u8, line, '|');
    for (&f) |*field| field.* = it.next().?;
    const op = try number(u8, f[0]);
    var backing = try source(try number(usize, f[2]));
    defer backing.deinit(allocator);
    var image = backing;
    if (std.mem.eql(u8, f[7], "1")) image.width = 0;
    if (std.mem.eql(u8, f[7], "2")) image.height = 0;
    if (std.mem.eql(u8, f[7], "3") and image.pixels.len() > 0) image.pixels = image.pixels.slice(0, 1);
    const managed = image.toManaged(allocator);
    observed_image = &image;
    const buffer = try allocator.alloc(u8, try number(usize, f[3]));
    defer allocator.free(buffer);
    @memset(buffer, 165);
    observed_buffer = buffer;
    const kind = try number(u8, f[5]);
    const seed = "\x66\x61\x72\x62\x66\x65\x6c\x64\x00\x00\x00\x01\x00\x00\x00\x01\x00\x13\x00\x38\x00\x5d\xff\xff";
    observed_fd = c.witty_image_path_setup(observed_root, kind, seed.ptr, seed.len);
    if (observed_fd < 0) return error.PathSetupFailed;
    observed_count = c.witty_image_path_count();
    defer {
        if (c.witty_image_path_cleanup(observed_root, observed_fd) != 0) @panic("path cleanup failed");
    }
    const target = try path_for_kind(kind);
    defer allocator.free(target);
    const opts = options(@enumFromInt(try number(u8, f[1])), 0);
    try snapshot(out);
    try out.writeByte('~');
    for (0..try number(usize, f[6])) |_| {
        var status: []const u8 = "ok";
        var result = W.Allocating.init(allocator);
        defer result.deinit();
        if (op == 0) {
            if (std.mem.eql(u8, f[4], "1")) managed.writeToFilePath(target, buffer, opts) catch |err| {
                status = @errorName(err);
            } else image.writeToFilePath(allocator, target, buffer, opts) catch |err| {
                status = @errorName(err);
            };
        } else if (op == 1) {
            if (detect(target, buffer, std.mem.eql(u8, f[4], "1"))) |value| {
                try result.writer.print("{s}", .{@tagName(value)});
            } else |err| {
                status = @errorName(err);
            }
        } else {
            if (decode(target, buffer, std.mem.eql(u8, f[4], "1"))) |value| {
                var decoded = value;
                defer decoded.deinit(allocator);
                try result.writer.print("{d}:{d}:{d}", .{ decoded.width, decoded.height, @intFromEnum(decoded.pixelFormat()) });
            } else |err| {
                status = @errorName(err);
            }
        }
        try out.print("{s}:{s}|", .{ status, if (op != 0 and std.mem.eql(u8, status, "ok")) result.written() else "-" });
        try snapshot(out);
        try out.writeByte('~');
    }
}
pub fn main() !void {
    if (c.witty_image_path_permissions() != 1) return error.UnprivilegedPosixUserRequired;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    var row = W.Allocating.init(allocator);
    defer row.deinit();
    var output = std.fs.File.stdout().writer(&.{});
    if (std.mem.eql(u8, args[1], "--trap")) {
        observed_path = args[2];
        observed_root = try std.fmt.allocPrintSentinel(allocator, "{s}.case", .{args[2]}, 0);
        defer allocator.free(observed_root);
        try record(args[3], &row.writer);
        try output.interface.print("{s}\n", .{row.written()});
        return;
    }
    observed_root = try std.fmt.allocPrintSentinel(allocator, "{s}.case", .{args[1]}, 0);
    defer allocator.free(observed_root);
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
