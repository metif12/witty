const std = @import("std");
const zigimg = @import("zigimg");
const PAM = zigimg.formats.pam.PAM;
const allocator = std.heap.page_allocator;

fn fixture(output: []u8, width: usize, height: usize, depth: usize, maxval: u16, tuple: []const u8, data: []const u8) ![]const u8 {
    var writer = std.Io.Writer.fixed(output);
    try writer.print("P7\nWIDTH {d}\nHEIGHT {d}\nDEPTH {d}\nMAXVAL {d}\n", .{ width, height, depth, maxval });
    if (tuple.len > 0) try writer.print("TUPLTYPE {s}\n", .{tuple});
    try writer.writeAll("ENDHDR\n");
    try writer.writeAll(data);
    return writer.buffered();
}

fn expectValues(pixels: zigimg.color.PixelStorage, expected: []const u16) !void {
    var values: [4]u16 = undefined;
    var count: usize = 0;
    switch (pixels) {
        inline .grayscale1, .grayscale8, .grayscale16 => |data| {
            values[0] = data[0].value;
            count = 1;
        },
        inline .grayscale8Alpha, .grayscale16Alpha => |data| {
            values[0..2].* = .{ data[0].value, data[0].alpha };
            count = 2;
        },
        inline .rgb24, .rgb48 => |data| {
            values[0..3].* = .{ data[0].r, data[0].g, data[0].b };
            count = 3;
        },
        inline .rgba32, .rgba64 => |data| {
            values = .{ data[0].r, data[0].g, data[0].b, data[0].a };
            count = 4;
        },
        else => unreachable,
    }
    try std.testing.expectEqualSlices(u16, expected, values[0..count]);
}

const DecodeCase = struct { depth: usize, maxval: u16, tuple: []const u8 = "", data: []const u8, format: zigimg.PixelFormat, values: []const u16 };
const ErrorCase = struct { bytes: []const u8, err: anyerror, pos: u64 };

