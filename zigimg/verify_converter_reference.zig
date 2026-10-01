const std = @import("std");
const color = @import("src/color.zig");
const Converter = @import("src/PixelFormatConverter.zig");
const ImageUnmanaged = @import("src/ImageUnmanaged.zig");
const PixelFormat = @import("src/pixel_format.zig").PixelFormat;

const formats = std.meta.tags(PixelFormat);

fn mix(hash: *u64, value: u64) void {
    hash.* = (hash.* ^ value) *% 1099511628211;
}

fn badUnion(source: PixelFormat, destination: PixelFormat) bool {
    return source == .bgr555 and switch (destination) {
        .rgb555, .rgb565, .rgb24, .rgba32, .bgr24, .bgra32, .rgb48, .rgba64, .float32 => true,
        else => false,
    };
}

fn emptyAlignment(source: PixelFormat, destination: PixelFormat, count: usize) bool {
    return count == 0 and (((source == .rgba32 or source == .bgra32) and destination == .float32) or (source == .float32 and (destination == .rgba32 or destination == .bgra32)));
}

fn pixels(allocator: std.mem.Allocator, format: PixelFormat, count: usize, seed: usize, ordinal: usize) !color.PixelStorage {
    var result = try color.PixelStorage.init(allocator, format, count);
    const bytes = result.asBytes();
    for (bytes, 0..) |*byte, i| byte.* = @truncate(i * 73 + ordinal * 19 + seed * 29);
    if (format == .invalid) return result;
    if (format.isIndexed()) {
        const capacity: usize = @as(usize, 1) << @intCast(format.bitsPerChannel());
        const active = @min(capacity, 11);
        result.resizePalette(active);
        const palette = result.getPalette().?;
        for (palette, 0..) |*entry, i| entry.* = .{
            .r = @truncate(i * 31 + seed * 17),
            .g = @truncate(i * 71 + seed * 29),
            .b = @truncate(i * 113 + seed * 41),
            .a = @truncate(i * 47 + seed * 53),
        };
        inline for (.{ .indexed1, .indexed2, .indexed4, .indexed8, .indexed16 }) |tag| {
            if (format == tag) {
                const indexed = @field(result, @tagName(tag));
                for (indexed.indices, 0..) |*entry, i| entry.* = @intCast((i * 7 + seed) % active);
            }
        }
    } else if (format == .float32) {
        for (result.float32, 0..) |*entry, i| entry.* = .{
            .r = @as(f32, @floatFromInt((i * 31 + seed * 17) % 257)) / 256.0,
            .g = @as(f32, @floatFromInt((i * 71 + seed * 29) % 257)) / 256.0,
            .b = @as(f32, @floatFromInt((i * 113 + seed * 41) % 257)) / 256.0,
            .a = @as(f32, @floatFromInt((i * 47 + seed * 53) % 257)) / 256.0,
        };
    } else {
        // Keep sub-byte values and packed padding defined in the input.
        inline for (.{ .grayscale1, .grayscale2, .grayscale4 }) |tag| {
            if (format == tag) {
                for (@field(result, @tagName(tag)), 0..) |*entry, i| entry.value = @truncate(i * 73 + ordinal * 19 + seed * 29);
            }
        }
        if (format == .rgb555 or format == .bgr555) {
            for (0..count) |i| bytes[i * 2 + 1] &= 0x7f;
        }
    }
    return result;
}

fn verifyMatrix() !u64 {
    var hash: u64 = 14695981039346656037;
    var cases: usize = 0;
    for (formats, 0..) |source_format, ordinal| {
        for (formats) |destination_format| {
            for ([_]usize{ 0, 1, 3, 4, 5, 9, 17, 64 }) |count| {
                for (0..4) |seed| {
                    // Individual page allocations satisfy the source's f32 alignCast.
                    // An align(1) arena need not do so; allocator-dependent alignment
                    // remains a separately documented representation boundary.
                    const allocator = std.heap.page_allocator;
                    var source = try pixels(allocator, source_format, count, seed, ordinal);
                    defer source.deinit(allocator);
                    mix(&hash, @intFromEnum(source_format));
                    mix(&hash, @intFromEnum(destination_format));
                    mix(&hash, count);
                    mix(&hash, seed);
                    cases += 1;
                    if (std.posix.getenv("WITTY_CONVERTER_TRACE") != null) std.debug.print("{d} {s} {d} {d} {x:0>16}\n", .{ ordinal, @tagName(destination_format), count, seed, hash });
                    if (badUnion(source_format, destination_format)) {
                        mix(&hash, 3);
                        continue;
                    }
                    if (emptyAlignment(source_format, destination_format, count)) {
                        mix(&hash, 4);
                        continue;
                    }
                    var destination = Converter.convert(allocator, &source, destination_format) catch |err| {
                        mix(&hash, switch (err) {
                            error.NoConversionNeeded => 1,
                            error.NoConversionAvailable => 2,
                            else => return err,
                        });
                        continue;
                    };
                    defer destination.deinit(allocator);
                    mix(&hash, 0);
                    mix(&hash, destination.len());
                    for (destination.asBytes(), 0..) |byte, i| {
                        const defined = if ((destination_format == .rgb555 or destination_format == .bgr555) and i % 2 == 1) byte & 0x7f else byte;
                        mix(&hash, defined);
                    }
                    if (destination.getPalette()) |palette| {
                        mix(&hash, palette.len);
                        const defined = if (source_format.isIndexed() and source_format != .invalid and source_format.bitsPerChannel() < destination_format.bitsPerChannel()) source.getPalette().?.len else palette.len;
                        for (palette[0..defined]) |entry| {
                            mix(&hash, entry.r);
                            mix(&hash, entry.g);
                            mix(&hash, entry.b);
                            mix(&hash, entry.a);
                        }
                    }
                }
            }
        }
    }
    std.debug.print("converter matrix: {d} cases, {x}\n", .{ cases, hash });
    return hash;
}

