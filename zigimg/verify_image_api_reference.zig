const std = @import("std");
const Image = @import("src/Image.zig");
const ImageUnmanaged = @import("src/ImageUnmanaged.zig");
const PixelFormat = @import("src/pixel_format.zig").PixelFormat;
const color = @import("src/color.zig");
const allocator = std.heap.page_allocator;

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

fn mix(hash: *u64, value: u64) void {
    hash.* = (hash.* ^ value) *% 1099511628211;
}

fn verifyMatrix() !void {
    var hash: u64 = 14695981039346656037;
    var cases: usize = 0;
    for (std.meta.tags(Image.Format)) |format| {
        for (0..8) |profile| {
            var image = try source(profile);
            defer image.deinit(allocator);
            for (0..3) |variant| {
                const encoder_options = options(format, variant);
                try std.testing.expectEqual(format, std.meta.activeTag(encoder_options));
                for ([_]usize{ 0, 1, 7, 8, 15, 31, 127, 1024 }) |size| {
                    for (0..2) |managed| {
                        const buffer = try allocator.alloc(u8, size);
                        defer allocator.free(buffer);
                        @memset(buffer, 0xa5);
                        mix(&hash, @intFromEnum(format));
                        mix(&hash, profile);
                        mix(&hash, variant);
                        mix(&hash, size);
                        mix(&hash, managed);
                        var code: u64 = 0;
                        const result = (if (managed == 1) image.toManaged(allocator).writeToMemory(buffer, encoder_options) else image.writeToMemory(allocator, buffer, encoder_options)) catch |err| blk: {
                            code = switch (err) {
                                error.Unsupported => 1,
                                error.WriteFailed => 2,
                                error.EndOfStream => 3,
                                error.InvalidData => 4,
                                error.UnfinishedBits => 5,
                                else => return err,
                            };
                            break :blk &.{};
                        };
                        mix(&hash, code);
                        if (code == 0) {
                            mix(&hash, result.len);
                            try std.testing.expectEqual(buffer.ptr, result.ptr);
                        }
                        for (buffer) |byte| mix(&hash, byte);
                        cases += 1;
                        if (std.posix.getenv("WITTY_IMAGE_API_TRACE") != null) std.debug.print("{s} {d} {d} {d} {d} {x:0>16}\n", .{ @tagName(format), profile, variant, size, managed, hash });
                    }
                }
            }
        }
    }
    std.debug.print("image encoder matrix: {d} cases, {x:0>16}\n", .{ cases, hash });
    try std.testing.expectEqual(@as(usize, 6528), cases);
    try std.testing.expectEqual(@as(u64, 0xe49e6984a209c47b), hash);
}

fn verifyCreation() !void {
    for (std.meta.tags(PixelFormat)) |format| {
        var image = try Image.create(allocator, 3, 2, format);
        defer image.deinit();
        try std.testing.expectEqual(@as(usize, 3), image.width);
        try std.testing.expectEqual(@as(usize, 2), image.height);
        try std.testing.expectEqual(format, image.pixelFormat());
        try std.testing.expectEqual(@as(usize, if (format == .invalid) 0 else 6), image.pixels.len());
        try std.testing.expectEqual(@as(usize, 6) * format.pixelStride(), image.imageByteSize());
        try std.testing.expectEqual(@as(usize, 3) * format.pixelStride(), image.rowByteSize());
    }
    var bytes = [_]u8{ 10, 20, 30, 40, 50, 60 };
    var image = try Image.fromRawPixels(allocator, 9, 2, &bytes, .rgb24);
    defer image.deinit();
    try std.testing.expectEqual(@as(usize, 9), image.width);
    try std.testing.expectEqual(@as(usize, 2), image.pixels.len());
    try std.testing.expectEqual(@as(usize, 3), image.rowByteSize());
    try std.testing.expect(image.rawBytes().ptr != &bytes);
    bytes[0] = 100;
    try std.testing.expectEqual(@as(u8, 10), image.rawBytes()[0]);
}

