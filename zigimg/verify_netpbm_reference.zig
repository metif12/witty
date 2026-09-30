const std = @import("std");
const zigimg = @import("zigimg");
const netpbm = zigimg.formats.netpbm;
const allocator = std.heap.page_allocator;

pub fn verify() !void {
    try verifyBitOrder(.big, &.{ 0xcd, 0x0b });
    try verifyBitOrder(.little, &.{ 0x1d, 0x95 });
    try verifyBitBoundaries();
    try verifyBitmaps();
    try verifyGraymaps();
    try verifyRgbmaps();
    try verifyParsing();
}

fn verifyBitOrder(comptime endian: std.builtin.Endian, expected: []const u8) !void {
    var bytes: [2]u8 = undefined;
    var writer = std.Io.Writer.fixed(&bytes);
    var bits = zigimg.io.BitWriter(endian){ .writer = &writer };
    for ([_]u16{ 1, 2, 3, 4, 5, 1 }, 0..) |num, i| {
        try bits.writeBits(@as(u16, @intCast(if (i == 5) 1 else i + 1)), num);
    }
    try std.testing.expectEqualSlices(u8, expected, &bytes);
    var reader = std.Io.Reader.fixed(&bytes);
    var read_bits = zigimg.io.BitReader(endian){ .reader = &reader };
    for ([_]u16{ 1, 2, 3, 4, 5, 1 }, 0..) |num, i| {
        const value, const count = try read_bits.readBitsTuple(u16, num);
        try std.testing.expectEqual(@as(u16, @intCast(if (i == 5) 1 else i + 1)), value);
        try std.testing.expectEqual(num, count);
    }
    try std.testing.expectError(error.EndOfStream, read_bits.readBitsNoEof(u8, 1));
}

fn verifyBitBoundaries() !void {
    var reader = std.Io.Reader.fixed(&.{0xab});
    var bits = zigimg.io.BitReader(.big){ .reader = &reader };
    try std.testing.expectEqual(@as(u8, 5), try bits.readBitsNoEof(u8, 3));
    const partial, const count = try bits.readBitsTuple(u16, 10);
    try std.testing.expectEqual(@as(u16, 0x0b), partial);
    try std.testing.expectEqual(@as(u16, 5), count);
    reader.seek = 0;
    try std.testing.expectEqual(@as(i8, -85), try bits.readBitsNoEof(i8, 8));
    var le_reader = std.Io.Reader.fixed(&.{ 0xab, 0xcd });
    var le = zigimg.io.BitReader(.little){ .reader = &le_reader };
    try std.testing.expectEqual(@as(u8, 3), try le.readBitsNoEof(u8, 3));
    const le_partial, const le_count = try le.readBitsTuple(u32, 20);
    try std.testing.expectEqual(@as(u32, 0x19b5), le_partial);
    try std.testing.expectEqual(@as(u16, 13), le_count);

    var bytes: [9]u8 = undefined;
    var writer = std.Io.Writer.fixed(&bytes);
    var out = zigimg.io.BitWriter(.big){ .writer = &writer };
    try out.writeBits(@as(u8, 1), 1);
    try out.writeBits(@as(u64, 0xfedcba9876543210), 64);
    try out.flushBits();
    try std.testing.expectEqualSlices(u8, &.{ 0xff, 0x6e, 0x5d, 0x4c, 0x3b, 0x2a, 0x19, 0x08, 0x00 }, &bytes);
    writer.end = 0;
    var le_out = zigimg.io.BitWriter(.little){ .writer = &writer };
    try le_out.writeBits(@as(u8, 0xff), 1);
    try le_out.writeBits(@as(u8, 0), 7);
    try std.testing.expectEqual(@as(u8, 0xff), bytes[0]);
    var empty: [0]u8 = undefined;
    var fixed = std.Io.Writer.fixed(&empty);
    var failing = zigimg.io.BitWriter(.big){ .writer = &fixed };
    try failing.writeBits(@as(u8, 5), 3);
    try std.testing.expectError(error.WriteFailed, failing.flushBits());
    try std.testing.expectEqual(@as(u8, 0xa0), failing.bits);
    try std.testing.expectEqual(@as(u4, 3), failing.count);

    writer.end = 0;
    try out.writeBits(@as(f32, -2.5), 32);
    try std.testing.expectEqualSlices(u8, &.{ 0xc0, 0x20, 0, 0 }, writer.buffered());
    reader = std.Io.Reader.fixed(writer.buffered());
    try std.testing.expectEqual(@as(f32, -2.5), try bits.readBitsNoEof(f32, 32));
    writer.end = 0;
    try le_out.writeBits(@as(f64, 1.0), 64);
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0, 0, 0, 0xf0, 0x3f }, writer.buffered());
    le_reader = std.Io.Reader.fixed(writer.buffered());
    try std.testing.expectEqual(@as(f64, 1.0), try le.readBitsNoEof(f64, 64));
}

