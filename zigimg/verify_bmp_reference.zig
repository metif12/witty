const std = @import("std");
const zigimg = @import("zigimg");
const bmp = zigimg.formats.bmp;
const allocator = std.heap.page_allocator;

fn fixture(output: []u8, file: bmp.BitmapFileHeader, info: bmp.BitmapInfoHeader, data: []const u8) ![]const u8 {
    var writer = std.Io.Writer.fixed(output);
    try writer.writeStruct(file, .little);
    switch (info) {
        inline else => |header| try writer.writeStruct(header, .little),
    }
    try writer.writeAll(data);
    return writer.buffered();
}

pub fn verify() !void {
    try std.testing.expectEqual(@as(usize, 14), @sizeOf(bmp.BitmapFileHeader));
    try std.testing.expectEqual(@as(usize, 40), @sizeOf(bmp.BitmapInfoHeaderWindows31));
    try std.testing.expectEqual(@as(usize, 108), @sizeOf(bmp.BitmapInfoHeaderV4));
    try std.testing.expectEqual(@as(usize, 124), @sizeOf(bmp.BitmapInfoHeaderV5));
    try std.testing.expectEqual(@as(u32, 0x73524742), @intFromEnum(bmp.BitmapColorSpace.srgb));
    try std.testing.expectEqual(@as(u32, 0x57696e20), @intFromEnum(bmp.BitmapColorSpace.windows_color_space));
    try std.testing.expectEqual(@as(u32, 0x4c494e4b), @intFromEnum(bmp.BitmapColorSpace.profile_linked));
    try std.testing.expectEqual(@as(u32, 0x4d424544), @intFromEnum(bmp.BitmapColorSpace.profile_embedded));
    for ([_][]const u8{ "BM", "BN" }) |magic| {
        var reader = zigimg.io.ReadStream.initMemory(magic);
        try std.testing.expectEqual(magic[1] == 'M', try bmp.BMP.formatDetect(&reader));
        try std.testing.expectEqual(@as(u64, 0), reader.getPos());
    }
    for ([_][]const u8{ "", "B" }) |magic| {
        var reader = zigimg.io.ReadStream.initMemory(magic);
        try std.testing.expectError(error.EndOfStream, bmp.BMP.formatDetect(&reader));
        try std.testing.expectEqual(@as(u64, 0), reader.getPos());
    }
    var output: [1000]u8 = undefined;
    const file = bmp.BitmapFileHeader{ .size = 1, .reserved = 0x12345678, .pixel_offset = 9000 };
    const info = bmp.BitmapInfoHeaderV4{ .header_size = 108, .width = 1, .height = 2, .color_plane = 17, .bit_count = 24, .image_raw_size = 99, .horizontal_resolution = 11, .vertical_resolution = 12, .palette_size = 13, .important_colors = 14, .red_mask = 0x10203040, .green_mask = 0x50607080, .blue_mask = 0x90abcdef, .alpha_mask = 0xdeadbeef, .color_space = .profile_linked, .cie_end_points = .{ .red = .{ .x = 1, .y = 2, .z = 3 }, .green = .{ .x = 4, .y = 5, .z = 6 }, .blue = .{ .x = 7, .y = 8, .z = 9 } }, .gamma_red = 0x11223344, .gamma_green = 0x55667788, .gamma_blue = 0x99aabbcc };
    var reader = zigimg.io.ReadStream.initMemory(try fixture(&output, file, .{ .v4 = info }, &.{ 1, 2, 3, 0, 4, 5, 6, 0 }));
    var codec = bmp.BMP{};
    const pixels = try codec.read(allocator, &reader);
    defer pixels.deinit(allocator);
    try std.testing.expectEqualDeep(file, codec.file_header);
    try std.testing.expectEqualDeep(info, codec.info_header.v4);
    try std.testing.expectEqualSlices(u8, &.{ 0, 4, 5, 1, 2, 3 }, pixels.asBytes());
    try std.testing.expectEqual(@as(u64, 128), reader.getPos());
    try std.testing.expectEqualSlices(u8, &.{ 6, 0 }, try reader.reader().take(2));

    const info5 = bmp.BitmapInfoHeaderV5{ .header_size = 124, .width = 2, .height = 2, .bit_count = 32, .compression_method = .bitfields, .color_plane = 0, .red_mask = 1, .green_mask = 2, .blue_mask = 3, .alpha_mask = 4, .color_space = .windows_color_space, .gamma_red = 5, .gamma_green = 6, .gamma_blue = 7, .intent = .absolute_colorimetric, .profile_data = 123, .profile_size = 456, .reserved = 789 };
    reader = zigimg.io.ReadStream.initMemory(try fixture(&output, .{}, .{ .v5 = info5 }, &.{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 }));
    const alpha = try codec.read(allocator, &reader);
    defer alpha.deinit(allocator);
    try std.testing.expectEqualDeep(info5, codec.info_header.v5);
    try std.testing.expectEqualSlices(u8, &.{ 8, 9, 10, 11, 12, 13, 14, 15, 0, 1, 2, 3, 4, 5, 6, 7 }, alpha.asBytes());
    try std.testing.expectEqual(@as(u64, 154), reader.getPos());
    for ([_]bmp.BitmapInfoHeader{
        .{ .v4 = .{ .header_size = 108, .width = 1, .height = 1, .bit_count = 32, .compression_method = .bitfields } },
        .{ .v5 = .{ .header_size = 124, .width = 1, .height = 1, .bit_count = 24 } },
    }) |header| {
        reader = zigimg.io.ReadStream.initMemory(try fixture(&output, .{}, header, &.{ 1, 2, 3, 4 }));
        var image = try bmp.BMP.readImage(allocator, &reader);
        defer image.deinit(allocator);
        try std.testing.expectEqual(@as(usize, 1), image.width);
        try std.testing.expectEqual(@as(usize, 1), image.height);
        try std.testing.expectEqualSlices(u8, if (header == .v4) &.{ 1, 2, 3, 4 } else &.{ 1, 2, 3 }, image.rawBytes());
    }
    for ([_][2]usize{ .{ 0, 0 }, .{ 0, 1 }, .{ 1, 0 } }) |dims| {
        var writer = zigimg.io.WriteStream.initMemory(&output);
        try bmp.BMP.writeImage(allocator, &writer, .{ .width = dims[0], .height = dims[1], .pixels = .{ .bgr24 = &.{} } }, .{ .bmp = .{} });
        try std.testing.expectEqual(@as(u64, 122), writer.getPos());
        reader = zigimg.io.ReadStream.initMemory(writer.memory.buffered());
        var image = try bmp.BMP.readImage(allocator, &reader);
        defer image.deinit(allocator);
        try std.testing.expectEqual(dims[0], image.width);
        try std.testing.expectEqual(dims[1], image.height);
        try std.testing.expectEqual(@as(usize, 0), image.rawBytes().len);
        try std.testing.expectEqual(@as(u64, 122), reader.getPos());
    }
    reader = zigimg.io.ReadStream.initMemory(try fixture(&output, .{}, .{ .v4 = .{ .header_size = 108, .width = -1, .height = -2, .bit_count = 24 } }, ""));
    const negative = try codec.read(allocator, &reader);
    defer negative.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 2), negative.len());
    try std.testing.expectEqual(@as(i32, -1), codec.width());
    try std.testing.expectEqual(@as(i32, -2), codec.height());
    try std.testing.expectEqual(@as(u64, 122), reader.getPos());
    try verifyWriters();
    try verifyErrors();
}

