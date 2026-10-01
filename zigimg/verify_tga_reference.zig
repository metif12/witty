const std = @import("std");
const zigimg = @import("zigimg");
const tga = zigimg.formats.tga;
const allocator = std.heap.page_allocator;

fn header(kind: u8, depth: u8, width: u16, height: u16, descriptor: u8) tga.TGAHeader {
    return .{ .image_type = @bitCast(kind), .image_spec = .{ .width = width, .height = height, .bit_per_pixel = depth, .descriptor = @bitCast(descriptor) } };
}

fn fixture(h: tga.TGAHeader, body: []const u8, extension: ?tga.TGAExtension) ![]u8 {
    const bytes = try allocator.alloc(u8, 18 + body.len + (if (extension != null) @as(usize, 495) else 0) + 26);
    var writer = std.Io.Writer.fixed(bytes);
    try writer.writeStruct(h, .little);
    try writer.writeAll(body);
    var footer = tga.TGAFooter{};
    if (extension) |value| {
        footer.extension_offset = @intCast(writer.end);
        try writer.writeStruct(value, .little);
    }
    footer.signature = tga.TGASignature.*;
    try writer.writeStruct(footer, .little);
    return bytes;
}

pub fn verify() !void {
    try verifyMetadata();
    try verifyDetection();
    try verifyReading();
    try verifyReadAhead();
    try verifyErrors();
    try verifyWriting();
    try verifyEncoderHash();
    try verifyDecoderHash();
}

fn verifyMetadata() !void {
    try std.testing.expectEqual(@as(usize, 495), @sizeOf(tga.TGAExtension));
    try std.testing.expectEqual(@as(usize, 40), @as(tga.TGAExtension, .{}).author_name.len);
    var extension = tga.TGAExtension{
        .extension_size = 123,
        .timestamp = .{ .month = 1, .day = 2, .year = 2003, .hour = 4, .minute = 5, .second = 6 },
        .job_time = .{ .hours = 100, .minutes = 11, .seconds = 12 },
        .software_version = .{ .number = 321, .letter = 'b' },
        .key_color = .{ .b = 1, .g = 2, .r = 3, .a = 4 },
        .pixel_aspect = .{ .numerator = 5, .denominator = 6 },
        .gamma_value = .{ .numerator = 7, .denominator = 8 },
        .color_correction_offset = 0x12345678,
        .postage_stamp_offset = 0x89abcdef,
        .scanline_offset = 0x76543210,
        .attributes = .premultipled_alpha,
    };
    for (0..40) |i| {
        extension.author_name[i] = @intCast(i + 1);
        extension.job_id[i] = @intCast(i + 2);
        extension.software_id[i] = @intCast(i + 3);
    }
    for (0..4) |row| for (0..80) |col| {
        extension.author_comment.lines[row][col] = @truncate(row * 81 + col);
    };
    var output: [495]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    try writer.writeStruct(extension, .little);
    try std.testing.expectEqualSlices(u8, &.{ 1, 0, 2, 0, 0xd3, 7, 4, 0, 5, 0, 6, 0 }, output[367..379]);
    try std.testing.expectEqualSlices(u8, &.{ 0x41, 1, 'b', 1, 2, 3, 4, 5, 0, 6, 0, 7, 0, 8, 0, 0x78, 0x56, 0x34, 0x12, 0xef, 0xcd, 0xab, 0x89, 0x10, 0x32, 0x54, 0x76, 4 }, output[467..]);
}

fn verifyDetection() !void {
    var output: [27]u8 = @splat(0);
    for ([_]usize{ 0, 18, 19, 26, 27 }) |length| {
        var reader = zigimg.io.ReadStream.initMemory(output[0..length]);
        if (length > 1) try reader.seekTo(1);
        try std.testing.expectEqual(length > 18, try tga.TGA.formatDetect(&reader));
        try std.testing.expectEqual(@as(u64, 0), reader.getPos());
    }
    const bytes = try fixture(header(0xf0, 7, 0, 0, 0), "", null);
    var reader = zigimg.io.ReadStream.initMemory(bytes);
    try std.testing.expect(try tga.TGA.formatDetect(&reader));
    bytes[bytes.len - 2] = 0;
    reader = zigimg.io.ReadStream.initMemory(bytes);
    try std.testing.expect(!try tga.TGA.formatDetect(&reader));
    try std.testing.expectEqual(@as(u64, 0), reader.getPos());
}