fn expectEncoded(comptime Codec: type, image: zigimg.ImageUnmanaged, options: zigimg.ImageUnmanaged.EncoderOptions, expected: []const u8) !void {
    var output: [150]u8 = undefined;
    var writer = zigimg.io.WriteStream.initMemory(&output);
    try Codec.writeImage(allocator, &writer, image, options);
    try std.testing.expectEqualSlices(u8, expected, writer.memory.buffered());
}

fn verifyBitmaps() !void {
    var reader = zigimg.io.ReadStream.initMemory("P4\n10 2\n\xaa\x80\x55\x40");
    var image = try netpbm.PBM.readImage(allocator, &reader);
    defer image.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 10), image.width);
    try std.testing.expectEqual(@as(usize, 2), image.height);
    try std.testing.expectEqual(@as(u64, 12), reader.getPos());
    try std.testing.expectEqualSlices(u8, &.{ 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0 }, image.rawBytes());
    try expectEncoded(netpbm.PBM, image, .{ .pbm = .{} }, "P4\n# Created by zigimg\n10 2\n\xaa\x80\x55\x40");
    try expectEncoded(netpbm.PBM, image, .{ .pbm = .{ .binary = false } }, "P1\n# Created by zigimg\n10 2\n10101010100101010101\n");
    reader = zigimg.io.ReadStream.initMemory("P1\n5 1\n0#x1\n0");
    var ascii = try netpbm.PBM.readImage(allocator, &reader);
    defer ascii.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{ 1, 0, 0, 0, 1 }, ascii.rawBytes());
}

fn verifyGraymaps() !void {
    var reader = zigimg.io.ReadStream.initMemory("P2\n4 1\n15\n0 7 15 300\n");
    var ascii = try netpbm.PGM.readImage(allocator, &reader);
    defer ascii.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{ 0, 7, 15, 44 }, ascii.rawBytes());
    reader = zigimg.io.ReadStream.initMemory("P5\n4 1\n15\n\x00\x07\x0f\x1e");
    var binary = try netpbm.PGM.readImage(allocator, &reader);
    defer binary.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{ 0, 119, 255, 254 }, binary.rawBytes());
    reader = zigimg.io.ReadStream.initMemory("P2\n3 1\n1000\n1 999 65537\n");
    var ascii16 = try netpbm.PGM.readImage(allocator, &reader);
    defer ascii16.deinit(allocator);
    try std.testing.expectEqualSlices(zigimg.color.Grayscale16, &.{ .{ .value = 1 }, .{ .value = 999 }, .{ .value = 1 } }, ascii16.pixels.grayscale16);
    reader = zigimg.io.ReadStream.initMemory("P5\n2 1\n1000\n\x00\x01\x03\xe7");
    var binary16 = try netpbm.PGM.readImage(allocator, &reader);
    defer binary16.deinit(allocator);
    try expectEncoded(netpbm.PGM, binary16, .{ .pgm = .{} }, "P5\n# Created by zigimg\n2 1\n65535\n\x00\x01\x03\xe7");
    try expectEncoded(netpbm.PGM, binary16, .{ .pgm = .{ .binary = false } }, "P2\n# Created by zigimg\n2 1\n65535\n1 999\n");
}

