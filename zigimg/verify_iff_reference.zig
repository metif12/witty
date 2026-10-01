const std = @import("std");
const builtin = @import("builtin");
const zigimg = @import("zigimg");
const iff = zigimg.formats.iff;
const allocator = std.heap.page_allocator;

fn chunk(name: []const u8, length: u32, data: []const u8) ![]u8 {
    const bytes = try allocator.alloc(u8, 8 + data.len);
    var writer = std.Io.Writer.fixed(bytes);
    try writer.writeAll(name);
    try writer.writeInt(u32, length, .big);
    try writer.writeAll(data);
    return bytes;
}

fn bmhd(header: iff.BmhdHeader) ![]u8 {
    var bytes: [20]u8 = undefined;
    var writer = std.Io.Writer.fixed(&bytes);
    try writer.writeStruct(header, .big);
    return chunk("BMHD", 20, &bytes);
}

fn fixture(format: []const u8, header: iff.BmhdHeader, chunks: []const u8) ![]u8 {
    const bytes = try allocator.alloc(u8, 40 + chunks.len);
    var writer = std.Io.Writer.fixed(bytes);
    try writer.writeAll("FORM");
    try writer.writeInt(u32, 0xdeadbeef, .big);
    try writer.writeAll(format);
    try writer.writeAll(try bmhd(header));
    try writer.writeAll(chunks);
    return bytes;
}

fn planar(indices: []const u8, width: usize, height: usize, planes: usize, vertical: bool) ![]u8 {
    const pitch = ((width + 15) / 16) * 2;
    const bytes = try allocator.alloc(u8, pitch * height * planes);
    @memset(bytes, 0);
    for (0..height) |row| {
        for (0..planes) |plane| {
            const base = if (vertical) plane * height * pitch + row * pitch else row * planes * pitch + plane * pitch;
            for (0..width) |col| {
                if (indices[row * width + col] & (@as(u8, 1) << @intCast(plane)) != 0)
                    bytes[base + col / 8] |= @as(u8, 1) << @intCast(7 - col % 8);
            }
        }
    }
    return bytes;
}

fn concat(parts: []const []const u8) ![]u8 {
    var size: usize = 0;
    for (parts) |part| size += part.len;
    const bytes = try allocator.alloc(u8, size);
    var writer = std.Io.Writer.fixed(bytes);
    for (parts) |part| try writer.writeAll(part);
    return bytes;
}

pub fn verify() !void {
    try verifyHeaders();
    try verifyPixels();
    try verifyColors();
    try verifyByteRun2();
    try verifyErrors();
}

fn verifyHeaders() !void {
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(iff.ChunkHeader));
    try std.testing.expectEqual(@as(usize, 1), @alignOf(iff.ChunkHeader));
    try std.testing.expectEqual(@as(usize, 20), @sizeOf(iff.BmhdHeader));
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(iff.DgblHeader));
    try std.testing.expectEqualStrings("DBGL", iff.Chunks.DGBL.name);
    var header = iff.ChunkHeader{ .type = iff.Chunks.BMHD.id, .length = 0 };
    const name = header.name();
    try std.testing.expectEqualStrings(if (builtin.cpu.arch.endian() == .little) "DHMB" else "BMHD", name);
    header.type = iff.Chunks.BODY.id;
    try std.testing.expectEqualStrings(if (builtin.cpu.arch.endian() == .little) "YDOB" else "BODY", name);
    for ([_][]const u8{ "ILBM", "PBM ", "ACBM", "DEEP", "XXXX" }, 0..) |format, index| {
        var reader = zigimg.io.ReadStream.initMemory(try fixture(format, .{}, ""));
        try std.testing.expectEqual(index < 3, try iff.IFF.formatDetect(&reader));
        try std.testing.expectEqual(@as(u64, 0), reader.getPos());
    }
    for ([_][]const u8{ "", "FORM", "FORM0123ILB" }) |bytes| {
        var reader = zigimg.io.ReadStream.initMemory(bytes);
        try std.testing.expect(!try iff.IFF.formatDetect(&reader));
        try std.testing.expectEqual(@as(u64, 0), reader.getPos());
    }
    var reader = zigimg.io.ReadStream.initMemory("FORM0123DEEP");
    try std.testing.expectError(error.InvalidData, iff.takeIffFormatId(reader.reader()));
    try std.testing.expectEqual(@as(u64, 12), reader.getPos());
    const meta = iff.BmhdHeader{ .width = 16, .height = 2, .x = -2, .y = -32768, .planes = 7, .mask_type = .has_lasso, .compression_type = .byterun2, .pad = 0x99, .transparent_color = 0x1234, .x_asoect = 5, .y_aspect = 6, .page_width = 789, .page_height = 1234 };
    reader = zigimg.io.ReadStream.initMemory(try bmhd(meta));
    try std.testing.expectEqualDeep(meta, try iff.decodeBmhdChunk(&reader));
    try std.testing.expectEqual(@as(u64, 28), reader.getPos());
    reader = zigimg.io.ReadStream.initMemory(&.{ 1, 2, 3 });
    try std.testing.expectEqualDeep(iff.DgblHeader{}, try iff.decodeDbglChunk(&reader));
    try std.testing.expectEqualDeep(iff.DgblHeader{}, (try iff.loadHeader(&reader, .deep)).dgbl);
    try std.testing.expectEqual(@as(u64, 0), reader.getPos());
    var codec = iff.IFF{ .header = .{ .dgbl = .{ .width = 23, .height = 45 } }, .viewport_mode = @intFromEnum(iff.ViewportMode.ham) };
    try std.testing.expectEqual(@as(usize, 23), codec.width());
    try std.testing.expectEqual(@as(usize, 45), codec.height());
    try std.testing.expectEqual(zigimg.PixelFormat.rgb24, try codec.pixelFormat());
}