fn verifyReading() !void {
    var h = header(2, 24, 2, 2, 0xdf);
    h.id_length = 3;
    h.image_spec.origin_x = 77;
    h.image_spec.origin_y = 88;
    var reader = zigimg.io.ReadStream.initMemory(try fixture(h, &.{ 'i', 'd', '!', 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }, null));
    var codec = tga.TGA{};
    var pixels = try codec.read(allocator, &reader);
    try std.testing.expectEqualSlices(u8, &.{ 7, 8, 9, 10, 11, 12, 1, 2, 3, 4, 5, 6 }, pixels.asBytes());
    try std.testing.expectEqualSlices(u8, "id!", codec.id.data);
    try std.testing.expectEqual(@as(u64, 33), reader.getPos());
    pixels.deinit(allocator);
    reader = zigimg.io.ReadStream.initMemory(try fixture(header(3, 200, 2, 2, 32), &.{ 1, 2, 3, 4 }, null));
    pixels = try codec.read(allocator, &reader);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 4 }, pixels.asBytes());
    try std.testing.expectEqualSlices(u8, "id!", codec.id.data);
    pixels.deinit(allocator);
    reader = zigimg.io.ReadStream.initMemory(try fixture(header(2, 16, 2, 1, 32), &.{ 0xff, 0xff, 0x43, 0xa5 }, null));
    pixels = try codec.read(allocator, &reader);
    try std.testing.expectEqual(zigimg.color.Rgb555{ .r = 31, .g = 31, .b = 31 }, pixels.rgb555[0]);
    try std.testing.expectEqual(zigimg.color.Rgb555{ .r = 9, .g = 10, .b = 3 }, pixels.rgb555[1]);
    pixels.deinit(allocator);
    for ([_]u8{ 15, 16, 24 }) |depth| {
        h = header(1, 8, 2, 1, 32);
        h.color_map_spec = .{ .length = 2, .bit_depth = depth };
        const body: []const u8 = if (depth == 24) &.{ 3, 2, 1, 6, 5, 4, 1, 0 } else &.{ 0x23, 0xc5, 0xff, 0x7f, 1, 0 };
        reader = zigimg.io.ReadStream.initMemory(try fixture(h, body, null));
        pixels = try codec.read(allocator, &reader);
        try std.testing.expectEqualSlices(u8, &.{ 1, 0 }, pixels.indexed8.indices);
        try std.testing.expectEqual(@as(usize, 2), pixels.indexed8.palette.len);
        try std.testing.expectEqual(zigimg.color.Rgba32{ .r = if (depth == 24) 1 else 140, .g = if (depth == 24) 2 else 74, .b = if (depth == 24) 3 else 25 }, pixels.indexed8.palette[0]);
        pixels.deinit(allocator);
    }
    inline for (std.meta.tags(tga.TGAAttributeType)) |attribute| {
        const bytes = try fixture(header(2, 32, 1, 1, 0), &.{ 1, 2, 3, 4 }, .{ .extension_size = 1, .attributes = attribute });
        bytes[bytes.len - 2] = 0;
        bytes[bytes.len - 1] = 7;
        reader = zigimg.io.ReadStream.initMemory(bytes);
        codec = .{};
        pixels = try codec.read(allocator, &reader);
        try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, if (attribute == .useful_alpha_channel) 4 else 255 }, pixels.asBytes());
        try std.testing.expectEqual(@as(u16, 1), codec.extension.?.extension_size);
        pixels.deinit(allocator);
    }
    codec = .{};
    reader = zigimg.io.ReadStream.initMemory(try fixture(header(2, 32, 1, 1, 0), &.{ 1, 2, 3, 4 }, null));
    pixels = try codec.read(allocator, &reader);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 4 }, pixels.asBytes());
    pixels.deinit(allocator);
    codec.extension = .{};
    try reader.seekTo(0);
    pixels = try codec.read(allocator, &reader);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 255 }, pixels.asBytes());
    pixels.deinit(allocator);
}