fn verifyRgbmaps() !void {
    var reader = zigimg.io.ReadStream.initMemory("P3\n2 1\n1000\n0 500 1000 1 999 65537\n");
    var ascii = try netpbm.PPM.readImage(allocator, &reader);
    defer ascii.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{ 0, 127, 255, 0, 254, 71 }, ascii.rawBytes());
    reader = zigimg.io.ReadStream.initMemory("P6\n2 1\n1000\n\x00\x00\x01\xf4\x03\xe8\x00\x01\x03\xe7\xff\xff");
    var binary = try netpbm.PPM.readImage(allocator, &reader);
    defer binary.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{ 0, 127, 255, 0, 254, 71 }, binary.rawBytes());
    try expectEncoded(netpbm.PPM, binary, .{ .ppm = .{} }, "P6\n# Created by zigimg\n2 1\n255\n\x00\x7f\xff\x00\xfe\x47");
    try expectEncoded(netpbm.PPM, binary, .{ .ppm = .{ .binary = false } }, "P3\n# Created by zigimg\n2 1\n255\n0 127 255\n0 254 71\n");
}

fn verifyParsing() !void {
    for ([_][]const u8{ "P1", "P2", "P3", "P4", "P5", "P6" }, 0..) |magic, i| {
        var reader = zigimg.io.ReadStream.initMemory(magic);
        try std.testing.expectEqual(i % 3 == 0, try netpbm.PBM.formatDetect(&reader));
        try std.testing.expectEqual(i % 3 == 1, try netpbm.PGM.formatDetect(&reader));
        try std.testing.expectEqual(i % 3 == 2, try netpbm.PPM.formatDetect(&reader));
        try std.testing.expectEqual(@as(u64, 0), reader.getPos());
    }
    var reader = zigimg.io.ReadStream.initMemory("P6\n1 1\n255\n\x0a\x14\x1e");
    var rgb = try netpbm.PBM.readImage(allocator, &reader);
    defer rgb.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{ 10, 20, 30 }, rgb.rawBytes());
    reader = zigimg.io.ReadStream.initMemory("P3 0# comment\n1 +0_1 +2_55 255 0 0\n");
    var comments = try netpbm.PPM.readImage(allocator, &reader);
    defer comments.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 1), comments.width);
    try std.testing.expectEqual(@as(usize, 1), comments.height);
    try std.testing.expectEqualSlices(u8, &.{ 255, 0, 0 }, comments.rawBytes());
    reader = zigimg.io.ReadStream.initMemory("P2 -0 +0 255\n");
    var empty = try netpbm.PGM.readImage(allocator, &reader);
    defer empty.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), empty.width);
    try std.testing.expectEqual(@as(usize, 0), empty.height);
    reader = zigimg.io.ReadStream.initMemory("P5 1 1 255\r\n\xff");
    var delimiter = try netpbm.PGM.readImage(allocator, &reader);
    defer delimiter.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{10}, delimiter.rawBytes());
    try std.testing.expectEqual(@as(u8, 255), try reader.reader().takeByte());
    const bad_inputs = [_][]const u8{ "P", "P0 1 1\n", "P2 1 1 255 123", "P2 -1 1 255 0\n", "P2 1_ 1 255 0\n", "P2 1 1 255 _1\n", "P2 1 1 255 00000000000000001\n", "P5 1 1 255\n" };
    const errors = [_]anyerror{ error.EndOfStream, error.InvalidData, error.EndOfStream, error.InvalidData, error.InvalidData, error.InvalidData, error.OutOfMemory, error.EndOfStream };
    for (bad_inputs, errors) |input, expected_error| {
        reader = zigimg.io.ReadStream.initMemory(input);
        try std.testing.expectError(expected_error, netpbm.PGM.readImage(allocator, &reader));
    }
    var output: [8]u8 = undefined;
    var writer = zigimg.io.WriteStream.initMemory(&output);
    const image = zigimg.ImageUnmanaged{ .width = 1, .height = 1, .pixels = .{ .grayscale8 = @constCast(&[_]zigimg.color.Grayscale8{.{ .value = 1 }}) } };
    try std.testing.expectError(error.Unsupported, netpbm.PBM.writeImage(allocator, &writer, image, .{ .pbm = .{} }));
    try std.testing.expectEqual(@as(u64, 0), writer.getPos());
    try std.testing.expectError(error.WriteFailed, netpbm.PGM.writeImage(allocator, &writer, image, .{ .pgm = .{} }));
    try std.testing.expectEqualSlices(u8, "P5\n# Cre", writer.memory.buffered());
}