pub fn verify() !void {
    var output: [1000]u8 = undefined;
    const cases = [_]DecodeCase{
        .{ .depth = 1, .maxval = 1, .data = &.{1}, .format = .grayscale1, .values = &.{1} },
        .{ .depth = 2, .maxval = 1, .data = &.{ 1, 0 }, .format = .grayscale1, .values = &.{0} },
        .{ .depth = 1, .maxval = 15, .data = &.{7}, .format = .grayscale8, .values = &.{119} },
        .{ .depth = 2, .maxval = 15, .data = &.{ 7, 15 }, .format = .grayscale8Alpha, .values = &.{ 119, 255 } },
        .{ .depth = 3, .maxval = 31, .tuple = "RGB", .data = &.{ 0, 15, 31 }, .format = .rgb24, .values = &.{ 0, 123, 255 } },
        .{ .depth = 4, .maxval = 15, .tuple = "RGB_ALPHA", .data = &.{ 1, 7, 15, 0 }, .format = .rgba32, .values = &.{ 17, 119, 255, 0 } },
        .{ .depth = 1, .maxval = 1000, .data = &.{ 0xf4, 1 }, .format = .grayscale16, .values = &.{32767} },
        .{ .depth = 2, .maxval = 1000, .data = &.{ 1, 0, 0xe8, 3 }, .format = .grayscale16Alpha, .values = &.{ 65, 65535 } },
        .{ .depth = 3, .maxval = 1000, .data = &.{ 0, 0, 0xf4, 1, 0xe8, 3 }, .format = .rgb48, .values = &.{ 0, 32767, 65535 } },
        .{ .depth = 4, .maxval = 65535, .data = &.{ 0x34, 0x12, 0x78, 0x56, 0xbc, 0x9a, 0xf0, 0xde }, .format = .rgba64, .values = &.{ 0x1234, 0x5678, 0x9abc, 0xdef0 } },
    };
    for (cases) |item| {
        var reader = zigimg.io.ReadStream.initMemory(try fixture(&output, 1, 1, item.depth, item.maxval, item.tuple, item.data));
        var image = try PAM.readImage(allocator, &reader);
        defer image.deinit(allocator);
        try std.testing.expectEqual(item.format, image.pixelFormat());
        try expectValues(image.pixels, item.values);
    }
    var reader = zigimg.io.ReadStream.initMemory(try fixture(&output, 4, 1, 2, 1, "BLACKANDWHITE_ALPHA", &.{ 0, 0, 0, 1, 1, 0, 1, 1 }));
    var mono = try PAM.readImage(allocator, &reader);
    defer mono.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 1 }, mono.rawBytes());
    reader = zigimg.io.ReadStream.initMemory("P7\n");
    try std.testing.expect(try PAM.formatDetect(&reader));
    try std.testing.expectEqual(@as(u64, 0), reader.getPos());
    reader = zigimg.io.ReadStream.initMemory("P7 332");
    try std.testing.expect(!try PAM.formatDetect(&reader));
    for ([_][]const u8{ "", "x", "xy" }) |ending| {
        const first = try fixture(&output, 1, 1, 1, 1, "", &.{1});
        const consumed = first.len;
        @memcpy(output[consumed..][0..ending.len], ending);
        reader = zigimg.io.ReadStream.initMemory(output[0 .. consumed + ending.len]);
        var images = try PAM.read(allocator, &reader);
        defer images.deinit(allocator);
        defer for (images.items) |*image| image.deinit(allocator);
        try std.testing.expectEqual(@as(usize, 1), images.items.len);
        try std.testing.expectEqual(@as(u64, consumed), reader.getPos());
    }
    for ([_][]const u8{ "", "x", "xy" }) |short| {
        reader = zigimg.io.ReadStream.initMemory(short);
        try std.testing.expectError(error.InvalidData, PAM.readImage(allocator, &reader));
        try std.testing.expectEqual(@as(u64, 0), reader.getPos());
    }
    const text = "P7\n\n#one\r\n\t \x0b\x0c\nWIDTH 9 ignored\nWIDTH 0__2\nHEIGHT\t1\r\nDEPTH 3\nMAXVAL 3_1\n#two\nENDHDR ignored\n\x00\x0f\x1f\x00\x0f\x1f";
    reader = zigimg.io.ReadStream.initMemory(text);
    var commented = try PAM.readImage(allocator, &reader);
    defer commented.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 2), commented.width);
    try std.testing.expectEqualSlices(u8, &.{ 0, 123, 255, 0, 123, 255 }, commented.rawBytes());

    const first_len = (try fixture(&output, 1, 1, 3, 255, "", &.{ 1, 2, 3 })).len;
    const second_len = (try fixture(output[first_len..], 1, 1, 3, 15, "", &.{ 1, 2, 3 })).len;
    reader = zigimg.io.ReadStream.initMemory(output[0 .. first_len + second_len]);
    var sequence = try PAM.readImage(allocator, &reader);
    defer sequence.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3 }, sequence.rawBytes());
    try std.testing.expectEqual(@as(i32, -1), sequence.animation.loop_count);
    try std.testing.expectEqual(@as(usize, 1), sequence.animation.frames.items.len);
    try std.testing.expectEqual(@as(f32, 0), sequence.animation.frames.items[0].duration);
    try std.testing.expectEqualSlices(u8, &.{ 17, 34, 51 }, sequence.animation.frames.items[0].pixels.asBytes());
    for ([_]DecodeCase{
        .{ .depth = 3, .maxval = 255, .data = &.{ 1, 2, 3, 4, 5, 6 }, .format = .rgb24, .values = &.{} },
        .{ .depth = 1, .maxval = 255, .data = &.{1}, .format = .grayscale8, .values = &.{} },
        .{ .depth = 3, .maxval = 256, .data = &.{ 1, 0, 2, 0, 3, 0 }, .format = .rgb48, .values = &.{} },
    }, 0..) |other, index| {
        const first = (try fixture(&output, 1, 1, 3, 255, "", &.{ 1, 2, 3 })).len;
        const second = (try fixture(output[first..], if (index == 0) 2 else 1, 1, other.depth, other.maxval, "", other.data)).len;
        reader = zigimg.io.ReadStream.initMemory(output[0 .. first + second]);
        try std.testing.expectError(error.Unsupported, PAM.readImage(allocator, &reader));
        try std.testing.expectEqual(@as(u64, first + second), reader.getPos());
    }
    try verifyWriters();
    try verifyErrors();
    try verifyDurations();
}

