const std = @import("std");
const zigimg = @import("zigimg");
const pcx = zigimg.formats.pcx;
const allocator = std.heap.page_allocator;

fn fixture(output: []u8, header: pcx.PCXHeader, data: []const u8) ![]const u8 {
    var writer = std.Io.Writer.fixed(output);
    try writer.writeStruct(header, .little);
    try writer.writeAll(data);
    return writer.buffered();
}

pub fn verify() !void {
    try std.testing.expectEqual(@as(usize, 128), @sizeOf(pcx.PCXHeader));
    try std.testing.expectEqual(@as(usize, 1), (pcx.PCX{}).width());
    const max = pcx.PCX{ .header = .{ .xmin = 1, .xmax = 65535, .ymin = 1, .ymax = 65535 } };
    try std.testing.expectEqual(@as(usize, 65535), max.width());
    try std.testing.expectEqual(@as(usize, 65535), max.height());
    try std.testing.expect(@TypeOf(max.header.stride * max.header.planes) == u16);
    var output: [2000]u8 = undefined;
    for (0..7) |version| {
        var magic = [_]u8{ 0x0a, @intCast(version) };
        var reader = zigimg.io.ReadStream.initMemory(&magic);
        try std.testing.expectEqual(version <= 5, try pcx.PCX.formatDetect(&reader));
        try std.testing.expectEqual(@as(u64, 0), reader.getPos());
    }
    var reader = zigimg.io.ReadStream.initMemory(&.{ 0x0b, 5 });
    try std.testing.expect(!try pcx.PCX.formatDetect(&reader));
    var h = pcx.PCXHeader{ .bpp = 1, .xmin = 10, .ymin = 20, .xmax = 19, .ymax = 21, .horizontal_dpi = 123, .vertical_dpi = 456, ._reserved0 = 77, .planes = 1, .stride = 2, .palette_information = @enumFromInt(99), .screen_width = 789, .screen_height = 345 };
    h.builtin_palette[0] = .{ .r = 1, .g = 2, .b = 3 };
    h.builtin_palette[1] = .{ .r = 4, .g = 5, .b = 6 };
    h.padding[53] = 99;
    reader = zigimg.io.ReadStream.initMemory(try fixture(&output, h, &.{ 0xaa, 0, 0x55, 0x11, 7 }));
    var codec = pcx.PCX{};
    const pixels = try codec.read(allocator, &reader);
    defer pixels.deinit(allocator);
    try std.testing.expectEqualDeep(h, codec.header);
    try std.testing.expectEqual(@as(usize, 10), codec.width());
    try std.testing.expectEqual(@as(usize, 2), codec.height());
    try std.testing.expectEqualSlices(u8, &.{ 1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0 }, pixels.asBytes());
    try std.testing.expectEqualSlices(zigimg.color.Rgba32, &.{ .{ .r = 1, .g = 2, .b = 3 }, .{ .r = 4, .g = 5, .b = 6 } }, pixels.indexed1.palette);
    try std.testing.expectEqual(@as(u64, 132), reader.getPos());
    for ([_]pcx.Compression{ .none, .rle }) |compression| {
        reader = zigimg.io.ReadStream.initMemory(try fixture(&output, .{ .compression = compression, .bpp = 1, .xmax = 7, .ymax = 1, .planes = 1, .stride = 1 }, &.{ 0xc0, 0xc0, 0xc2, 0xaa }));
        var image = try pcx.PCX.readImage(allocator, &reader);
        defer image.deinit(allocator);
        try std.testing.expectEqualSlices(u8, &.{ 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0 }, image.rawBytes());
        try std.testing.expectEqual(@as(u64, 132), reader.getPos());
    }
    reader = zigimg.io.ReadStream.initMemory(try fixture(&output, .{ .bpp = 4, .xmax = 2, .ymax = 1, .planes = 1, .stride = 2 }, &.{ 0x12, 0x30, 0x45, 0x60 }));
    var nibble = try pcx.PCX.readImage(allocator, &reader);
    defer nibble.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 4, 5, 6 }, nibble.rawBytes());

    var data: [800]u8 = undefined;
    var data_writer = std.Io.Writer.fixed(&data);
    try data_writer.writeAll(&.{ 1, 2, 3, 9, 4, 5, 6, 9, 77, 88, 0x0c });
    for (0..256) |i| try data_writer.writeAll(&.{ @intCast(i), @intCast(255 - i), @intCast(i ^ 55) });
    reader = zigimg.io.ReadStream.initMemory(try fixture(&output, .{ .bpp = 8, .xmin = 2, .xmax = 4, .ymax = 1, .planes = 1, .stride = 4 }, data_writer.buffered()));
    var vga = try pcx.PCX.readImage(allocator, &reader);
    defer vga.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 4, 5, 6 }, vga.rawBytes());
    try std.testing.expectEqual(@as(usize, 256), vga.pixels.indexed8.palette.len);
    try std.testing.expectEqual(zigimg.color.Rgba32{ .r = 0, .g = 255, .b = 55 }, vga.pixels.indexed8.palette[0]);
    try std.testing.expectEqual(zigimg.color.Rgba32{ .r = 255, .g = 0, .b = 200 }, vga.pixels.indexed8.palette[255]);
    try std.testing.expectEqual(try reader.getEndPos(), reader.getPos());
    reader = zigimg.io.ReadStream.initMemory(try fixture(&output, .{ .bpp = 8, .xmax = 2, .planes = 3, .stride = 4 }, &.{ 1, 2, 3, 0, 4, 5, 6, 0, 7, 8, 9, 0 }));
    var rgb = try pcx.PCX.readImage(allocator, &reader);
    defer rgb.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{ 1, 4, 7, 2, 5, 8, 3, 6, 9 }, rgb.rawBytes());
    try std.testing.expectEqual(@as(u64, 140), reader.getPos());
    reader = zigimg.io.ReadStream.initMemory(try fixture(&output, .{ .bpp = 8, .xmax = 3, .planes = 3, .stride = 6 }, &.{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }));
    var extra = try pcx.PCX.readImage(allocator, &reader);
    defer extra.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{ 1, 5, 9, 2, 6, 10, 3, 7, 11, 4, 8, 12 }, extra.rawBytes());
    try std.testing.expectEqual(@as(u64, 144), reader.getPos());
    try verifyWriters();
    try verifyErrors();
}

