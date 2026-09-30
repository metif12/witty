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
    std.debug.print("PASS: locked QOI/farbfeld bytes and signature-only PNG writer\n", .{});
}