fn verifyWriters() !void {
    const pixels = [_]zigimg.color.PixelStorage{
        .{ .grayscale1 = @constCast(&[_]zigimg.color.Grayscale1{.{ .value = 1 }}) },
        .{ .grayscale4 = @constCast(&[_]zigimg.color.Grayscale4{.{ .value = 7 }}) },
        .{ .grayscale8 = @constCast(&[_]zigimg.color.Grayscale8{.{ .value = 23 }}) },
        .{ .grayscale16 = @constCast(&[_]zigimg.color.Grayscale16{.{ .value = 0x1234 }}) },
        .{ .grayscale8Alpha = @constCast(&[_]zigimg.color.Grayscale8Alpha{.{ .value = 23, .alpha = 17 }}) },
        .{ .grayscale16Alpha = @constCast(&[_]zigimg.color.Grayscale16Alpha{.{ .value = 0x1234, .alpha = 0x5678 }}) },
        .{ .rgb555 = @constCast(&[_]zigimg.color.Rgb555{.{ .r = 17, .g = 9, .b = 3 }}) },
        .{ .bgr555 = @constCast(&[_]zigimg.color.Bgr555{.{ .r = 17, .g = 9, .b = 3 }}) },
        .{ .rgb24 = @constCast(&[_]zigimg.color.Rgb24{.{ .r = 1, .g = 2, .b = 3 }}) },
        .{ .bgr24 = @constCast(&[_]zigimg.color.Bgr24{.{ .r = 1, .g = 2, .b = 3 }}) },
        .{ .rgba32 = @constCast(&[_]zigimg.color.Rgba32{.{ .r = 1, .g = 2, .b = 3, .a = 4 }}) },
        .{ .bgra32 = @constCast(&[_]zigimg.color.Bgra32{.{ .r = 1, .g = 2, .b = 3, .a = 4 }}) },
        .{ .rgb48 = @constCast(&[_]zigimg.color.Rgb48{.{ .r = 0x1234, .g = 0x5678, .b = 0x9abc }}) },
        .{ .rgba64 = @constCast(&[_]zigimg.color.Rgba64{.{ .r = 0x1234, .g = 0x5678, .b = 0x9abc, .a = 0xdef0 }}) },
    };
    const expected = [_]DecodeCase{
        .{ .depth = 1, .maxval = 1, .tuple = "BLACKANDWHITE", .data = &.{1}, .format = .grayscale1, .values = &.{} },
        .{ .depth = 1, .maxval = 15, .tuple = "GRAYSCALE", .data = &.{7}, .format = .grayscale4, .values = &.{} },
        .{ .depth = 1, .maxval = 255, .tuple = "GRAYSCALE", .data = &.{23}, .format = .grayscale8, .values = &.{} },
        .{ .depth = 1, .maxval = 65535, .tuple = "GRAYSCALE", .data = &.{ 0x34, 0x12 }, .format = .grayscale16, .values = &.{} },
        .{ .depth = 2, .maxval = 255, .tuple = "GRAYSCALE_ALPHA", .data = &.{ 23, 17 }, .format = .grayscale8Alpha, .values = &.{} },
        .{ .depth = 2, .maxval = 65535, .tuple = "GRAYSCALE_ALPHA", .data = &.{ 0x34, 0x12, 0x78, 0x56 }, .format = .grayscale16Alpha, .values = &.{} },
        .{ .depth = 3, .maxval = 31, .tuple = "RGB", .data = &.{ 17, 9, 3 }, .format = .rgb555, .values = &.{} },
        .{ .depth = 3, .maxval = 31, .tuple = "RGB", .data = &.{ 17, 9, 3 }, .format = .bgr555, .values = &.{} },
        .{ .depth = 3, .maxval = 255, .tuple = "RGB", .data = &.{ 1, 2, 3 }, .format = .rgb24, .values = &.{} },
        .{ .depth = 3, .maxval = 255, .tuple = "RGB", .data = &.{ 1, 2, 3 }, .format = .bgr24, .values = &.{} },
        .{ .depth = 4, .maxval = 255, .tuple = "RGB_ALPHA", .data = &.{ 1, 2, 3, 4 }, .format = .rgba32, .values = &.{} },
        .{ .depth = 4, .maxval = 255, .tuple = "RGB_ALPHA", .data = &.{ 1, 2, 3, 4 }, .format = .bgra32, .values = &.{} },
        .{ .depth = 3, .maxval = 65535, .tuple = "RGB", .data = &.{ 0x34, 0x12, 0x78, 0x56, 0xbc, 0x9a }, .format = .rgb48, .values = &.{} },
        .{ .depth = 4, .maxval = 65535, .tuple = "RGB_ALPHA", .data = &.{ 0x34, 0x12, 0x78, 0x56, 0xbc, 0x9a, 0xf0, 0xde }, .format = .rgba64, .values = &.{} },
    };
    var output: [1000]u8 = undefined;
    var expected_output: [1000]u8 = undefined;
    for (pixels, expected) |storage, item| {
        var writer = zigimg.io.WriteStream.initMemory(&output);
        try PAM.writeFrame(&writer.memory, .{ .width = 1, .height = 1, .pixels = storage }, .{ .pam = .{} });
        try std.testing.expectEqualSlices(u8, try fixture(&expected_output, 1, 1, item.depth, item.maxval, item.tuple, item.data), writer.memory.buffered());
    }
    inline for (.{ .invalid, .indexed1, .indexed2, .indexed4, .indexed8, .indexed16, .float32, .rgb332, .rgb565 }) |format| {
        var writer = zigimg.io.WriteStream.initMemory(&output);
        const storage = try zigimg.color.PixelStorage.init(allocator, format, 1);
        defer storage.deinit(allocator);
        try std.testing.expectError(error.Unsupported, PAM.writeFrame(&writer.memory, .{ .width = 1, .height = 1, .pixels = storage }, .{ .pam = .{} }));
        try std.testing.expectEqual(@as(u64, 0), writer.getPos());
    }
    var image = zigimg.ImageUnmanaged{ .width = 1, .height = 1, .pixels = pixels[8], .animation = .{ .loop_count = 7 } };
    // Animation deinit would free these borrowed pixel arrays; release only its list.
    defer image.animation.frames.deinit(allocator);
    try image.animation.frames.append(allocator, .{ .duration = 0.125, .pixels = .{ .rgb24 = @constCast(&[_]zigimg.color.Rgb24{.{ .r = 4, .g = 5, .b = 6 }}) } });
    try image.animation.frames.append(allocator, .{ .duration = 2, .pixels = .{ .grayscale8 = @constCast(&[_]zigimg.color.Grayscale8{.{ .value = 17 }}) } });
    for ([_]bool{ false, true }) |add_duration| {
        var writer = zigimg.io.WriteStream.initMemory(&output);
        try PAM.writeImage(allocator, &writer, image, .{ .pam = .{ .comments = &.{ "note", "" }, .add_duration_as_comment = add_duration } });
        const loop = if (add_duration) "#loop count: 7\n" else "";
        const first = if (add_duration) "#duration: 0.125\n" else "";
        const second = if (add_duration) "#duration: 2\n" else "";
        const text = try std.fmt.bufPrint(&expected_output, "P7\n#note\n#\n{s}WIDTH 1\nHEIGHT 1\nDEPTH 3\nMAXVAL 255\nTUPLTYPE RGB\nENDHDR\n\x01\x02\x03" ++
            "P7\n#note\n#\n{s}WIDTH 1\nHEIGHT 1\nDEPTH 3\nMAXVAL 255\nTUPLTYPE RGB\nENDHDR\n\x04\x05\x06" ++
            "P7\n#note\n#\n{s}WIDTH 1\nHEIGHT 1\nDEPTH 1\nMAXVAL 255\nTUPLTYPE GRAYSCALE\nENDHDR\n\x11", .{ loop, first, second });
        try std.testing.expectEqualSlices(u8, text, writer.memory.buffered());
    }
}