fn verifyPixels() !void {
    const indices = [_]u8{ 0, 1, 2, 3, 1, 0, 2, 3, 0, 1, 2, 3, 3, 2, 1, 0, 3, 2, 1, 0, 2, 3, 1, 0, 3, 2, 1, 0, 0, 1, 2, 3 };
    for ([_][]const u8{ "ILBM", "ACBM" }, 0..) |format, index| {
        const acbm = index == 1;
        const chunks = try concat(&.{ try chunk("JUNK", 1, &.{99}), try chunk("CMAP", 12, &.{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }), try chunk(if (acbm) "ABIT" else "BODY", 1, try planar(&indices, 16, 2, 2, acbm)) });
        var reader = zigimg.io.ReadStream.initMemory(try fixture(format, .{ .width = 16, .height = 2, .planes = 2, .compression_type = if (acbm) .byterun else .none }, chunks));
        var codec = iff.IFF{};
        const pixels = try codec.read(&reader, allocator);
        defer pixels.deinit(allocator);
        try std.testing.expectEqualSlices(u8, &indices, pixels.asBytes());
        try std.testing.expectEqual(@as(u64, 85), reader.getPos());
        try std.testing.expectEqual(@as(u16, 2), codec.pitch);
        try std.testing.expectEqual(@as(u8, 2), codec.cmap_bits);
        try std.testing.expectEqual(@as(usize, 4), pixels.indexed8.palette.len);
        try std.testing.expectEqualDeep(zigimg.color.Rgba32{ .r = 10, .g = 11, .b = 12, .a = 255 }, pixels.indexed8.palette[3]);
        codec.palette.data[3].r = 99;
        try std.testing.expectEqual(@as(u8, 10), pixels.indexed8.palette[3].r);
    }
    var raw: [32]u8 = undefined;
    for (&raw, 0..) |*byte, i| byte.* = @intCast(i + 1);
    var reader = zigimg.io.ReadStream.initMemory(try fixture("PBM ", .{ .width = 3, .height = 2, .planes = 8 }, try chunk("BODY", 1, &raw)));
    var image = try iff.IFF.readImage(allocator, &reader);
    defer image.deinit(allocator);
    try std.testing.expectEqualSlices(u8, raw[0..6], image.rawBytes());
    try std.testing.expectEqual(@as(usize, 3), image.width);
    try std.testing.expectEqual(@as(usize, 2), image.height);
    try std.testing.expectEqual(@as(u64, 80), reader.getPos());
    var codec = iff.IFF{ .format_id = .ilbm, .header = .{ .bmhd = .{ .width = 9, .height = 2, .planes = 1 } }, .pitch = 2 };
    var chunky: [18]u8 = undefined;
    var bitplanes = [_]u8{ 0, 0x40, 0x80, 0 };
    try codec.planarToChunky(&bitplanes, &chunky);
    for (chunky, 0..) |byte, i| try std.testing.expectEqual(@as(u8, if (i == 9) 1 else 0), byte);
    reader = zigimg.io.ReadStream.initMemory(try fixture("ILBM", .{ .width = 16, .height = 1, .planes = 1, .compression_type = .byterun }, try chunk("BODY", 4, &.{ 1, 0x80, 1, 0x99 })));
    var compressed = try iff.IFF.readImage(allocator, &reader);
    defer compressed.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 }, compressed.rawBytes());
    try std.testing.expectEqual(@as(u64, 51), reader.getPos());
    try std.testing.expectEqual(@as(u8, 0x99), try reader.reader().takeByte());
    var rgb_planes = [_]u8{0} ** 48;
    for ([_]u8{ 0xa5, 0x5a, 0xc3 }, 0..) |value, channel| {
        for (0..8) |bit| {
            if (value & (@as(u8, 1) << @intCast(bit)) != 0) rgb_planes[(channel * 8 + bit) * 2] = 0x80;
        }
    }
    reader = zigimg.io.ReadStream.initMemory(try fixture("ILBM", .{ .width = 1, .height = 1, .planes = 24 }, try chunk("BODY", 0, &rgb_planes)));
    var rgb = try iff.IFF.readImage(allocator, &reader);
    defer rgb.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{ 0xa5, 0x5a, 0xc3 }, rgb.rawBytes());
    try std.testing.expectEqual(@as(u64, 96), reader.getPos());
}

