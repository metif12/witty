const std = @import("std");
const builtin = @import("builtin");
const zigimg = @import("zigimg");
const sgi = zigimg.formats.sgi;
const allocator = std.heap.page_allocator;
const Header = @TypeOf((sgi.SGI{}).header);

fn header(width: u16, height: u16, channels: u16, bytes: u8, dimension: sgi.Dimensions, compression: sgi.CompressionFlag) Header {
    return .{ .compression = compression, .bytes_per_channel = bytes, .dimension = dimension, .x_size = width, .y_size = height, .z_size = channels, .pix_min = 123, .pix_max = 456, .dummy1 = 789, .image_name = .{'X'} ++ .{0} ** 79, .pixel_format = .normal, .dummy2 = .{0} ** 403 ++ .{77} };
}

fn fixture(output: []u8, h: Header, data: []const u8) ![]const u8 {
    var writer = std.Io.Writer.fixed(output);
    try writer.writeAll(&.{ 1, 0xda, @intFromEnum(h.compression), h.bytes_per_channel });
    for ([_]u16{ @intFromEnum(h.dimension), h.x_size, h.y_size, h.z_size }) |value| try writer.writeInt(u16, value, .big);
    for ([_]u32{ h.pix_min, h.pix_max, h.dummy1 }) |value| try writer.writeInt(u32, value, .big);
    try writer.writeAll(&h.image_name);
    try writer.writeInt(u32, @intFromEnum(h.pixel_format), .big);
    try writer.writeAll(&h.dummy2);
    try std.testing.expectEqual(@as(usize, 512), writer.end);
    try writer.writeAll(data);
    return writer.buffered();
}

fn rleFixture(output: []u8, h: Header, rows: []const []const u8) ![]const u8 {
    var data: [200]u8 = undefined;
    var writer = std.Io.Writer.fixed(&data);
    var offsets: [6]u32 = undefined;
    var index = rows.len;
    while (index > 0) {
        index -= 1;
        offsets[index] = @intCast(512 + rows.len * 8 + writer.end);
        try writer.writeAll(rows[index]);
    }
    var tables: [300]u8 = undefined;
    var table_writer = std.Io.Writer.fixed(&tables);
    for (offsets[0..rows.len]) |offset| try table_writer.writeInt(u32, offset, .big);
    for (rows) |row| try table_writer.writeInt(u32, @intCast(row.len), .big);
    try table_writer.writeAll(writer.buffered());
    try table_writer.writeAll(&.{ 99, 88 });
    return fixture(output, h, table_writer.buffered());
}