fn verifyViews() !void {
    var image = Image.init(allocator);
    try std.testing.expectEqual(@as(usize, 0), image.width);
    try std.testing.expectEqual(PixelFormat.invalid, image.pixelFormat());
    try std.testing.expect(!image.isAnimation());
    image = try Image.create(allocator, 2, 1, .indexed8);
    defer image.deinit();
    image.pixels.resizePalette(2);
    image.pixels.indexed8.indices[1] = 1;
    image.animation.loop_count = 3;
    try image.animation.frames.append(allocator, .{ .pixels = image.pixels, .duration = 0.5 });
    var view = image.toUnmanaged();
    view.width = 10;
    view.animation.loop_count = 8;
    view.animation.frames.items[0].duration = 0.75;
    view.pixels.resizePalette(3);
    view.pixels.indexed8.indices[0] = 1;
    view.pixels.indexed8.palette[1].r = 91;
    view.pixels.indexed8.indices = view.pixels.indexed8.indices[0..1];
    try std.testing.expectEqual(@as(usize, 2), image.width);
    try std.testing.expectEqual(@as(i32, 3), image.animation.loop_count);
    try std.testing.expectEqual(@as(f32, 0.75), image.animation.frames.items[0].duration);
    try std.testing.expectEqual(@as(usize, 2), image.pixels.len());
    try std.testing.expectEqual(@as(usize, 2), image.pixels.indexed8.palette.len);
    try std.testing.expectEqualSlices(u8, &.{ 1, 1 }, image.rawBytes());
    try std.testing.expectEqual(@as(u8, 91), image.pixels.indexed8.palette[1].r);
    var managed = view.toManaged(allocator);
    managed.pixels.resizePalette(1);
    try std.testing.expectEqual(@as(usize, 3), view.pixels.indexed8.palette.len);
    try std.testing.expectEqual(view.rawBytes().ptr, managed.rawBytes().ptr);
}

fn verifyEditor() !void {
    var bytes = [_]u8{ 10, 20, 30, 40 };
    var image = try Image.fromRawPixels(allocator, 2, 2, &bytes, .grayscale8);
    defer image.deinit();
    bytes[0] = 99;
    try std.testing.expectEqual(@as(u8, 10), image.rawBytes()[0]);
    try image.animation.frames.append(allocator, .{ .pixels = image.pixels, .duration = 0.5 });
    try image.flipVertically();
    try std.testing.expectEqualSlices(u8, &.{ 30, 40, 10, 20 }, image.rawBytes());
    var cropped = try image.crop(allocator, .{ .x = 1, .width = 8, .height = 2 });
    defer cropped.deinit();
    try std.testing.expectEqualSlices(u8, &.{ 40, 20 }, cropped.rawBytes());
    try std.testing.expect(!cropped.isAnimation());
    var iterator = image.iterator();
    try image.convert(.rgba32);
    try std.testing.expectEqual(&image.pixels, iterator.pixels);
    try std.testing.expectEqual(color.Colorf32{ .r = @as(f32, 30) / 255, .g = @as(f32, 30) / 255, .b = @as(f32, 30) / 255, .a = 1 }, iterator.next().?);
    try std.testing.expectEqual(PixelFormat.grayscale8, std.meta.activeTag(image.animation.frames.items[0].pixels));
    const pointer = image.rawBytes().ptr;
    try image.convert(.rgba32);
    try std.testing.expectEqual(pointer, image.rawBytes().ptr);
    try std.testing.expectError(error.NoConversionAvailable, image.convert(.grayscale16));
    try std.testing.expectEqual(pointer, image.rawBytes().ptr);
}

pub fn main() !void {
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(Image.Format));
    try std.testing.expectEqual(@as(usize, 5), @bitSizeOf(Image.Format));
    try verifyCreation();
    try verifyViews();
    try verifyEditor();
    try verifyMatrix();
    const invalid = ImageUnmanaged{ .width = std.math.maxInt(usize), .height = std.math.maxInt(usize) };
    for ([_]Image.Format{ .gif, .iff, .jpeg, .ras, .sgi, .tiff, .xbm }) |format| {
        const result = try invalid.writeToMemory(allocator, &.{}, options(format, 0));
        try std.testing.expectEqual(@as(usize, 0), result.len);
    }
    std.debug.print("PASS: managed image views, edits, conversions, and fixed-memory dispatch\n", .{});
}