fn verifyColors() !void {
    for ([_]u8{ 6, 8, 0 }) |case| {
        const planes: u8 = if (case == 0) 6 else case;
        const palette_len: usize = if (case == 0) 256 else if (planes == 6) 16 else 64;
        const colors = try allocator.alloc(u8, palette_len * 3);
        @memset(colors, 0);
        @memcpy(colors[3..6], &[_]u8{ 10, 20, 30 });
        const control: u8 = if (planes == 6) 16 else 64;
        const indices = [_]u8{ 1, control + 10, control * 2 + 3, control * 3 + 4, control + 5, 1, control * 2 + 2, control * 3 + 6 };
        const chunks = try concat(&.{ try chunk("CMAP", @intCast(colors.len), colors), try chunk("CAMG", 900, &.{ 0, 0, 8, 0 }), try chunk("BODY", 0, try planar(&indices, 4, 2, planes, false)) });
        var reader = zigimg.io.ReadStream.initMemory(try fixture("ILBM", .{ .width = 4, .height = 2, .planes = planes }, chunks));
        var image = try iff.IFF.readImage(allocator, &reader);
        defer image.deinit(allocator);
        const shift: u3 = if (planes == 6) 4 else 2;
        const expected = [_]u8{ 10, 20, 30, 10, 20, @as(u8, 10) << shift, @as(u8, 3) << shift, 20, @as(u8, 10) << shift, @as(u8, 3) << shift, @as(u8, 4) << shift, @as(u8, 10) << shift, 0, 0, @as(u8, 5) << shift, 10, 20, 30, @as(u8, 2) << shift, 20, 30, @as(u8, 2) << shift, @as(u8, 6) << shift, 30 };
        try std.testing.expectEqualSlices(u8, &expected, image.rawBytes());
    }
    var codec = iff.IFF{ .header = .{ .bmhd = .{ .planes = 6 } }, .cmap_bits = 8 };
    codec.palette.resize(256);
    codec.reduceHamPalette();
    try std.testing.expectEqual(@as(u8, 4), codec.cmap_bits);
    try std.testing.expectEqual(@as(usize, 16), codec.palette.data.len);
    for ([_]u8{ 34, 66, 130 }) |planes| {
        var reducer = iff.IFF{ .header = .{ .bmhd = .{ .planes = planes } }, .cmap_bits = planes + 1 };
        reducer.palette.resize(256);
        reducer.reduceHamPalette();
        const shift: std.math.Log2Int(usize) = @truncate(planes - 2);
        try std.testing.expectEqual(planes - 2, reducer.cmap_bits);
        try std.testing.expectEqual(@as(usize, 256) >> shift, reducer.palette.data.len);
    }
    codec.palette.resize(32);
    for (codec.palette.data, 0..) |*color, i| color.* = .{ .r = @intCast(i * 3), .g = @intCast(i * 5), .b = @intCast(i * 7), .a = 0 };
    iff.extendEhbPalette(&codec.palette);
    try std.testing.expectEqual(@as(usize, 64), codec.palette.data.len);
    try std.testing.expectEqualDeep(zigimg.color.Rgba32{ .r = 46, .g = 77, .b = 108, .a = 255 }, codec.palette.data[63]);
    var palette_bytes: [96]u8 = undefined;
    for (0..32) |i| {
        palette_bytes[i * 3] = @intCast(i * 3);
        palette_bytes[i * 3 + 1] = @intCast(i * 5);
        palette_bytes[i * 3 + 2] = @intCast(i * 7);
    }
    const chunks = try concat(&.{ try chunk("CMAP", 96, &palette_bytes), try chunk("CAMG", 4, &.{ 0, 0, 0, 0x80 }), try chunk("BODY", 0, try planar(&.{ 31, 63 }, 2, 1, 6, false)) });
    var reader = zigimg.io.ReadStream.initMemory(try fixture("ILBM", .{ .width = 2, .height = 1, .planes = 6 }, chunks));
    var image = try iff.IFF.readImage(allocator, &reader);
    defer image.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{ 31, 63 }, image.pixels.indexed8.indices);
    try std.testing.expectEqual(@as(usize, 64), image.pixels.indexed8.palette.len);
    try std.testing.expectEqualDeep(zigimg.color.Rgba32{ .r = 46, .g = 77, .b = 108, .a = 255 }, image.pixels.indexed8.palette[63]);
    const both_chunks = try concat(&.{ try chunk("CMAP", 96, &palette_bytes), try chunk("CAMG", 4, &.{ 0, 0, 8, 0x80 }), try chunk("BODY", 0, try planar(&.{ 31, 63 }, 2, 1, 6, false)) });
    reader = zigimg.io.ReadStream.initMemory(try fixture("ILBM", .{ .width = 2, .height = 1, .planes = 6 }, both_chunks));
    var both = try iff.IFF.readImage(allocator, &reader);
    defer both.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{ 93, 155, 217, 46, 77, 108 }, both.rawBytes());
}