const WriteCase = struct { width: usize, height: usize = 1, pixels: zigimg.color.PixelStorage, bpp: u8, planes: u8 = 1, stride: u16, data: []const u8 };

fn verifyWriters() !void {
    const cases = [_]WriteCase{
        .{ .width = 8, .pixels = .{ .indexed1 = .{ .indices = @constCast(&([_]u1{1} ** 8)), .palette = &.{} } }, .bpp = 1, .stride = 2, .data = &.{ 0xc1, 0xff } },
        .{ .width = 9, .pixels = .{ .indexed1 = .{ .indices = @constCast(&([_]u1{1} ** 9)), .palette = &.{} } }, .bpp = 1, .stride = 2, .data = &.{ 0xc1, 0xff, 0x80 } },
        .{ .width = 10, .pixels = .{ .indexed1 = .{ .indices = @constCast(&([_]u1{1} ** 10)), .palette = &.{} } }, .bpp = 1, .stride = 2, .data = &.{ 0xc1, 0xff } },
        .{ .width = 17, .pixels = .{ .indexed1 = .{ .indices = @constCast(&([_]u1{1} ** 17)), .palette = &.{} } }, .bpp = 1, .stride = 2, .data = &.{ 0xc2, 0xff, 0x80 } },
        .{ .width = 4, .pixels = .{ .indexed4 = .{ .indices = @constCast(&[_]u4{ 1, 2, 3, 4 }), .palette = &.{} } }, .bpp = 4, .stride = 2, .data = &.{ 0x12, 0x34 } },
        .{ .width = 3, .pixels = .{ .indexed4 = .{ .indices = @constCast(&[_]u4{ 15, 1, 2 }), .palette = &.{} } }, .bpp = 4, .stride = 2, .data = &.{ 0xc1, 0xf1, 0x20 } },
        .{ .width = 2, .pixels = .{ .rgb24 = @constCast(&[_]zigimg.color.Rgb24{ .{ .r = 1, .g = 1, .b = 1 }, .{ .r = 1, .g = 1, .b = 1 } }) }, .bpp = 8, .planes = 3, .stride = 2, .data = &.{ 0xc6, 1 } },
        .{ .width = 3, .pixels = .{ .rgb24 = @constCast(&[_]zigimg.color.Rgb24{ .{ .r = 1, .g = 3, .b = 6 }, .{ .r = 1, .g = 4, .b = 7 }, .{ .r = 2, .g = 5, .b = 8 } }) }, .bpp = 8, .planes = 3, .stride = 4, .data = &.{ 0xc2, 1, 2, 0, 3, 4, 5, 0, 6, 7, 8, 0 } },
    };
    var output: [2000]u8 = undefined;
    var expected: [2000]u8 = undefined;
    for (cases) |item| {
        var writer = zigimg.io.WriteStream.initMemory(&output);
        try pcx.PCX.writeImage(allocator, &writer, .{ .width = item.width, .height = item.height, .pixels = item.pixels }, .{ .pcx = .{} });
        try std.testing.expectEqualSlices(u8, try fixture(&expected, .{ .xmax = @intCast(item.width - 1), .ymax = @intCast(item.height - 1), .bpp = item.bpp, .planes = item.planes, .stride = item.stride }, item.data), writer.memory.buffered());
    }
    var writer = zigimg.io.WriteStream.initMemory(&output);
    const one = zigimg.ImageUnmanaged{ .width = 1, .height = 1, .pixels = .{ .indexed1 = .{ .indices = @constCast(&[_]u1{1}), .palette = @constCast(&[_]zigimg.color.Rgba32{.{ .r = 1, .g = 2, .b = 3, .a = 4 }}) } } };
    try pcx.PCX.writeImage(allocator, &writer, one, .{ .pcx = .{} });
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 0, 0, 0 }, writer.memory.buffered()[16..22]);
    try std.testing.expectEqualSlices(u8, &.{ 0, 0 }, writer.memory.buffered()[66..68]);
    try std.testing.expectEqualSlices(u8, &.{0x80}, writer.memory.buffered()[128..]);
    try writer.seekTo(0);
    const indexed = zigimg.ImageUnmanaged{ .width = 2, .height = 1, .pixels = .{ .indexed8 = .{ .indices = @constCast(&[_]u8{ 0xc0, 0xc0 }), .palette = @constCast(&[_]zigimg.color.Rgba32{ .{ .r = 1, .g = 2, .b = 3, .a = 4 }, .{ .r = 5, .g = 6, .b = 7, .a = 8 } }) } } };
    try pcx.PCX.writeImage(allocator, &writer, indexed, .{ .pcx = .{} });
    try std.testing.expectEqualSlices(u8, &.{ 0xc2, 0xc0, 0x0c, 1, 2, 3, 5, 6, 7 }, writer.memory.buffered()[128..]);
    const fast_cases = .{
        .{ &([_]u8{0x45} ** 65 ++ .{ 1, 1, 1, 1 }), &[_]u8{ 0xff, 0x45, 0x45, 0x45, 0xc4, 1 } },
        .{ &([_]u8{1} ** 16 ++ [_]u8{2} ** 16), &[_]u8{ 0xe0, 2 } },
        .{ &([_]u8{1} ** 16 ++ [_]u8{2} ** 8 ++ [_]u8{3} ** 8), &[_]u8{ 0xd8, 2, 0xc8, 3 } },
        .{ &[_]u8{ 1, 2, 3, 4 }, &[_]u8{ 1, 2, 3, 4 } },
    };
    inline for (fast_cases) |item| {
        try writer.seekTo(0);
        const image = zigimg.ImageUnmanaged{ .width = 2, .height = 1, .pixels = .{ .indexed8 = .{ .indices = @constCast(item[0]), .palette = &.{} } } };
        try pcx.PCX.writeImage(allocator, &writer, image, .{ .pcx = .{} });
        try std.testing.expectEqualSlices(u8, item[1] ++ .{0x0c}, writer.memory.buffered()[128..]);
    }
    try writer.seekTo(0);
    try pcx.PCX.writeImage(allocator, &writer, .{ .width = 3, .height = 2, .pixels = .{ .indexed8 = .{ .indices = @constCast(&([_]u8{5} ** 6)), .palette = &.{} } } }, .{ .pcx = .{} });
    try std.testing.expectEqualSlices(u8, &.{ 0xc3, 5, 0, 0xc3, 5, 0, 0x0c }, writer.memory.buffered()[128..]);
    try writer.seekTo(0);
    const codec = pcx.PCX{ .header = .{ .id = 7, .version = 6, .compression = .none, .bpp = 99, .xmax = 1, .ymin = 1, .ymax = 0, .planes = 2, .stride = 42 } };
    try codec.write(&writer, indexed.pixels);
    try std.testing.expectEqualSlices(u8, try fixture(&expected, codec.header, &.{ 0xc2, 0xc0, 0x0c, 1, 2, 3, 5, 6, 7 }), writer.memory.buffered());
}

