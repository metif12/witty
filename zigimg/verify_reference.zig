// Run against the unmodified, locked zigimg module with Zig 0.15.2.
// This file verifies reference behavior; production code is V.
const std = @import("std");
const zigimg = @import("zigimg");

pub fn main() !void {
    const encoded = "qoif\x00\x00\x00\x08\x00\x00\x00\x01\x04\x00" ++
        "\xfe\x0a\x14\x1e\x7f\xa2\x97\xff\x64\x96\xc8\x32\xc1\x09\x00";
    var reader = zigimg.io.ReadStream.initMemory(encoded);
    var qoi = zigimg.formats.qoi.QOI{};
    const pixels = try qoi.read(std.heap.page_allocator, &reader);
    defer pixels.deinit(std.heap.page_allocator);
    try std.testing.expectEqualSlices(u8, &.{ 10, 20, 30, 255, 11, 21, 31, 255, 14, 23, 32, 255, 100, 150, 200, 50, 100, 150, 200, 50, 100, 150, 200, 50, 10, 20, 30, 255, 0, 0, 0, 0 }, pixels.asBytes());
    try std.testing.expectEqual(encoded.len, reader.getPos());
    var output: [100]u8 = undefined;
    var writer = zigimg.io.WriteStream.initMemory(&output);
    try qoi.write(&writer, pixels);
    try std.testing.expectEqualSlices(u8, encoded ++ "\x00\x00\x00\x00\x00\x00\x00\x01", writer.memory.buffered());

    const farbfeld = "farbfeld\x00\x00\x00\x02\x00\x00\x00\x01" ++
        "\xff\xff\x12\x34\x00\x99\x80\x00\x00\x00\xff\xff\xbe\xef\x00\x01";
    reader = zigimg.io.ReadStream.initMemory(farbfeld);
    var ff = try zigimg.formats.farbfeld.Farbfeld.readImage(std.heap.page_allocator, &reader);
    defer ff.deinit(std.heap.page_allocator);
    try std.testing.expectEqual(zigimg.color.Rgba64{ .r = 0xffff, .g = 0x1234, .b = 0x99, .a = 0x8000 }, ff.pixels.rgba64[0]);
    writer = zigimg.io.WriteStream.initMemory(&output);
    try zigimg.formats.farbfeld.Farbfeld.writeImage(std.heap.page_allocator, &writer, ff, .{ .farbfeld = {} });
    try std.testing.expectEqualSlices(u8, farbfeld, writer.memory.buffered());

    var png_pixels = [_]zigimg.color.Rgba32{ .{ .r = 1, .g = 2, .b = 3 }, .{ .r = 4, .g = 5, .b = 6 } };
    const png = zigimg.ImageUnmanaged{ .width = 2, .height = 1, .pixels = .{ .rgba32 = &png_pixels } };
    writer = zigimg.io.WriteStream.initMemory(&output);
    try zigimg.formats.png.PNG.writeImage(std.heap.page_allocator, &writer, png, .{ .png = .{} });
    try std.testing.expectEqualSlices(u8, "\x89PNG\x0d\x0a\x1a\x0a", writer.memory.buffered());
    writer = zigimg.io.WriteStream.initMemory(output[0..4]);
    try std.testing.expectError(error.WriteFailed, zigimg.formats.png.PNG.writeImage(std.heap.page_allocator, &writer, png, .{ .png = .{} }));
    try std.testing.expectEqualSlices(u8, "\x89PNG", writer.memory.buffered());
    try verifyEditing();
    try verifyIteration();
    try @import("verify_netpbm_reference.zig").verify();
    try @import("verify_ras_reference.zig").verify();
    try @import("verify_sgi_reference.zig").verify();
    try @import("verify_pam_reference.zig").verify();
    try @import("verify_xbm_reference.zig").verify();
    try @import("verify_pcx_reference.zig").verify();
    try @import("verify_bmp_reference.zig").verify();
    try @import("verify_iff_reference.zig").verify();
    try @import("verify_gif_reference.zig").verify();
    try @import("verify_tga_reference.zig").verify();
    std.debug.print("PASS: locked codecs (QOI/farbfeld/PNG/PBM/PGM/PPM/RAS/SGI/PAM/XBM/PCX/BMP/IFF/GIF/TGA), editing, pixel iteration, and bit streams\n", .{});
}