fn verifyReadAhead() !void {
    for (1..5) |bpp| {
        var body: [40]u8 = undefined;
        var writer = std.Io.Writer.fixed(&body);
        for (0..8) |packet| {
            try writer.writeByte(0xff);
            for (0..bpp) |channel| try writer.writeByte(@intCast(packet * 8 + channel));
        }
        var reader = zigimg.io.ReadStream.initMemory(try fixture(header(if (bpp == 1) 11 else 10, @intCast(bpp * 8), 200, 1, 32), writer.buffered(), null));
        var codec = tga.TGA{};
        const pixels = try codec.read(allocator, &reader);
        defer pixels.deinit(allocator);
        for (pixels.asBytes(), 0..) |byte, i| try std.testing.expectEqual(@as(u8, @intCast(((i / bpp) / 128) * 8 + (i % bpp))), if (bpp == 2 and i % 2 == 1) byte & 127 else byte);
        const packets: usize = switch (bpp) {
            1 => 4,
            2 => 2,
            3 => 3,
            4 => 2,
            else => unreachable,
        };
        try std.testing.expectEqual(@as(u64, 18 + packets * (1 + bpp)), reader.getPos());
    }
    var bytes: [28]u8 = undefined;
    var writer = std.Io.Writer.fixed(&bytes);
    try writer.writeStruct(header(11, 8, 1, 1, 32), .little);
    try writer.writeAll(&.{ 0x87, 9, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80 });
    var reader = zigimg.io.ReadStream.initMemory(writer.buffered());
    var codec = tga.TGA{};
    try std.testing.expectError(error.EndOfStream, codec.read(allocator, &reader));
    try std.testing.expectEqual(@as(u64, 28), reader.getPos());
    writer = .fixed(&bytes);
    try writer.writeStruct(header(11, 8, 1, 1, 32), .little);
    try writer.writeAll(&.{ 127, 9, 9, 9, 9, 9, 9, 9 });
    reader = zigimg.io.ReadStream.initMemory(writer.buffered());
    const pixels = try codec.read(allocator, &reader);
    defer pixels.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{9}, pixels.asBytes());
    try std.testing.expectEqual(@as(u64, 26), reader.getPos());
}

fn verifyErrors() !void {
    var bytes: [26]u8 = @splat(0);
    for ([_]usize{ 0, 18, 25 }) |length| {
        var reader = zigimg.io.ReadStream.initMemory(bytes[0..length]);
        var codec = tga.TGA{};
        try std.testing.expectError(error.InvalidData, codec.read(allocator, &reader));
        try std.testing.expectEqual(@as(u64, 0), reader.getPos());
    }
    var h = header(2, 24, 0, 0, 0);
    h.id_length = 20;
    var writer = std.Io.Writer.fixed(&bytes);
    try writer.writeStruct(h, .little);
    try writer.splatByteAll(77, 8);
    var reader = zigimg.io.ReadStream.initMemory(&bytes);
    var codec = tga.TGA{};
    try std.testing.expectError(error.InvalidData, codec.read(allocator, &reader));
    try std.testing.expectEqual(@as(u64, 26), reader.getPos());
    try std.testing.expectEqualSlices(u8, &.{ 77, 77, 77, 77, 77, 77, 77, 77 }, codec.id.data[0..8]);
    var partial: [27]u8 = undefined;
    for ([_]u8{ 8, 16, 24, 32 }) |depth| {
        var short = std.Io.Writer.fixed(&partial);
        const width: u16 = if (depth == 8) 10 else if (depth == 16) 5 else 3;
        try short.writeStruct(header(if (depth == 8) 3 else 2, depth, width, 1, 32), .little);
        try short.splatByteAll(7, if (depth == 16) 9 else 8);
        reader = zigimg.io.ReadStream.initMemory(short.buffered());
        try std.testing.expectError(error.EndOfStream, codec.read(allocator, &reader));
        try std.testing.expectEqual(@as(u64, 26), reader.getPos());
    }
    const bad_offset = try fixture(header(2, 24, 0, 0, 0), "", null);
    bad_offset[bad_offset.len - 26] = 250;
    reader = zigimg.io.ReadStream.initMemory(bad_offset);
    try std.testing.expectError(error.Unseekable, codec.read(allocator, &reader));
    try std.testing.expectEqual(@as(u64, bad_offset.len), reader.getPos());
    bad_offset[bad_offset.len - 26] = 1;
    reader = zigimg.io.ReadStream.initMemory(bad_offset);
    try std.testing.expectError(error.EndOfStream, codec.read(allocator, &reader));
    try std.testing.expectEqual(@as(u64, 1), reader.getPos());
    for ([_]u8{ 0, 4, 0x10 }) |kind| {
        reader = zigimg.io.ReadStream.initMemory(try fixture(header(kind, 8, 0, 0, 0), "", null));
        try std.testing.expectError(if (kind == 0) error.Unsupported else error.InvalidData, codec.read(allocator, &reader));
        try std.testing.expectEqual(@as(u64, 18), reader.getPos());
    }
}