fn verifyByteRun2() !void {
    var codec = iff.IFF{ .header = .{ .bmhd = .{ .width = 32, .height = 3, .planes = 1, .compression_type = .byterun2 } }, .pitch = 4 };
    var reader = zigimg.io.ReadStream.initMemory(try chunk("VDAT", 0xffffffff, &.{ 0, 6, 0xff, 0, 1, 2, 0x11, 0x22, 0, 1, 0x33, 0x44, 0, 2, 0x55, 0x66, 0x77, 0x88 }));
    var buffer: [12]u8 = @splat(0xee);
    try codec.decodeByteRun2(&reader, &buffer, allocator);
    try std.testing.expectEqualSlices(u8, &.{ 0x11, 0x22, 0x55, 0x66, 0x33, 0x44, 0x77, 0x88, 0x55, 0x66, 0x77, 0x88 }, &buffer);
    try std.testing.expectEqual(@as(u64, 26), reader.getPos());
    reader = zigimg.io.ReadStream.initMemory(try chunk("VDAT", 0, &.{ 0, 3, 0x80, 0xa0, 0, 0xb0, 0, 0xc0, 0, 0xdd }));
    var one_col = iff.IFF{ .header = .{ .bmhd = .{ .width = 16, .height = 3, .planes = 1 } }, .pitch = 2 };
    var col: [6]u8 = undefined;
    try one_col.decodeByteRun2(&reader, &col, allocator);
    try std.testing.expectEqualSlices(u8, &.{ 0xa0, 0, 0xb0, 0, 0xc0, 0 }, &col);
    try std.testing.expectEqual(@as(u8, 0xdd), try reader.reader().takeByte());
    const body = try concat(&.{ try chunk("VDAT", 0, &.{ 0, 3, 2, 0x80, 0 }), try chunk("VDAT", 0, &.{ 0, 3, 2, 0x40, 0 }) });
    reader = zigimg.io.ReadStream.initMemory(try fixture("ILBM", .{ .width = 16, .height = 2, .planes = 2, .compression_type = .byterun2 }, try chunk("BODY", 0, body)));
    var image = try iff.IFF.readImage(allocator, &reader);
    defer image.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, image.rawBytes()[0..16]);
    try std.testing.expectEqualSlices(u8, image.rawBytes()[0..16], image.rawBytes()[16..32]);
}