fn verifyErrors() !void {
    const base = "P7\nWIDTH 1\nHEIGHT 1\nDEPTH 1\nMAXVAL 255\n";
    const cases = [_]ErrorCase{
        .{ .bytes = "bad", .err = error.InvalidData, .pos = 3 },
        .{ .bytes = base ++ "ENDHDR", .err = error.EndOfStream, .pos = base.len + 6 },
        .{ .bytes = base ++ "ENDHDR\n", .err = error.EndOfStream, .pos = base.len + 7 },
        .{ .bytes = base ++ "TUPLTYPE GRAYSCALE \n", .err = error.Unsupported, .pos = base.len + 20 },
        .{ .bytes = base ++ "TUPLTYPE GRAYSCALE\r\n", .err = error.Unsupported, .pos = base.len + 20 },
        .{ .bytes = base ++ " #note\n", .err = error.InvalidData, .pos = base.len + 7 },
        .{ .bytes = base ++ "LONGTOKEN 1\n", .err = error.InvalidData, .pos = base.len + 12 },
        .{ .bytes = base ++ "WIDTH +1\n", .err = error.InvalidData, .pos = base.len + 9 },
        .{ .bytes = base ++ "WIDTH -0\n", .err = error.InvalidData, .pos = base.len + 9 },
        .{ .bytes = base ++ "MAXVAL 65536\n", .err = error.InvalidData, .pos = base.len + 13 },
        .{ .bytes = base ++ "MAXVAL 0\nENDHDR\n", .err = error.InvalidData, .pos = base.len + 16 },
        .{ .bytes = base ++ "DEPTH 5\nENDHDR\n", .err = error.Unsupported, .pos = base.len + 15 },
        .{ .bytes = base ++ "TUPLTYPE RGB\nENDHDR\n", .err = error.InvalidData, .pos = base.len + 20 },
        .{ .bytes = "P7\nWIDTH 1\nHEIGHT 1\nDEPTH 1\nMAXVAL 15\nENDHDR\n\x10", .err = error.InvalidData, .pos = 46 },
        .{ .bytes = "P7\nWIDTH 1\nHEIGHT 1\nDEPTH 2\nMAXVAL 1\nENDHDR\n\x00\x02", .err = error.InvalidData, .pos = 46 },
        .{ .bytes = "P7\nWIDTH 1\nHEIGHT 1\nDEPTH 1\nMAXVAL 1000\nENDHDR\n\x01", .err = error.EndOfStream, .pos = 47 },
    };
    for (cases) |item| {
        var reader = zigimg.io.ReadStream.initMemory(item.bytes);
        try std.testing.expectError(item.err, PAM.readImage(allocator, &reader));
        try std.testing.expectEqual(item.pos, reader.getPos());
    }
    var output: [100]u8 = undefined;
    var expected: [100]u8 = undefined;
    const bytes = try fixture(&expected, 1, 1, 1, 65535, "GRAYSCALE", &.{ 0x34, 0x12 });
    const image = zigimg.ImageUnmanaged{ .width = 1, .height = 1, .pixels = .{ .grayscale16 = @constCast(&[_]zigimg.color.Grayscale16{.{ .value = 0x1234 }}) } };
    for ([_]usize{ 0, 1, 5, 68 }) |length| {
        var writer = zigimg.io.WriteStream.initMemory(output[0..length]);
        try std.testing.expectError(error.WriteFailed, PAM.writeImage(allocator, &writer, image, .{ .pam = .{} }));
        try std.testing.expectEqual(@as(u64, length), writer.getPos());
        try std.testing.expectEqualSlices(u8, bytes[0..length], writer.memory.buffered());
    }
}