pub fn verify() !void {
    var output: [900]u8 = undefined;
    var h = header(2, 2, 3, 1, .multi_channel, .uncompressed);
    try std.testing.expectEqual(@as(usize, 510), @sizeOf(Header));
    try std.testing.expect(@TypeOf(h.z_size * h.bytes_per_channel) == u16);
    var reader = zigimg.io.ReadStream.initMemory(try fixture(&output, h, &.{ 10, 20, 30, 40, 1, 2, 3, 4, 100, 110, 120, 130 }));
    try std.testing.expect(try sgi.SGI.formatDetect(&reader));
    try std.testing.expectEqual(@as(u64, 0), reader.getPos());
    var codec = sgi.SGI{};
    const rgb = try codec.read(allocator, &reader);
    defer rgb.deinit(allocator);
    try std.testing.expectEqualDeep(h, codec.header);
    try std.testing.expectEqualSlices(u8, &.{ 30, 3, 120, 40, 4, 130, 10, 1, 100, 20, 2, 110 }, rgb.asBytes());
    h.z_size = 4;
    reader = zigimg.io.ReadStream.initMemory(try fixture(&output, h, &.{ 10, 20, 30, 40, 1, 2, 3, 4, 100, 110, 120, 130, 5, 6, 7, 8 }));
    var rgba = try sgi.SGI.readImage(allocator, &reader);
    defer rgba.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{ 30, 3, 120, 7, 40, 4, 130, 8, 10, 1, 100, 5, 20, 2, 110, 6 }, rgba.rawBytes());

    reader = zigimg.io.ReadStream.initMemory(try fixture(&output, header(1, 2, 3, 2, .multi_channel, .uncompressed), &.{ 0x11, 0x11, 0x22, 0x22, 0x33, 0x33, 0x44, 0x44, 0x55, 0x55, 0x66, 0x66 }));
    var rgb16 = try sgi.SGI.readImage(allocator, &reader);
    defer rgb16.deinit(allocator);
    try std.testing.expectEqualSlices(zigimg.color.Rgb48, &.{ .{ .r = 0x2222, .g = 0x4444, .b = 0x6666 }, .{ .r = 0x1111, .g = 0x3333, .b = 0x5555 } }, rgb16.pixels.rgb48);
    reader = zigimg.io.ReadStream.initMemory(try fixture(&output, header(1, 1, 4, 2, .multi_channel, .uncompressed), &.{ 0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0 }));
    var rgba16 = try sgi.SGI.readImage(allocator, &reader);
    defer rgba16.deinit(allocator);
    try std.testing.expectEqual(zigimg.color.Rgba64{ .r = 0x1234, .g = 0x5678, .b = 0x9abc, .a = if (builtin.cpu.arch.endian() == .little) 0x7800 else 0x78 }, rgba16.pixels.rgba64[0]);

    reader = zigimg.io.ReadStream.initMemory(try fixture(&output, header(2, 2, 1, 1, .single_channel, .uncompressed), &.{ 1, 2, 3, 4 }));
    var gray = try sgi.SGI.readImage(allocator, &reader);
    defer gray.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{ 3, 4, 1, 2 }, gray.rawBytes());
    reader = zigimg.io.ReadStream.initMemory(try fixture(&output, header(2, 1, 1, 2, .single_channel, .uncompressed), &.{ 0x12, 0x34, 0x56, 0x78 }));
    var gray16 = try sgi.SGI.readImage(allocator, &reader);
    defer gray16.deinit(allocator);
    try std.testing.expectEqual(zigimg.PixelFormat.grayscale8, gray16.pixelFormat());
    try std.testing.expectEqualSlices(u8, &.{ 0x12, 0x34 }, gray16.rawBytes());
    try std.testing.expectEqual(@as(u64, 516), reader.getPos());

    const encoded = try rleFixture(&output, header(3, 2, 3, 1, .multi_channel, .rle), &.{ &.{ 0x80, 0x81, 1, 2, 3, 0 }, &.{ 0x83, 4, 5, 6, 0 }, &.{ 3, 7, 0 }, &.{ 0x83, 8, 9, 10, 0 }, &.{ 3, 11, 0 }, &.{ 3, 12, 0 } });
    reader = zigimg.io.ReadStream.initMemory(encoded);
    var rle = try sgi.SGI.readImage(allocator, &reader);
    defer rle.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{ 4, 8, 12, 5, 9, 12, 6, 10, 12, 1, 7, 11, 3, 7, 11, 3, 7, 11 }, rle.rawBytes());
    try std.testing.expectEqual(@as(u64, encoded.len), reader.getPos());
    reader = zigimg.io.ReadStream.initMemory(try rleFixture(&output, header(3, 1, 3, 2, .multi_channel, .rle), &.{ &.{ 0xff, 0x83, 0x11, 0x11, 0x22, 0x22, 0x33, 0x33, 0, 0 }, &.{ 0x7f, 3, 0x44, 0x44, 0, 0 }, &.{ 0, 0x83, 0x55, 0x55, 0x66, 0x66, 0x77, 0x77, 0, 0 } }));
    var rle16 = try sgi.SGI.readImage(allocator, &reader);
    defer rle16.deinit(allocator);
    try std.testing.expectEqualSlices(zigimg.color.Rgb48, &.{ .{ .r = 0x1111, .g = 0x4444, .b = 0x5555 }, .{ .r = 0x2222, .g = 0x4444, .b = 0x6666 }, .{ .r = 0x3333, .g = 0x4444, .b = 0x7777 } }, rle16.pixels.rgb48);
    reader = zigimg.io.ReadStream.initMemory(try rleFixture(&output, header(2, 2, 1, 1, .single_channel, .rle), &.{ &.{ 3, 9, 0 }, &.{ 2, 1, 0 } }));
    var overrun = try sgi.SGI.readImage(allocator, &reader);
    defer overrun.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{ 1, 1, 9, 9 }, overrun.rawBytes());

    const bytes = try fixture(&output, header(1, 1, 3, 1, .multi_channel, .uncompressed), &.{ 1, 2, 3 });
    for ([_]usize{ 1, 20, 513 }, [_]u64{ 0, 2, 513 }) |length, pos| {
        reader = zigimg.io.ReadStream.initMemory(bytes[0..length]);
        try std.testing.expectError(if (length == 20) error.InvalidData else error.EndOfStream, sgi.SGI.readImage(allocator, &reader));
        try std.testing.expectEqual(pos, reader.getPos());
    }
    for ([_]Header{ header(0, 0, 0, 0, .scanline, .uncompressed), header(0, 0, 2, 0, .multi_channel, .uncompressed) }) |unsupported| {
        reader = zigimg.io.ReadStream.initMemory(try fixture(&output, unsupported, ""));
        try std.testing.expectError(error.Unsupported, sgi.SGI.readImage(allocator, &reader));
        try std.testing.expectEqual(@as(u64, 512), reader.getPos());
    }
    h = header(0, 0, 0, 0, .single_channel, .uncompressed);
    h.pixel_format = .dithered;
    reader = zigimg.io.ReadStream.initMemory(try fixture(&output, h, ""));
    try std.testing.expectError(error.Unsupported, sgi.SGI.readImage(allocator, &reader));
    var writer = zigimg.io.WriteStream.initMemory(output[0..0]);
    try sgi.SGI.writeImage(allocator, &writer, .{}, .{ .sgi = {} });
    try std.testing.expectEqual(@as(u64, 0), writer.getPos());
}