fn verifyExamples() !void {
    const allocator = std.heap.page_allocator;
    var source = try color.PixelStorage.init(allocator, .rgba32, 1);
    defer source.deinit(allocator);
    source.rgba32[0] = .{ .r = 240, .g = 128, .b = 64, .a = 128 };
    var rgb = try Converter.convert(allocator, &source, .rgb24);
    defer rgb.deinit(allocator);
    try std.testing.expectEqual(color.Rgb24.from.rgb(120, 64, 32), rgb.rgb24[0]);
    var small = try Converter.convert(allocator, &source, .rgb332);
    defer small.deinit(allocator);
    try std.testing.expectEqual(color.Rgb332.from.rgb(7, 4, 1), small.rgb332[0]);
    var floats = try color.PixelStorage.init(allocator, .float32, 5);
    defer floats.deinit(allocator);
    @memset(floats.float32, .{ .r = 0.5, .g = 0.25, .b = 0.75, .a = 0.5 });
    var rounded = try Converter.convert(allocator, &floats, .rgba32);
    defer rounded.deinit(allocator);
    for (rounded.rgba32[0..4]) |entry| try std.testing.expectEqual(color.Rgba32.from.rgba(127, 63, 191, 127), entry);
    try std.testing.expectEqual(color.Rgba32.from.rgba(128, 64, 191, 128), rounded.rgba32[4]);
    @memset(floats.float32, .{ .r = -0.001, .g = 1.003, .b = 0.5, .a = 1 });
    var fractional = try Converter.convert(allocator, &floats, .rgba32);
    defer fractional.deinit(allocator);
    try std.testing.expectEqual(color.Rgba32.from.rgba(0, 255, 127, 255), fractional.rgba32[0]);
    try std.testing.expectEqual(color.Rgba32.from.rgba(0, 255, 128, 255), fractional.rgba32[4]);
    @memset(floats.float32, .{ .r = std.math.nan(f32) });
    var nan = try Converter.convert(allocator, &floats, .rgba32);
    defer nan.deinit(allocator);
    for (nan.rgba32[0..4]) |entry| try std.testing.expectEqual(color.Rgba32.from.rgb(0, 0, 0), entry);
    try std.testing.expectEqual(color.Rgba32.from.rgb(255, 0, 0), nan.rgba32[4]);
    var gray_source = try pixels(allocator, .rgba64, 3, 0, 22);
    defer gray_source.deinit(allocator);
    var gray = try Converter.convert(allocator, &gray_source, .grayscale8Alpha);
    defer gray.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{ 140, 161, 158, 233, 47, 50 }, gray.asBytes());
    var palette_source = try pixels(allocator, .indexed8, 0, 0, 4);
    defer palette_source.deinit(allocator);
    var indexed = try Converter.convert(allocator, &palette_source, .indexed4);
    defer indexed.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 16), indexed.indexed4.palette.len);
    for (indexed.indexed4.palette[11..]) |entry| try std.testing.expectEqual(color.Rgba32.from.rgb(0, 0, 0), entry);
    // Unlike allocated zero-length storage, a borrowed empty float view can
    // retain an aligned pointer and pass the unconditional source cast.
    var owner = try color.PixelStorage.init(allocator, .float32, 1);
    defer owner.deinit(allocator);
    var empty_view = owner.slice(0, 0);
    for ([_]PixelFormat{ .rgba32, .bgra32 }) |format| {
        var empty_result = try Converter.convert(allocator, &empty_view, format);
        defer empty_result.deinit(allocator);
        try std.testing.expectEqual(@as(usize, 0), empty_result.len());
    }
}