fn durationHash(hash: *u64, bits: u32) !void {
    var buffer: [128]u8 = undefined;
    const text = try std.fmt.bufPrint(&buffer, "{d}", .{@as(f32, @bitCast(bits))});
    for (text) |byte| hash.* = (hash.* ^ byte) *% 0x100000001b3;
    hash.* = (hash.* ^ '\n') *% 0x100000001b3;
}

fn verifyDurations() !void {
    const words = [_]u32{ 0, 0x80000000, 0x3e000000, 0x40000000, 0x3dcccccd, 1, 0x7f7fffff, 0x7f800000, 0xff800000, 0x7fc00000, 0xffc00000 };
    const expected = [_][]const u8{ "0", "-0", "0.125", "2", "0.1", "0.000000000000000000000000000000000000000000001", "340282350000000000000000000000000000000", "inf", "-inf", "nan", "-nan" };
    var buffer: [128]u8 = undefined;
    for (words, expected) |word, text| try std.testing.expectEqualStrings(text, try std.fmt.bufPrint(&buffer, "{d}", .{@as(f32, @bitCast(word))}));
    var hash: u64 = 0xcbf29ce484222325;
    for (0..256) |exponent| {
        for ([_]u32{ 0, 1, 2, 0x3fffff, 0x400000, 0x7ffffe, 0x7fffff }) |mantissa| {
            const bits = @as(u32, @intCast(exponent)) << 23 | mantissa;
            try durationHash(&hash, bits);
            try durationHash(&hash, bits | 0x80000000);
        }
    }
    var state: u32 = 0x12345678;
    for (0..16384) |_| {
        state = state *% 1664525 +% 1013904223;
        try durationHash(&hash, state);
    }
    try std.testing.expectEqual(@as(u64, 0x721aeceda8f4ab7d), hash);
}
