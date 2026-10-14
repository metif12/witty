const std = @import("std");
const Image = @import("src/Image.zig");
const ImageUnmanaged = @import("src/ImageUnmanaged.zig");
const PixelFormat = @import("src/pixel_format.zig").PixelFormat;
const allocator = std.heap.page_allocator;
const W = std.Io.Writer;
const c = @cImport({
    @cDefine("WITTY_IMAGE_OPEN_DECLARATIONS", "1");
    @cInclude("fixture_shims.h");
});
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_root: [:0]const u8 = undefined;
var observed_target: [:0]const u8 = undefined;
var observed_exe: [:0]const u8 = undefined;
var observed_mask: c_int = 0;
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

fn disk(out: *W, file_path: [:0]const u8) !void {
    var bytes: [4096]u8 = undefined;
    const n = c.witty_image_open_bytes(file_path, &bytes, bytes.len);
    if (n < 0) try out.writeByte('-') else try out.print("{x}", .{bytes[0..@intCast(n)]});
}
fn snapshot(out: *W) !void {
    const fd = c.witty_image_open_find(observed_target);
    if (fd == -2) return error.MultipleOwnedDescriptors;
    if (fd < 0) try out.writeByte('-') else try out.print("{d}:{d}:{d}:{d}", .{ c.witty_image_open_flag(fd, 0), c.witty_image_open_flag(fd, 1), c.witty_image_open_flag(fd, 2), c.witty_image_open_exec(observed_exe, fd) });
    const image = observed_image.?;
    try out.print("|{d}:{d}|{x}|{d}:{d}:{d}:{d}:{x}|", .{ c.witty_image_open_kind(observed_target), c.witty_image_open_mode(observed_target), observed_buffer, image.width, image.height, @intFromEnum(image.pixelFormat()), image.pixels.len(), image.rawBytes() });
    if (image.pixels.getPalette()) |pal| try out.print("{x}", .{std.mem.sliceAsBytes(pal)}) else try out.writeByte('-');
    try out.writeByte('|');
    try disk(out, observed_target);
    try out.writeByte('|');
    const seed = try std.fmt.allocPrintSentinel(allocator, "{s}/seed", .{observed_root}, 0);
    defer allocator.free(seed);
    try disk(out, seed);
}
fn observe(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |state_path| {
        var state = W.Allocating.init(allocator);
        snapshot(&state.writer) catch {};
        _ = c.witty_image_open_mask(observed_mask);
        if (std.fs.cwd().createFile(state_path, .{})) |file| {
            defer file.close();
            file.writeAll(state.written()) catch {};
        } else |_| {}
    }
    if (c.witty_image_open_cleanup(observed_root) != 0) std.debug.print("OBSERVER CLEANUP ERROR\n", .{});
    std.debug.defaultPanic(message, address);
}
fn number(comptime T: type, value: []const u8) !T {
    return std.fmt.parseInt(T, value, 10);
}
fn record(line: []const u8, out: *W, ready: ?[:0]const u8) !void {
    var f: [9][]const u8 = undefined;
    var it = std.mem.splitScalar(u8, line, '|');
    for (&f) |*field| field.* = it.next().?;
    const op = try number(u8, f[0]);
    var image = try source(try number(usize, f[2]));
    defer image.deinit(allocator);
    if (std.mem.eql(u8, f[7], "1")) image.width = 0;
    observed_image = &image;
    const managed = image.toManaged(allocator);
    const buffer = try allocator.alloc(u8, try number(usize, f[3]));
    defer allocator.free(buffer);
    @memset(buffer, 165);
    observed_buffer = buffer;
    const seed = if (op == 0) &([_]u8{165} ** 256) else "#define w 8\n";
    if (c.witty_image_open_setup(observed_root, try number(c_int, f[5]), seed.ptr, seed.len) != 0) return error.OpenFixtureSetupFailed;
    observed_target = try std.fmt.allocPrintSentinel(allocator, "{s}/target", .{observed_root}, 0);
    defer allocator.free(observed_target);
    observed_mask = c.witty_image_open_mask(try number(c_int, f[6]));
    defer {
        _ = c.witty_image_open_mask(observed_mask);
        if (c.witty_image_open_cleanup(observed_root) != 0) @panic("open fixture cleanup failed");
    }
    if (ready) |name| {
        if (c.witty_image_open_watch(observed_target, name, observed_exe) != 0) return error.OpenWatcherFailed;
    }
    const opts = options(@enumFromInt(try number(u8, f[1])), 0);
    try snapshot(out);
    try out.writeByte('~');
    for (0..try number(usize, f[8])) |_| {
        var status: []const u8 = "ok";
        if (op == 0) {
            if (std.mem.eql(u8, f[4], "1")) managed.writeToFilePath(observed_target, buffer, opts) catch |err| {
                status = @errorName(err);
            } else image.writeToFilePath(allocator, observed_target, buffer, opts) catch |err| {
                status = @errorName(err);
            };
        } else if (op == 1) {
            if (std.mem.eql(u8, f[4], "1")) {
                _ = Image.detectFormatFromFilePath(observed_target, buffer) catch |err| {
                    status = @errorName(err);
                };
            } else {
                _ = ImageUnmanaged.detectFormatFromFilePath(observed_target, buffer) catch |err| {
                    status = @errorName(err);
                };
            }
        } else {
            if (std.mem.eql(u8, f[4], "1")) {
                _ = Image.fromFilePath(allocator, observed_target, buffer) catch |err| {
                    status = @errorName(err);
                };
            } else {
                _ = ImageUnmanaged.fromFilePath(allocator, observed_target, buffer) catch |err| {
                    status = @errorName(err);
                };
            }
        }
        try out.print("{s}|", .{status});
        try snapshot(out);
        try out.writeByte('~');
    }
}
pub fn main() !void {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (std.mem.eql(u8, args[1], "--child")) {
        std.process.exit(@intCast(c.witty_image_open_child(try number(c_int, args[2]), try number(u64, args[3]), try number(u64, args[4]))));
    }
    observed_exe = try allocator.dupeZ(u8, args[0]);
    defer allocator.free(observed_exe);
    var row = W.Allocating.init(allocator);
    defer row.deinit();
    var output = std.fs.File.stdout().writer(&.{});
    if (std.mem.eql(u8, args[1], "--trap")) {
        observed_path = args[2];
        observed_root = try std.fmt.allocPrintSentinel(allocator, "{s}.case", .{args[2]}, 0);
        defer allocator.free(observed_root);
        try record(args[3], &row.writer, null);
        try output.interface.print("{s}\n", .{row.written()});
        return;
    }
    if (std.mem.eql(u8, args[1], "--loop")) {
        observed_root = try std.fmt.allocPrintSentinel(allocator, "{s}.case", .{args[2]}, 0);
        defer allocator.free(observed_root);
        const ready = try allocator.dupeZ(u8, args[2]);
        defer allocator.free(ready);
        try record(args[3], &row.writer, ready);
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
        try record(line, &row.writer, null);
        try output.interface.print("{s}\n", .{row.written()});
    }
}