fn verifyWriters() !void {
    var output: [1000]u8 = undefined;
    var expected: [1000]u8 = undefined;
    var writer = zigimg.io.WriteStream.initMemory(&output);
    var bgr = [_]zigimg.color.Bgr24{ .{ .b = 1, .g = 2, .r = 3 }, .{ .b = 4, .g = 5, .r = 6 } };
    const image = zigimg.ImageUnmanaged{ .width = 1, .height = 2, .pixels = .{ .bgr24 = &bgr } };
    try bmp.BMP.writeImage(allocator, &writer, image, .{ .bmp = .{} });
    const info = bmp.BitmapInfoHeaderV4{ .header_size = 108, .width = 1, .height = 2, .color_plane = 1, .bit_count = 24, .image_raw_size = 6, .horizontal_resolution = 2835, .vertical_resolution = 2835 };
    try std.testing.expectEqualSlices(u8, try fixture(&expected, .{ .size = 128, .pixel_offset = 122 }, .{ .v4 = info }, &.{ 4, 5, 6, 1, 2, 3 }), writer.memory.buffered());
    try std.testing.expectEqualSlices(u8, &.{ 'B', 'M', 128, 0, 0, 0, 0, 0, 0, 0, 122, 0, 0, 0, 108, 0, 0, 0 }, writer.memory.buffered()[0..18]);
    try writer.seekTo(0);
    var bgra = [_]zigimg.color.Bgra32{ .{ .b = 1, .g = 2, .r = 3, .a = 4 }, .{ .b = 5, .g = 6, .r = 7, .a = 8 } };
    const alpha = zigimg.ImageUnmanaged{ .width = 1, .height = 2, .pixels = .{ .bgra32 = &bgra } };
    try bmp.BMP.writeImage(allocator, &writer, alpha, .{ .bmp = .{} });
    const info5 = bmp.BitmapInfoHeaderV5{ .header_size = 124, .width = 1, .height = 2, .color_plane = 1, .bit_count = 32, .compression_method = .bitfields, .image_raw_size = 8, .horizontal_resolution = 2835, .vertical_resolution = 2835, .red_mask = 0x0000ff00, .green_mask = 0x00ff0000, .blue_mask = 0xff000000, .alpha_mask = 0x000000ff };
    try std.testing.expectEqualSlices(u8, try fixture(&expected, .{ .size = 146, .pixel_offset = 138 }, .{ .v5 = info5 }, &.{ 5, 6, 7, 8, 1, 2, 3, 4 }), writer.memory.buffered());
    try std.testing.expectEqualSlices(u8, &.{ 0, 255, 0, 0, 0, 0, 255, 0, 0, 0, 0, 255, 255, 0, 0, 0, 0x42, 0x47, 0x52, 0x73 }, writer.memory.buffered()[54..74]);
    var reader = zigimg.io.ReadStream.initMemory(writer.memory.buffered());
    var decoded = try bmp.BMP.readImage(allocator, &reader);
    defer decoded.deinit(allocator);
    try std.testing.expectEqualSlices(u8, alpha.rawBytes(), decoded.rawBytes());
    try writer.seekTo(0);
    const codec = bmp.BMP{ .file_header = .{ .magic_header = .{ 'X', 'Y' }, .pixel_offset = 999 }, .info_header = .{ .v4 = .{ .header_size = 7, .width = 1, .height = 1, .bit_count = 1, .compression_method = .rle4 } } };
    try codec.write(&writer, .{ .bgra32 = bgra[0..1] });
    try std.testing.expectEqualSlices(u8, try fixture(&expected, codec.file_header, codec.info_header, &.{ 1, 2, 3, 4 }), writer.memory.buffered());
}

