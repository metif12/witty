const std = @import("std");
const zigimg = @import("zigimg");
const XBM = zigimg.formats.xbm.XBM;
const allocator = std.heap.page_allocator;

pub fn verify() !void {
    const text = "#define name_width 4\n#define name_height 4\nstatic unsigned char bits[] = {\n0x0F, 0x0F, 0xF0, 0xF0\n};\n";
    var reader = zigimg.io.ReadStream.initMemory(text);
    var codec = XBM{};
    const pixels = try codec.read(allocator, &reader);
    defer pixels.deinit(allocator);
    try std.testing.expectEqual(@as(u32, 4), codec.width);
    try std.testing.expectEqual(@as(u32, 4), codec.height);
    try std.testing.expectEqualSlices(u1, &.{ 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0 }, pixels.indexed1.indices);
    try std.testing.expectEqualSlices(zigimg.color.Rgba32, &.{ .{ .r = 255, .g = 255, .b = 255 }, .{ .r = 0, .g = 0, .b = 0 } }, pixels.indexed1.palette);
    try std.testing.expectEqual(try reader.getEndPos(), reader.getPos());
    reader = zigimg.io.ReadStream.initMemory("#define a 8\n#define b 2\n{0X55, 0xaa};\n");
    var image = try XBM.readImage(allocator, &reader);
    defer image.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{ 1, 0, 1, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0, 1 }, image.rawBytes());
    reader = zigimg.io.ReadStream.initMemory("#define unrelated +0_8 \r\n#define whatever +1\n#define y -0\n#define x 7\n#define more 8\n#define ignored 9\n{0x01}\n");
    const hotspots = try codec.read(allocator, &reader);
    defer hotspots.deinit(allocator);
    try std.testing.expectEqual(@as(u32, 8), codec.width);
    try std.testing.expectEqual(@as(u32, 1), codec.height);
    try std.testing.expectEqual(@as(u32, 7), codec.hotspot_x);
    try std.testing.expectEqual(@as(u32, 8), codec.hotspot_y);
    reader = zigimg.io.ReadStream.initMemory("#define width 0\n#define height 5\n{ };\n");
    var empty = try XBM.readImage(allocator, &reader);
    defer empty.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), empty.rawBytes().len);
    reader = zigimg.io.ReadStream.initMemory("#define w 16\n#define h 2\n{0xgg, 0x1ffffffff, 0x-1, 0x, 0x+1_55, 0x-0, 0x123456, 77};\n");
    var words = try XBM.readImage(allocator, &reader);
    defer words.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{ 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 0 }, words.rawBytes());
    for ([_][]const u8{ "#define w 8\n#define h 1\n{0xff}\r\n", "#define w 8\n#define h 1\n{\n0xff\r\n0x55\n}\n" }, 0..) |crlf, i| {
        reader = zigimg.io.ReadStream.initMemory(crlf);
        var cr_image = try XBM.readImage(allocator, &reader);
        defer cr_image.deinit(allocator);
        try std.testing.expectEqualSlices(u8, if (i == 0) &.{ 1, 1, 1, 1, 1, 1, 1, 1 } else &.{ 1, 0, 1, 0, 1, 0, 1, 0 }, cr_image.rawBytes());
    }
    const prefix = "#define w 8\n#define h 1\n{0xff}\n";
    reader = zigimg.io.ReadStream.initMemory(prefix ++ "0x55");
    var ignored = try XBM.readImage(allocator, &reader);
    defer ignored.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{ 1, 1, 1, 1, 1, 1, 1, 1 }, ignored.rawBytes());
    try std.testing.expectEqual(@as(u64, prefix.len), reader.getPos());
    reader = zigimg.io.ReadStream.initMemory("#define w 8\n#define h 1\n{\n0xff");
    try std.testing.expectError(error.InvalidData, XBM.readImage(allocator, &reader));
    try std.testing.expectEqual(@as(u64, 26), reader.getPos());
    reader = zigimg.io.ReadStream.initMemory("#define w 8\n#define h 1\n{0xff}");
    try std.testing.expectError(error.EndOfStream, XBM.readImage(allocator, &reader));
    try std.testing.expectEqual(@as(u64, 24), reader.getPos());
    for ([_][]const u8{ "#define w -1\n", "#define w 4294967296\n", "#define w 8\t\n" }) |invalid| {
        reader = zigimg.io.ReadStream.initMemory(invalid);
        codec = .{ .width = 99, .height = 88 };
        try std.testing.expectError(error.InvalidData, codec.read(allocator, &reader));
        try std.testing.expectEqual(@as(u32, 99), codec.width);
        try std.testing.expectEqual(@as(u32, 88), codec.height);
        try std.testing.expectEqual(@as(u64, invalid.len), reader.getPos());
    }
    reader = zigimg.io.ReadStream.initMemory("#define w 8\n{}\n");
    try std.testing.expectError(error.InvalidData, XBM.readImage(allocator, &reader));
    reader = zigimg.io.ReadStream.initMemory("#define w 8\n#define h 1\n{}\n");
    codec = .{ .width = 99, .height = 88 };
    try std.testing.expectError(error.InvalidData, codec.read(allocator, &reader));
    try std.testing.expectEqual(@as(u32, 8), codec.width);
    try std.testing.expectEqual(@as(u32, 1), codec.height);
    try std.testing.expectEqual(try reader.getEndPos(), reader.getPos());
    for ([_][]const u8{ "anything\n", "\n", " #define w 8\n" }) |non_define| {
        reader = zigimg.io.ReadStream.initMemory(non_define);
        try std.testing.expect(!try XBM.formatDetect(&reader));
        try std.testing.expectEqual(@as(u64, 0), reader.getPos());
    }
    for ([_][]const u8{ "", "#define w 8" }) |no_newline| {
        reader = zigimg.io.ReadStream.initMemory(no_newline);
        try std.testing.expectError(error.EndOfStream, XBM.formatDetect(&reader));
        try std.testing.expectEqual(@as(u64, 0), reader.getPos());
    }
    var output: [0]u8 = .{};
    var writer = zigimg.io.WriteStream.initMemory(&output);
    try XBM.writeImage(allocator, &writer, .{}, .{ .xbm = {} });
    try std.testing.expectEqual(@as(u64, 0), writer.getPos());
}