fn verifyWriting() !void {
    var output: [2000]u8 = undefined;
    var gray = [_]zigimg.color.Grayscale8{.{ .value = 0 }};
    const image = zigimg.ImageUnmanaged{ .width = 1, .height = 1, .pixels = .{ .grayscale8 = &gray } };
    for ([_]usize{ 255, 256, 257 }) |length| {
        var id: [257]u8 = @splat(8);
        var writer = zigimg.io.WriteStream.initMemory(&output);
        if (length == 257) {
            try std.testing.expectError(error.Unsupported, tga.TGA.writeImage(allocator, &writer, image, .{ .tga = .{ .rle_compressed = false, .image_id = id[0..length] } }));
            try std.testing.expectEqual(@as(u64, 0), writer.getPos());
        } else {
            try tga.TGA.writeImage(allocator, &writer, image, .{ .tga = .{ .rle_compressed = false, .image_id = id[0..length] } });
            try std.testing.expectEqual(@as(u8, @truncate(length)), writer.memory.buffered()[0]);
            try std.testing.expectEqual(@as(u64, 540 + (if (length == 255) @as(u64, 255) else 0)), writer.getPos());
        }
    }
    var name: [40:0]u8 = @splat('a');
    name[40] = 0;
    for ([_]tga.TGA.EncoderOptions{ .{ .color_map_depth = 15 }, .{ .author_name = &name }, .{ .job_id = &name }, .{ .software_id = &name } }) |options| {
        var writer = zigimg.io.WriteStream.initMemory(&output);
        try std.testing.expectError(error.Unsupported, tga.TGA.writeImage(allocator, &writer, image, .{ .tga = options }));
        try std.testing.expectEqual(@as(u64, 0), writer.getPos());
    }
    var writer = zigimg.io.WriteStream.initMemory(&output);
    try tga.TGA.writeImage(allocator, &writer, image, .{ .tga = .{ .rle_compressed = false } });
    const complete = try allocator.dupe(u8, writer.memory.buffered());
    for ([_]usize{ 0, 17, 18, 19, 50, 539 }) |length| {
        writer = zigimg.io.WriteStream.initMemory(output[0..length]);
        try std.testing.expectError(error.WriteFailed, tga.TGA.writeImage(allocator, &writer, image, .{ .tga = .{ .rle_compressed = false } }));
        try std.testing.expectEqual(@as(u64, length), writer.getPos());
        try std.testing.expectEqualSlices(u8, complete[0..length], writer.memory.buffered());
    }
    writer = zigimg.io.WriteStream.initMemory(&output);
    var codec = tga.TGA{ .header = .{ .id_length = 1 } };
    try std.testing.expectError(error.Unsupported, codec.write(&writer, image.pixels));
    try std.testing.expectEqual(@as(u64, 18), writer.getPos());
    codec = .{ .header = header(3, 8, 0, 0, 32) };
    writer = zigimg.io.WriteStream.initMemory(&output);
    try codec.write(&writer, image.pixels);
    try std.testing.expectEqual(@as(u64, 45), writer.getPos());
    var short_name: [39:0]u8 = @splat('a');
    writer = zigimg.io.WriteStream.initMemory(&output);
    try tga.TGA.writeImage(allocator, &writer, image, .{ .tga = .{ .rle_compressed = false, .author_name = &short_name } });
    var reader = zigimg.io.ReadStream.initMemory(writer.memory.buffered());
    var decoded = try tga.TGA.readImage(allocator, &reader);
    defer decoded.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 1), decoded.width);
    try std.testing.expectEqual(@as(usize, 1), decoded.height);
    try std.testing.expectEqualSlices(u8, image.pixels.asBytes(), decoded.pixels.asBytes());
}