fn verifyErrors() !void {
    var output: [1000]u8 = undefined;
    const file = bmp.BitmapFileHeader{ .size = 123, .reserved = 456, .pixel_offset = 789 };
    const info = bmp.BitmapInfoHeaderV4{ .header_size = 108, .width = 1, .height = 2, .bit_count = 24 };
    const bytes = try fixture(&output, file, .{ .v4 = info }, &.{ 1, 2, 3, 4, 5, 6 });
    for ([_]usize{ 0, 1, 13, 14, 15, 17, 121, 122, 123, 125, 126, 127 }) |length| {
        var reader = zigimg.io.ReadStream.initMemory(bytes[0..length]);
        var codec = bmp.BMP{ .file_header = .{ .size = 99 }, .info_header = .{ .v5 = .{ .width = 777 } } };
        try std.testing.expectError(error.EndOfStream, codec.read(allocator, &reader));
        const pos: u64 = if (length < 14) 0 else if (length < 122) 14 else if (length < 125) 122 else 125;
        try std.testing.expectEqual(pos, reader.getPos());
        try std.testing.expectEqualDeep(if (length < 14) bmp.BitmapFileHeader{ .size = 99 } else file, codec.file_header);
        try std.testing.expectEqualDeep(if (length < 122) bmp.BitmapInfoHeader{ .v5 = .{ .width = 777 } } else bmp.BitmapInfoHeader{ .v4 = info }, codec.info_header);
    }
    var reader = zigimg.io.ReadStream.initMemory(try fixture(&output, .{ .magic_header = .{ 'B', 'X' } }, .{ .v4 = info }, ""));
    var codec = bmp.BMP{};
    try std.testing.expectError(error.InvalidData, codec.read(allocator, &reader));
    try std.testing.expectEqual(@as(u64, 14), reader.getPos());
    try std.testing.expectEqualSlices(u8, "BX", &codec.file_header.magic_header);
    for ([_]u32{ 0, 12, 64, 109 }) |size| {
        var header_writer = std.Io.Writer.fixed(&output);
        try header_writer.writeStruct(bmp.BitmapFileHeader{}, .little);
        try header_writer.writeInt(u32, size, .little);
        reader = zigimg.io.ReadStream.initMemory(header_writer.buffered());
        codec = .{ .info_header = .{ .v5 = .{ .width = 777 } } };
        try std.testing.expectError(error.Unsupported, codec.read(allocator, &reader));
        try std.testing.expectEqual(@as(u64, 14), reader.getPos());
        try std.testing.expectEqualDeep(bmp.BitmapInfoHeader{ .v5 = .{ .width = 777 } }, codec.info_header);
    }
    for ([_]bmp.BitmapInfoHeader{
        .{ .windows31 = .{ .header_size = 40, .width = 1, .height = 1, .bit_count = 24 } },
        .{ .v4 = .{ .header_size = 108, .bit_count = 32 } },
        .{ .v5 = .{ .header_size = 124, .bit_count = 24, .compression_method = .bitfields } },
        .{ .v5 = .{ .header_size = 124, .bit_count = 8 } },
    }) |header| {
        const fixture_bytes = try fixture(&output, .{}, header, "");
        reader = zigimg.io.ReadStream.initMemory(fixture_bytes);
        try std.testing.expectError(error.Unsupported, codec.read(allocator, &reader));
        try std.testing.expectEqual(@as(u64, fixture_bytes.len), reader.getPos());
        try std.testing.expectEqualDeep(header, codec.info_header);
    }
    for ([_]bmp.BitmapInfoHeader{ .{ .windows31 = .{ .header_size = 40 } }, .{ .v5 = .{ .header_size = 124, .width = 1, .height = 2, .bit_count = 32, .compression_method = .bitfields } } }) |header| {
        const fixture_bytes = try fixture(&output, .{}, header, "");
        reader = zigimg.io.ReadStream.initMemory(fixture_bytes[0 .. fixture_bytes.len - 1]);
        codec = .{ .info_header = .{ .v4 = .{ .width = 999 } } };
        try std.testing.expectError(error.EndOfStream, codec.read(allocator, &reader));
        try std.testing.expectEqual(@as(u64, 14), reader.getPos());
        try std.testing.expectEqualDeep(bmp.BitmapInfoHeader{ .v4 = .{ .width = 999 } }, codec.info_header);
    }
    const zeros = [_]u8{0} ** 8;
    for (0..8) |length| {
        reader = zigimg.io.ReadStream.initMemory(try fixture(&output, .{}, .{ .v5 = .{ .header_size = 124, .width = 1, .height = 2, .bit_count = 32, .compression_method = .bitfields } }, zeros[0..length]));
        try std.testing.expectError(error.EndOfStream, codec.read(allocator, &reader));
        try std.testing.expectEqual(@as(u64, if (length < 4) 138 else 142), reader.getPos());
    }
    for ([_]u16{ 1, 4, 8, 16, 24, 32, 48 }) |bits| {
        inline for (std.meta.fields(bmp.CompressionMethod)) |compression| {
            const method: bmp.CompressionMethod = @enumFromInt(compression.value);
            codec = .{ .info_header = .{ .v4 = .{ .bit_count = bits, .compression_method = method } } };
            if (bits == 24 and method == .none) {
                try std.testing.expectEqual(zigimg.PixelFormat.bgr24, try codec.pixelFormat());
            } else if (bits == 32 and method == .bitfields) {
                try std.testing.expectEqual(zigimg.PixelFormat.bgra32, try codec.pixelFormat());
            } else try std.testing.expectError(error.Unsupported, codec.pixelFormat());
        }
    }
    var writer = zigimg.io.WriteStream.initMemory(&output);
    try std.testing.expectError(error.InvalidData, bmp.BMP.writeImage(allocator, &writer, .{ .width = 1, .height = 1, .pixels = .{ .rgb24 = &.{} } }, .{ .bmp = .{} }));
    try std.testing.expectEqual(@as(u64, 0), writer.getPos());
    for ([_]bmp.BitmapInfoHeader{ .{ .windows31 = .{} }, .{ .v4 = .{} }, .{ .v5 = .{} } }, [_]u64{ 14, 122, 138 }) |header, pos| {
        try writer.seekTo(0);
        codec = .{ .file_header = .{}, .info_header = header };
        try std.testing.expectError(error.InvalidData, codec.write(&writer, .{ .grayscale8 = &.{} }));
        try std.testing.expectEqual(pos, writer.getPos());
    }
    var complete: [200]u8 = undefined;
    var complete_writer = zigimg.io.WriteStream.initMemory(&complete);
    var bgr = [_]zigimg.color.Bgr24{ .{ .b = 1, .g = 2, .r = 3 }, .{ .b = 4, .g = 5, .r = 6 } };
    const image = zigimg.ImageUnmanaged{ .width = 1, .height = 2, .pixels = .{ .bgr24 = &bgr } };
    try bmp.BMP.writeImage(allocator, &complete_writer, image, .{ .bmp = .{} });
    for ([_]usize{ 0, 1, 13, 14, 100, 121, 122, 123, 124, 125, 127 }) |length| {
        writer = zigimg.io.WriteStream.initMemory(output[0..length]);
        try std.testing.expectError(error.WriteFailed, bmp.BMP.writeImage(allocator, &writer, image, .{ .bmp = .{} }));
        try std.testing.expectEqual(@as(u64, length), writer.getPos());
        try std.testing.expectEqualSlices(u8, complete_writer.memory.buffered()[0..length], writer.memory.buffered());
    }
}