fn verifyErrors() !void {
    for ([_]usize{ 0, 7, 8, 27 }) |size| {
        var reader = zigimg.io.ReadStream.initMemory((try bmhd(.{}))[0..size]);
        try std.testing.expectError(error.EndOfStream, iff.decodeBmhdChunk(&reader));
        try std.testing.expectEqual(@as(u64, if (size < 8) 0 else 8), reader.getPos());
    }
    var reader = zigimg.io.ReadStream.initMemory(try chunk("BMHD", 19, &(@as([20]u8, @splat(0)))));
    try std.testing.expectError(error.InvalidData, iff.decodeBmhdChunk(&reader));
    try std.testing.expectEqual(@as(u64, 8), reader.getPos());
    var codec = iff.IFF{ .header = .{ .bmhd = .{ .planes = 1 } }, .pitch = 2, .cmap_bits = 7, .viewport_mode = 0x99 };
    reader = zigimg.io.ReadStream.initMemory(&.{ 1, 2, 3, 4, 5 });
    try std.testing.expectError(error.EndOfStream, codec.decodeCMAPChunk(&reader, &.{ .type = 0, .length = 6 }));
    try std.testing.expectEqual(@as(u64, 3), reader.getPos());
    try std.testing.expectEqual(@as(u8, 7), codec.cmap_bits);
    try std.testing.expectEqual(@as(usize, 2), codec.palette.data.len);
    try std.testing.expectEqualDeep(zigimg.color.Rgba32{ .r = 1, .g = 2, .b = 3, .a = 255 }, codec.palette.data[0]);
    reader = zigimg.io.ReadStream.initMemory(&.{ 1, 2, 3, 0xff });
    try codec.decodeCMAPChunk(&reader, &.{ .type = 0, .length = 4 });
    try std.testing.expectEqual(@as(u64, 3), reader.getPos());
    try std.testing.expectEqual(@as(u8, 0), codec.cmap_bits);
    try std.testing.expectEqual(@as(u8, 0xff), try reader.reader().takeByte());
    reader = zigimg.io.ReadStream.initMemory(&.{ 1, 2, 3 });
    try std.testing.expectError(error.EndOfStream, codec.decodeCAMGChunk(&reader));
    try std.testing.expectEqual(@as(u64, 0), reader.getPos());
    try std.testing.expectEqual(@as(u32, 0x99), codec.viewport_mode);
    for ([_]usize{ 0, 3, 8, 9 }) |size| {
        const bytes = try allocator.alloc(u8, size);
        @memset(bytes, 0);
        reader = zigimg.io.ReadStream.initMemory(bytes);
        var buffer = [_]u8{ 99, 99 };
        try std.testing.expectError(error.EndOfStream, codec.decodeByteRun2(&reader, &buffer, allocator));
        try std.testing.expectEqual(@as(u64, if (size < 8) size else 8), reader.getPos());
        try std.testing.expectEqualSlices(u8, &.{ 0, 0 }, &buffer);
    }
    reader = zigimg.io.ReadStream.initMemory(try chunk("VDAT", 0, &.{ 0, 5, 0xff, 0 }));
    var buffer = [_]u8{ 99, 99 };
    try std.testing.expectError(error.EndOfStream, codec.decodeByteRun2(&reader, &buffer, allocator));
    try std.testing.expectEqual(@as(u64, 12), reader.getPos());
    try std.testing.expectEqualSlices(u8, &.{ 0, 0 }, &buffer);
    for (0..2) |tail| {
        const chunks = try concat(&.{ try chunk("JUNK", 1, &.{0}), if (tail == 1) &.{0} else "" });
        reader = zigimg.io.ReadStream.initMemory(try fixture("ILBM", .{}, chunks));
        try std.testing.expectError(if (tail == 0) error.Unseekable else error.Unsupported, codec.read(&reader, allocator));
        try std.testing.expectEqual(@as(u64, if (tail == 0) 48 else 49), reader.getPos());
    }
    reader = zigimg.io.ReadStream.initMemory(try fixture("ILBM", .{ .width = 16, .height = 1, .planes = 1 }, try chunk("BODY", 1, &.{0x80})));
    try std.testing.expectError(error.EndOfStream, codec.read(&reader, allocator));
    try std.testing.expectEqual(@as(u64, 49), reader.getPos());
    var output: [0]u8 = undefined;
    var writer = zigimg.io.WriteStream.initMemory(&output);
    try iff.IFF.writeImage(allocator, &writer, .{ .width = 999, .height = 123 }, .{ .iff = {} });
    try std.testing.expectEqual(@as(u64, 0), writer.getPos());
}