fn verifyEditing() !void {
    const allocator = std.heap.page_allocator;
    var bytes: [36]u8 = undefined;
    for (&bytes, 0..) |*byte, i| byte.* = @intCast(i);
    const image = zigimg.ImageUnmanaged{
        .width = 4,
        .height = 3,
        .pixels = .{ .rgb24 = std.mem.bytesAsSlice(zigimg.color.Rgb24, &bytes) },
        .animation = .{ .loop_count = 7 },
    };
    var cropped = try image.crop(allocator, .{ .x = 1, .y = 1, .width = 2, .height = 10 });
    defer cropped.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 2), cropped.width);
    try std.testing.expectEqual(@as(usize, 2), cropped.height);
    try std.testing.expectEqualSlices(u8, &.{ 15, 16, 17, 18, 19, 20, 27, 28, 29, 30, 31, 32 }, cropped.rawBytes());
    try std.testing.expectEqual(@as(i32, -1), cropped.animation.loop_count);
    try image.flipVertically(allocator);
    try std.testing.expectEqualSlices(u8, &.{ 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35 }, bytes[0..12]);
    try std.testing.expectEqualSlices(u8, &.{ 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23 }, bytes[12..24]);
    try image.flipVertically(allocator);
    for (bytes, 0..) |byte, i| try std.testing.expectEqual(@as(u8, @intCast(i)), byte);

    var indexed = try zigimg.color.PixelStorage.init(allocator, .indexed4, 6);
    defer indexed.deinit(allocator);
    indexed.resizePalette(3);
    @memcpy(indexed.indexed4.indices, &[_]u4{ 0, 1, 2, 2, 1, 0 });
    indexed.indexed4.palette[1] = .{ .r = 10, .g = 20, .b = 30, .a = 40 };
    const indexed_image = zigimg.ImageUnmanaged{ .width = 3, .height = 2, .pixels = indexed };
    var indexed_crop = try indexed_image.crop(allocator, .{ .x = 1, .width = 9, .height = 2 });
    defer indexed_crop.deinit(allocator);
    try std.testing.expectEqualSlices(u4, &.{ 1, 2, 1, 0 }, indexed_crop.pixels.indexed4.indices);
    try std.testing.expectEqualSlices(zigimg.color.Rgba32, indexed.indexed4.palette, indexed_crop.pixels.indexed4.palette);
    try std.testing.expect(indexed.indexed4.palette.ptr != indexed_crop.pixels.indexed4.palette.ptr);
    indexed.indexed4.palette[1].r = 90;
    try std.testing.expectEqual(@as(u8, 10), indexed_crop.pixels.indexed4.palette[1].r);
    var empty = try indexed_image.crop(allocator, .{ .x = 3, .width = 2, .height = 2 });
    defer empty.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), empty.width);
    try std.testing.expectEqual(@as(usize, 2), empty.height);
    try std.testing.expectEqual(@as(usize, 3), empty.pixels.indexed4.palette.len);
    try std.testing.expectEqual(@as(u8, 90), empty.pixels.indexed4.palette[1].r);
}

fn expectIterator(pixels: zigimg.color.PixelStorage, expected: zigimg.color.Colorf32) !void {
    var iter = zigimg.color.PixelStorageIterator.init(&pixels);
    try std.testing.expectEqual(expected, iter.next().?);
    try std.testing.expectEqual(@as(usize, 1), iter.current_index);
    try std.testing.expect(iter.next() == null);
    try std.testing.expectEqual(@as(usize, 1), iter.current_index);
}

