const std = @import("std");
const zigimg = @import("zigimg");
const ras = zigimg.formats.ras;
const allocator = std.heap.page_allocator;

fn fixture(output: []u8, width: u32, height: u32, depth: u32, kind: ras.Type, map: ras.ColorMapType, palette: []const u8, data: []const u8) ![]const u8 {
    var writer = std.Io.Writer.fixed(output);
    try writer.writeAll(&.{ 0x59, 0xa6, 0x6a, 0x95 });
    for ([_]u32{ width, height, depth, 0, @intFromEnum(kind), @intFromEnum(map), @intCast(palette.len) }) |value| {
        try writer.writeInt(u32, value, .big);
    }
    try writer.writeAll(palette);
    try writer.writeAll(data);
    return writer.buffered();
}

pub fn verify() !void {
    var output: [200]u8 = undefined;
    for ([_]ras.Type{ .old, .standard, .rgb }) |kind| {
        var reader = zigimg.io.ReadStream.initMemory(try fixture(&output, 1, 1, 24, kind, .no_color_map, "", &.{ 10, 20, 30 }));
        try std.testing.expect(try ras.RAS.formatDetect(&reader));
        try std.testing.expectEqual(@as(u64, 0), reader.getPos());
        var image = try ras.RAS.readImage(allocator, &reader);
        defer image.deinit(allocator);
        try std.testing.expectEqualSlices(u8, &.{ 10, 20, 30 }, image.rawBytes());
        try std.testing.expectEqual(if (kind == .rgb) zigimg.PixelFormat.rgb24 else zigimg.PixelFormat.bgr24, image.pixelFormat());
        var iter = image.iterator();
        const pixel = iter.next().?;
        try std.testing.expectEqual(if (kind == .rgb) @as(f32, 10) / 255 else @as(f32, 30) / 255, pixel.r);
        try std.testing.expectEqual(if (kind == .rgb) @as(f32, 30) / 255 else @as(f32, 10) / 255, pixel.b);
        try std.testing.expectEqual(@as(u64, 35), reader.getPos());
    }
    for ([_]ras.Type{ .standard, .rgb }) |kind| {
        var reader = zigimg.io.ReadStream.initMemory(try fixture(&output, 1, 1, 32, kind, .no_color_map, "", &.{ 77, 10, 20, 30 }));
        var image = try ras.RAS.readImage(allocator, &reader);
        defer image.deinit(allocator);
        try std.testing.expectEqualSlices(u8, if (kind == .rgb) &.{ 10, 20, 30, 255 } else &.{ 30, 20, 10, 255 }, image.rawBytes());
    }

    var reader = zigimg.io.ReadStream.initMemory(try fixture(&output, 10, 2, 1, .standard, .no_color_map, "", &.{ 0xaa, 0x80, 0x55, 0x40 }));
    var mono = try ras.RAS.readImage(allocator, &reader);
    defer mono.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{ 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0 }, mono.rawBytes());
    reader = zigimg.io.ReadStream.initMemory(try fixture(&output, 1, 2, 1, .old, .no_color_map, "", &.{ 0x80, 0xff, 0, 0xff }));
    var padded = try ras.RAS.readImage(allocator, &reader);
    defer padded.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{ 0, 1 }, padded.rawBytes());
    reader = zigimg.io.ReadStream.initMemory(try fixture(&output, 3, 2, 8, .old, .no_color_map, "", &.{ 1, 2, 3, 4, 5, 6 }));
    var gray = try ras.RAS.readImage(allocator, &reader);
    defer gray.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 4, 5, 6 }, gray.rawBytes());

    reader = zigimg.io.ReadStream.initMemory(try fixture(&output, 3, 1, 8, .standard, .rgb_color_map, &.{ 10, 11, 20, 21, 30, 31, 99 }, &.{ 0, 1, 0 }));
    var codec = ras.RAS{};
    const indexed = try codec.read(allocator, &reader);
    defer indexed.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{ 0, 1, 0 }, indexed.asBytes());
    try std.testing.expectEqualSlices(zigimg.color.Rgba32, &.{ .{ .r = 10, .g = 20, .b = 30 }, .{ .r = 11, .g = 21, .b = 31 } }, indexed.indexed8.palette);
    try std.testing.expect(@intFromPtr(codec.palette.data.ptr) == @intFromPtr(&codec.palette.storage[0]));
    try std.testing.expect(codec.palette.data.ptr != indexed.indexed8.palette.ptr);
    codec.palette.data[0].r = 55;
    try std.testing.expectEqual(@as(u8, 55), codec.palette.storage[0].r);
    try std.testing.expectEqual(@as(u8, 10), indexed.indexed8.palette[0].r);
    reader = zigimg.io.ReadStream.initMemory(try fixture(&output, 1, 1, 1, .old, .rgb_color_map, &.{ 0, 255, 0, 255, 0, 255 }, &.{ 0x80, 0 }));
    var indexed_mono = try ras.RAS.readImage(allocator, &reader);
    defer indexed_mono.deinit(allocator);
    try std.testing.expectEqual(zigimg.PixelFormat.indexed8, indexed_mono.pixelFormat());
    try std.testing.expectEqualSlices(u8, &.{0x80}, indexed_mono.rawBytes());

    reader = zigimg.io.ReadStream.initMemory(try fixture(&output, 7, 1, 8, .byte_encoded, .no_color_map, "", &.{ 1, 0x80, 0, 0x80, 2, 7, 0x80, 255, 9, 55 }));
    var rle = try ras.RAS.readImage(allocator, &reader);
    defer rle.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{ 1, 0x80, 7, 7, 7, 9, 9 }, rle.rawBytes());
    try std.testing.expectEqual(@as(u8, 55), try reader.reader().takeByte());
    try std.testing.expectEqual(@as(u64, 42), reader.getPos());

    for ([_]usize{ 3, 8, 34 }, [_]anyerror{ error.EndOfStream, error.InvalidData, error.EndOfStream }, [_]u64{ 0, 4, 34 }) |len, expected, position| {
        reader = zigimg.io.ReadStream.initMemory((try fixture(&output, 3, 1, 8, .old, .no_color_map, "", &.{ 1, 2, 3 }))[0..len]);
        try std.testing.expectError(expected, ras.RAS.readImage(allocator, &reader));
        try std.testing.expectEqual(position, reader.getPos());
    }
    reader = zigimg.io.ReadStream.initMemory(try fixture(&output, 0, 0, 16, .old, .no_color_map, "", ""));
    try std.testing.expectError(error.Unsupported, ras.RAS.readImage(allocator, &reader));
    reader = zigimg.io.ReadStream.initMemory(try fixture(&output, 0, 0, 8, .tiff, .no_color_map, "", ""));
    try std.testing.expectError(error.Unsupported, ras.RAS.readImage(allocator, &reader));
    reader = zigimg.io.ReadStream.initMemory(try fixture(&output, 0, 0, 8, .old, .raw_color_map, &.{0}, ""));
    try std.testing.expectError(error.Unsupported, ras.RAS.readImage(allocator, &reader));
    reader = zigimg.io.ReadStream.initMemory("other data");
    try std.testing.expectError(error.InvalidData, ras.RAS.readImage(allocator, &reader));
    try std.testing.expectEqual(@as(u64, 0), reader.getPos());
    var writer = zigimg.io.WriteStream.initMemory(output[0..1]);
    try ras.RAS.writeImage(allocator, &writer, .{}, .{ .ras = {} });
    try std.testing.expectEqual(@as(u64, 0), writer.getPos());
}