fn verifyErrors() !void {
    var output: [2000]u8 = undefined;
    const h = pcx.PCXHeader{ .bpp = 1, .xmax = 7, .planes = 1, .stride = 1 };
    const bytes = try fixture(&output, h, &.{1});
    for ([_]usize{ 1, 127 }) |length| {
        var reader = zigimg.io.ReadStream.initMemory(bytes[0..length]);
        var codec = pcx.PCX{ .header = .{ .version = 2 } };
        try std.testing.expectError(error.EndOfStream, codec.read(allocator, &reader));
        try std.testing.expectEqual(@as(u64, 0), reader.getPos());
        try std.testing.expectEqual(@as(u8, 2), codec.header.version);
    }
    for ([_]pcx.PCXHeader{ .{ .id = 0 }, .{ .version = 6 }, .{ .planes = 4 }, .{ .planes = 2 }, .{ .planes = 1, .bpp = 2 }, .{ .planes = 3, .bpp = 4 } }) |bad| {
        var reader = zigimg.io.ReadStream.initMemory(try fixture(&output, bad, ""));
        var codec = pcx.PCX{};
        try std.testing.expectError(if (bad.id != 0x0a or bad.version > 5) error.InvalidData else error.Unsupported, codec.read(allocator, &reader));
        try std.testing.expectEqual(@as(u64, 128), reader.getPos());
        try std.testing.expectEqualDeep(bad, codec.header);
    }
    for ([_][]const u8{ &.{0xc1}, &.{ 0xc2, 1 } }) |data| {
        var reader = zigimg.io.ReadStream.initMemory(try fixture(&output, h, data));
        try std.testing.expectError(if (data.len == 1) error.EndOfStream else error.InvalidData, pcx.PCX.readImage(allocator, &reader));
        try std.testing.expectEqual(@as(u64, 128 + data.len), reader.getPos());
    }
    for ([_]usize{ 769, 639 }, [_]u64{ 131, 1 }) |padding, pos| {
        const first_len = (try fixture(&output, .{ .bpp = 8, .planes = 1, .stride = 2 }, &.{ 1, 0 })).len;
        @memset(output[first_len..][0..padding], 0);
        var reader = zigimg.io.ReadStream.initMemory(output[0 .. first_len + padding]);
        try std.testing.expectError(error.InvalidData, pcx.PCX.readImage(allocator, &reader));
        try std.testing.expectEqual(pos, reader.getPos());
    }
    for ([_]zigimg.ImageUnmanaged{ .{ .width = 65536, .height = 1 }, .{ .width = 1, .height = 65536 }, .{ .width = 1, .height = 1, .pixels = .{ .grayscale8 = &.{} } } }) |image| {
        var writer = zigimg.io.WriteStream.initMemory(&output);
        try std.testing.expectError(error.Unsupported, pcx.PCX.writeImage(allocator, &writer, image, .{ .pcx = .{} }));
        try std.testing.expectEqual(@as(u64, 0), writer.getPos());
    }
    const image = zigimg.ImageUnmanaged{ .width = 8, .height = 1, .pixels = .{ .indexed1 = .{ .indices = @constCast(&([_]u1{1} ** 8)), .palette = &.{} } } };
    for ([_]usize{ 0, 1, 127, 129 }) |length| {
        var writer = zigimg.io.WriteStream.initMemory(output[0..length]);
        try std.testing.expectError(error.WriteFailed, pcx.PCX.writeImage(allocator, &writer, image, .{ .pcx = .{} }));
        try std.testing.expectEqual(@as(u64, length), writer.getPos());
    }
}