fn verifyIteration() !void {
    const gray8 = @as(f32, 85) / 255;
    const gray16 = @as(f32, 32768) / 65535;
    try expectIterator(.{ .grayscale1 = @constCast(&[_]zigimg.color.Grayscale1{.{ .value = 1 }}) }, .{ .r = 1, .g = 1, .b = 1 });
    try expectIterator(.{ .grayscale2 = @constCast(&[_]zigimg.color.Grayscale2{.{ .value = 1 }}) }, .{ .r = @as(f32, 1) / 3, .g = @as(f32, 1) / 3, .b = @as(f32, 1) / 3 });
    try expectIterator(.{ .grayscale4 = @constCast(&[_]zigimg.color.Grayscale4{.{ .value = 5 }}) }, .{ .r = @as(f32, 5) / 15, .g = @as(f32, 5) / 15, .b = @as(f32, 5) / 15 });
    try expectIterator(.{ .grayscale8 = @constCast(&[_]zigimg.color.Grayscale8{.{ .value = 85 }}) }, .{ .r = gray8, .g = gray8, .b = gray8 });
    try expectIterator(.{ .grayscale16 = @constCast(&[_]zigimg.color.Grayscale16{.{ .value = 32768 }}) }, .{ .r = gray16, .g = gray16, .b = gray16 });
    try expectIterator(.{ .grayscale8Alpha = @constCast(&[_]zigimg.color.Grayscale8Alpha{.{ .value = 85, .alpha = 0 }}) }, .{ .r = gray8, .g = gray8, .b = gray8, .a = 0 });
    try expectIterator(.{ .grayscale16Alpha = @constCast(&[_]zigimg.color.Grayscale16Alpha{.{ .value = 32768, .alpha = 16384 }}) }, .{ .r = gray16, .g = gray16, .b = gray16, .a = @as(f32, 16384) / 65535 });
    try expectIterator(.{ .rgb332 = @constCast(&[_]zigimg.color.Rgb332{.{ .r = 5, .g = 3, .b = 2 }}) }, .{ .r = @as(f32, 5) / 7, .g = @as(f32, 3) / 7, .b = @as(f32, 2) / 3 });
    try expectIterator(.{ .rgb555 = @constCast(&[_]zigimg.color.Rgb555{.{ .r = 17, .g = 9, .b = 3 }}) }, .{ .r = @as(f32, 17) / 31, .g = @as(f32, 9) / 31, .b = @as(f32, 3) / 31 });
    try expectIterator(.{ .bgr555 = @constCast(&[_]zigimg.color.Bgr555{.{ .r = 17, .g = 9, .b = 3 }}) }, .{ .r = @as(f32, 17) / 31, .g = @as(f32, 9) / 31, .b = @as(f32, 3) / 31 });
    try expectIterator(.{ .rgb565 = @constCast(&[_]zigimg.color.Rgb565{.{ .r = 17, .g = 35, .b = 3 }}) }, .{ .r = @as(f32, 17) / 31, .g = @as(f32, 35) / 63, .b = @as(f32, 3) / 31 });
    try expectIterator(.{ .rgb24 = @constCast(&[_]zigimg.color.Rgb24{.{ .r = 255, .g = 85, .b = 0 }}) }, .{ .r = 1, .g = gray8 });
    try expectIterator(.{ .rgba32 = @constCast(&[_]zigimg.color.Rgba32{.{ .r = 255, .g = 85, .b = 0, .a = 0 }}) }, .{ .r = 1, .g = gray8, .a = 0 });
    try expectIterator(.{ .bgr24 = @constCast(&[_]zigimg.color.Bgr24{.{ .r = 255, .g = 85, .b = 0 }}) }, .{ .r = 1, .g = gray8 });
    try expectIterator(.{ .bgra32 = @constCast(&[_]zigimg.color.Bgra32{.{ .r = 255, .g = 85, .b = 0, .a = 0 }}) }, .{ .r = 1, .g = gray8, .a = 0 });
    try expectIterator(.{ .rgb48 = @constCast(&[_]zigimg.color.Rgb48{.{ .r = 65535, .g = 32768, .b = 0 }}) }, .{ .r = 1, .g = gray16 });
    try expectIterator(.{ .rgba64 = @constCast(&[_]zigimg.color.Rgba64{.{ .r = 65535, .g = 32768, .b = 0, .a = 0 }}) }, .{ .r = 1, .g = gray16, .a = 0 });
    try expectIterator(.{ .float32 = @constCast(&[_]zigimg.color.Colorf32{.{ .r = -2, .g = 3, .b = 0.25, .a = 0.75 }}) }, .{ .r = -2, .g = 3, .b = 0.25, .a = 0.75 });

    var pixels = zigimg.color.PixelStorage{ .rgb24 = @constCast(&[_]zigimg.color.Rgb24{ .{ .r = 1 }, .{ .r = 2 } }) };
    var iter = zigimg.color.PixelStorageIterator.init(&pixels);
    pixels = .{ .float32 = @constCast(&[_]zigimg.color.Colorf32{ .{ .g = 0.25 }, .{ .g = 0.5 }, .{ .g = 0.75 } }) };
    try std.testing.expectEqual(zigimg.color.Colorf32{ .g = 0.25 }, iter.next().?);
    try std.testing.expectEqual(zigimg.color.Colorf32{ .g = 0.5 }, iter.next().?);
    try std.testing.expect(iter.next() == null);
    const palette = &[_]zigimg.color.Rgba32{ .{ .r = 255, .g = 85, .a = 0 }, .{ .b = 255, .a = 128 } };
    inline for (.{ u1, u2, u4, u8, u16 }, .{ .indexed1, .indexed2, .indexed4, .indexed8, .indexed16 }) |Index, tag| {
        const indexed = @unionInit(zigimg.color.PixelStorage, @tagName(tag), .{
            .palette = @constCast(palette),
            .indices = @constCast(&[_]Index{ 1, 0 }),
        });
        var indexed_iter = zigimg.color.PixelStorageIterator.init(&indexed);
        try std.testing.expectEqual(zigimg.color.Colorf32{ .b = 1, .a = @as(f32, 128) / 255 }, indexed_iter.next().?);
        try std.testing.expectEqual(zigimg.color.Colorf32{ .r = 1, .g = gray8, .a = 0 }, indexed_iter.next().?);
        try std.testing.expect(indexed_iter.next() == null);
    }
    const invalid: zigimg.color.PixelStorage = .invalid;
    var empty = zigimg.color.PixelStorageIterator.init(&invalid);
    try std.testing.expect(empty.next() == null);
    empty.end = 1;
    try std.testing.expectEqual(zigimg.color.Colorf32{}, empty.next().?);
}