fn verifyPrecision() !u64 {
    const allocator = std.heap.page_allocator;
    var hash: u64 = 14695981039346656037;
    var pixels_checked: usize = 0;
    for ([_]PixelFormat{ .rgb332, .rgb555, .bgr555, .rgb565, .rgba32, .rgba64, .grayscale16Alpha, .float32 }) |format| {
        const count: usize = if (format == .rgb332) 256 else if (format == .rgb555 or format == .bgr555) 32768 else 65536;
        var source = try color.PixelStorage.init(allocator, format, count);
        defer source.deinit(allocator);
        for (0..count) |i| switch (format) {
            .rgb332 => source.rgb332[i] = color.Rgb332.from.rgb(@truncate(i), @truncate(i >> 3), @truncate(i >> 6)),
            .rgb555 => source.rgb555[i] = color.Rgb555.from.rgb(@truncate(i >> 10), @truncate(i >> 5), @truncate(i)),
            .bgr555 => source.bgr555[i] = color.Bgr555.from.rgb(@truncate(i), @truncate(i >> 5), @truncate(i >> 10)),
            .rgb565 => source.rgb565[i] = color.Rgb565.from.rgb(@truncate(i >> 11), @truncate(i >> 5), @truncate(i)),
            .rgba32 => source.rgba32[i] = color.Rgba32.from.rgba(@truncate(i), @truncate(i * 13), @truncate(i * 29), @truncate(i >> 8)),
            .rgba64 => source.rgba64[i] = color.Rgba64.from.rgba(@truncate(i), @truncate(i * 13), @truncate(i * 29), @truncate(i * 17 + 11)),
            .grayscale16Alpha => source.grayscale16Alpha[i] = .{ .value = @truncate(i), .alpha = @truncate(i * 17 + 11) },
            .float32 => source.float32[i] = .{
                .r = @as(f32, @floatFromInt(i)) / 65535,
                .g = @as(f32, @floatFromInt((i * 13) % 65536)) / 65535,
                .b = @as(f32, @floatFromInt((i * 29) % 65536)) / 65535,
                .a = @as(f32, @floatFromInt((i * 17 + 11) % 65536)) / 65535,
            },
            else => unreachable,
        };
        for (formats) |destination_format| {
            if (destination_format.isIndexed() or destination_format == format or badUnion(format, destination_format)) continue;
            mix(&hash, @intFromEnum(format));
            mix(&hash, @intFromEnum(destination_format));
            var destination = Converter.convert(allocator, &source, destination_format) catch |err| {
                if (err != error.NoConversionAvailable) return err;
                mix(&hash, 2);
                continue;
            };
            defer destination.deinit(allocator);
            mix(&hash, 0);
            pixels_checked += count;
            for (destination.asBytes(), 0..) |byte, i| {
                mix(&hash, if ((destination_format == .rgb555 or destination_format == .bgr555) and i % 2 == 1) byte & 0x7f else byte);
            }
        }
    }
    std.debug.print("converter precision: {d} pixels, {x}\n", .{ pixels_checked, hash });
    try std.testing.expectEqual(@as(usize, 6066176), pixels_checked);
    try std.testing.expectEqual(@as(u64, 0x9014fb50e8722857), hash);
    return hash;
}

fn verifyImage() !void {
    const allocator = std.heap.page_allocator;
    var image = ImageUnmanaged{ .width = 1, .height = 1, .pixels = try color.PixelStorage.init(allocator, .rgba32, 1) };
    defer image.deinit(allocator);
    image.pixels.rgba32[0] = .{ .r = 240, .g = 128, .b = 64, .a = 128 };
    var frame_pixels = try color.PixelStorage.init(allocator, .rgb24, 1);
    defer frame_pixels.deinit(allocator);
    frame_pixels.rgb24[0] = .{ .r = 7, .g = 8, .b = 9 };
    try image.animation.frames.append(allocator, .{ .pixels = frame_pixels, .duration = 0.25 });
    const before = image.pixels.asBytes().ptr;
    try image.convert(allocator, .rgba32);
    try std.testing.expect(image.pixels.asBytes().ptr == before);
    try image.convert(allocator, .rgb24);
    try std.testing.expectEqualSlices(u8, &.{ 120, 64, 32 }, image.pixels.asBytes());
    try std.testing.expectEqualSlices(u8, &.{ 7, 8, 9 }, image.animation.frames.items[0].pixels.asBytes());
    try std.testing.expectEqual(@as(f32, 0.25), image.animation.frames.items[0].duration);
    const old_pixels = image.pixels;
    defer old_pixels.deinit(allocator);
    try image.convertNoFree(allocator, .rgba64);
    const before_error = image.pixels.asBytes().ptr;
    try std.testing.expectError(error.NoConversionAvailable, image.convert(allocator, .grayscale16));
    try std.testing.expect(image.pixels.asBytes().ptr == before_error);
}

pub fn main() !void {
    try verifyExamples();
    try std.testing.expectEqual(@as(u64, 0xe9de0fd7efd93e19), try verifyMatrix());
    _ = try verifyPrecision();
    try verifyImage();
    std.debug.print("PASS: unchanged locked pixel-format converter\n", .{});
}