fn verifyEncoderHash() !void {
    var hash: u64 = 14695981039346656037;
    var cases: usize = 0;
    var output: [20000]u8 = undefined;
    inline for (.{ .grayscale8, .indexed8, .rgb555, .rgb24, .bgr24, .rgba32, .bgra32 }) |tag| {
        for ([_]usize{ 0, 1, 2, 3, 4, 7, 8, 9, 15, 16, 17, 31, 32, 33, 127, 128, 129, 255 }) |width| {
            var pixels = try zigimg.color.PixelStorage.init(allocator, tag, width * 3);
            defer pixels.deinit(allocator);
            if (tag == .indexed8) {
                pixels.indexed8.resizePalette(32);
                for (pixels.indexed8.palette, 0..) |*color, i| color.* = .{ .r = @truncate(i * 7), .g = @truncate(i * 11), .b = @truncate(i * 13), .a = @truncate(i * 3) };
            }
            const stride = @as(zigimg.PixelFormat, tag).pixelStride();
            for (0..4) |pattern| {
                for (pixels.asBytes(), 0..) |*byte, i| {
                    const pixel = i / stride;
                    const channel = i % stride;
                    const value = switch (pattern) {
                        0 => 7,
                        1 => pixel / 17,
                        2 => pixel * 13,
                        3 => pixel / 16 * 3,
                        else => unreachable,
                    };
                    byte.* = @truncate((value + channel * 5) % (if (tag == .indexed8) @as(usize, 32) else 256));
                    if (tag == .rgb555 and channel == 1) byte.* &= 127;
                }
                for ([_]bool{ true, false }) |compressed| for ([_]bool{ true, false }) |top| {
                    var writer = zigimg.io.WriteStream.initMemory(&output);
                    const image = zigimg.ImageUnmanaged{ .width = width, .height = 3, .pixels = pixels };
                    try tga.TGA.writeImage(allocator, &writer, image, .{ .tga = .{
                        .rle_compressed = compressed,
                        .top_to_bottom_image = top,
                        .color_map_depth = if (pattern % 2 == 0) 24 else 16,
                        .image_id = "ID!",
                        .author_name = "author",
                        .job_id = "job",
                        .software_id = "V",
                        .timestamp = .{ .year = 2026 },
                        .software_version = .{ .number = 123, .letter = 'b' },
                    } });
                    for (writer.memory.buffered()) |byte| {
                        hash ^= byte;
                        hash *%= 1099511628211;
                    }
                    cases += 1;
                };
            }
        }
    }
    std.debug.print("TGA encoder: {} cases, hash {x}\n", .{ cases, hash });
    try std.testing.expectEqual(@as(usize, 2016), cases);
    try std.testing.expectEqual(@as(u64, 0x44cd8ebeb8f84afc), hash);
}

fn verifyDecoderHash() !void {
    var hash: u64 = 14695981039346656037;
    var cases: usize = 0;
    var body_buffer: [20000]u8 = undefined;
    for ([_]u8{ 3, 1, 2, 2, 2 }, [_]u8{ 8, 8, 16, 24, 32 }) |kind, depth| {
        const bpp = depth / 8;
        for (0..4) |mode| {
            var body = std.Io.Writer.fixed(&body_buffer);
            if (kind == 1) for (0..32) |i| {
                try body.writeAll(&.{ @truncate(i * 13), @truncate(i * 11), @truncate(i * 7) });
            };
            for (0..16) |packet| {
                const repeated = mode == 1 or (mode == 2 and packet % 2 == 1);
                if (mode != 3) try body.writeByte(if (repeated) 255 else 127);
                for (0..(if (repeated) @as(usize, 1) else 128)) |i| {
                    for (0..bpp) |channel| {
                        const value = if (repeated) packet * 3 else (packet * 128 + i) / 17;
                        try body.writeByte(@truncate((value + channel * 5) % (if (kind == 1) @as(usize, 32) else 256)));
                    }
                }
            }
            for ([_]u16{ 0, 1, 2, 127, 128, 129, 171, 172, 255, 256, 257, 511, 512, 513 }) |width| {
                for ([_]bool{ true, false }) |top| for ([_]bool{ true, false }) |extended| {
                    var h = header(kind | (if (mode == 3) @as(u8, 0) else 8), depth, width, 2, if (top) 32 else 0);
                    if (kind == 1) h.color_map_spec = .{ .length = 32, .bit_depth = 24 };
                    var reader = zigimg.io.ReadStream.initMemory(try fixture(h, body.buffered(), if (extended) @as(tga.TGAExtension, .{}) else null));
                    var codec = tga.TGA{};
                    const pixels = try codec.read(allocator, &reader);
                    defer pixels.deinit(allocator);
                    for (pixels.asBytes(), 0..) |byte, i| {
                        hash ^= if (depth == 16 and i % 2 == 1) byte & 127 else byte;
                        hash *%= 1099511628211;
                    }
                    if (kind == 1) for (std.mem.sliceAsBytes(pixels.indexed8.palette)) |byte| {
                        hash ^= byte;
                        hash *%= 1099511628211;
                    };
                    var position = reader.getPos();
                    for (0..8) |_| {
                        hash ^= @as(u8, @truncate(position));
                        hash *%= 1099511628211;
                        position >>= 8;
                    }
                    cases += 1;
                };
            }
        }
    }
    std.debug.print("TGA decoder: {} cases, hash {x}\n", .{ cases, hash });
    try std.testing.expectEqual(@as(usize, 1120), cases);
    try std.testing.expectEqual(@as(u64, 0x04232c58bcb7f905), hash);
}
