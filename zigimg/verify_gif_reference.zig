const std = @import("std");
const zigimg = @import("zigimg");
const gif = zigimg.formats.gif;
const allocator = std.heap.page_allocator;

fn concat(parts: []const []const u8) ![]u8 {
    var size: usize = 0;
    for (parts) |part| size += part.len;
    const bytes = try allocator.alloc(u8, size);
    var writer = std.Io.Writer.fixed(bytes);
    for (parts) |part| try writer.writeAll(part);
    return bytes;
}

fn fixture(width: u16, height: u16, flags: u8, background: u8, colors: []const u8, blocks: []const u8) ![]u8 {
    const bytes = try allocator.alloc(u8, 13 + colors.len + blocks.len);
    var writer = std.Io.Writer.fixed(bytes);
    try writer.writeStruct(gif.Header{ .magic = "GIF".*, .version = "89a".*, .width = width, .height = height, .flags = @bitCast(flags), .background_color_index = background, .pixel_aspect_ratio = 77 }, .little);
    try writer.writeAll(colors);
    try writer.writeAll(blocks);
    return bytes;
}

fn imageData(indices: []const u8, initial: u8, block_size: usize) ![]u8 {
    const output = try allocator.alloc(u8, indices.len * 4 + 10);
    var writer = std.Io.Writer.fixed(output);
    var bits = zigimg.io.BitWriter(.little){ .writer = &writer };
    const clear = @as(u16, 1) << @intCast(initial);
    for (indices) |index| {
        try bits.writeBits(clear, initial + 1);
        try bits.writeBits(@as(u16, index), initial + 1);
    }
    try bits.writeBits(clear + 1, initial + 1);
    try bits.flushBits();
    const encoded = writer.buffered();
    const bytes = try allocator.alloc(u8, 2 + encoded.len + (try std.math.divCeil(usize, encoded.len, block_size)));
    var result = std.Io.Writer.fixed(bytes);
    try result.writeByte(initial);
    var offset: usize = 0;
    while (offset < encoded.len) {
        const count = @min(encoded.len - offset, block_size);
        try result.writeByte(@intCast(count));
        try result.writeAll(encoded[offset..][0..count]);
        offset += count;
    }
    try result.writeByte(0);
    return bytes;
}

fn image(width: u16, height: u16, left: u16, top: u16, flags: u8, colors: []const u8, indices: []const u8, initial: u8, block_size: usize) ![]u8 {
    const data = try imageData(indices, initial, block_size);
    const bytes = try allocator.alloc(u8, 10 + colors.len + data.len);
    var writer = std.Io.Writer.fixed(bytes);
    try writer.writeByte(0x2c);
    try writer.writeStruct(gif.ImageDescriptor{ .width = width, .height = height, .left_position = left, .top_position = top, .flags = @bitCast(flags) }, .little);
    try writer.writeAll(colors);
    try writer.writeAll(data);
    return bytes;
}

fn control(flags: u8, delay: u16, transparent: u8) ![]u8 {
    const bytes = try allocator.alloc(u8, 8);
    var writer = std.Io.Writer.fixed(bytes);
    try writer.writeAll(&.{ 0x21, 0xf9, 0, flags });
    try writer.writeInt(u16, delay, .little);
    try writer.writeAll(&.{ transparent, 0xee });
    return bytes;
}

fn application(identifier: []const u8, code: []const u8, count: u16) ![]u8 {
    return concat(&.{ &.{ 0x21, 0xff, 1 }, identifier, code, &.{ 3, 99, @truncate(count), @truncate(count >> 8), 0 } });
}

fn deinitFrames(frames: *zigimg.ImageUnmanaged.Animation.FrameList) void {
    for (frames.items) |frame| frame.deinit(allocator);
    frames.deinit(allocator);
}

pub fn verify() !void {
    try verifyHeaders();
    try verifyGrouping();
    try verifyLayout();
    try verifyDisposal();
    try verifyFormats();
    try verifyExtensions();
    try verifyErrors();
    try verifyFrameCopies();
}

fn verifyHeaders() !void {
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(gif.HeaderFlags));
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(gif.ImageDescriptorFlags));
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(gif.GraphicControlExtensionFlags));
    try std.testing.expectEqual(@as(usize, 4), @sizeOf(gif.GraphicControlExtension));
    try std.testing.expectEqual(@as(usize, 13), @sizeOf(gif.Header));
    try std.testing.expectEqual(@as(usize, 9), @sizeOf(gif.ImageDescriptor));
    const flags: gif.HeaderFlags = @bitCast(@as(u8, 0xed));
    try std.testing.expect(flags.global_color_table_size == 5 and flags.sorted and flags.color_resolution == 6 and flags.use_global_color_table);
    const descriptor: gif.ImageDescriptorFlags = @bitCast(@as(u8, 0xfd));
    try std.testing.expect(descriptor.local_color_table_size == 5 and descriptor.reserved == 3 and descriptor.sort and descriptor.is_interlaced and descriptor.has_local_color_table);
    const gce: gif.GraphicControlExtensionFlags = @bitCast(@as(u8, 0xff));
    try std.testing.expect(gce.has_transparent_color and gce.user_input and @intFromEnum(gce.disposal_method) == 7 and gce.reserved == 7);
    for ([_][]const u8{ "GIF87a", "GIF89a", "GIF90a", "BAD89a" }, 0..) |magic, index| {
        var reader = zigimg.io.ReadStream.initMemory(magic);
        try std.testing.expectEqual(index < 2, try gif.GIF.formatDetect(&reader));
        try std.testing.expectEqual(@as(u64, 0), reader.getPos());
    }
    for ([_]usize{ 0, 3, 5 }) |size| {
        var reader = zigimg.io.ReadStream.initMemory("GIF89a"[0..size]);
        try std.testing.expectError(error.EndOfStream, gif.GIF.formatDetect(&reader));
    }
    var reader = zigimg.io.ReadStream.initMemory(try fixture(2, 2, 0xf8, 1, &.{ 1, 2, 3, 4, 5, 6 }, &.{0x3b}));
    var codec = gif.GIF.init(allocator);
    defer codec.deinit();
    var frames = try codec.read(&reader);
    defer deinitFrames(&frames);
    try std.testing.expect(codec.header.width == 2 and codec.header.height == 2 and codec.header.pixel_aspect_ratio == 77);
    try std.testing.expectEqual(@as(u8, 0xf8), @as(u8, @bitCast(codec.header.flags)));
    try std.testing.expectEqual(@as(usize, 2), codec.global_color_table.data.len);
    try std.testing.expectEqual(@as(usize, 0), codec.frames.items.len);
    try std.testing.expectEqual(@as(usize, 1), frames.items.len);
    try std.testing.expectEqual(zigimg.PixelFormat.indexed1, std.meta.activeTag(frames.items[0].pixels));
    try std.testing.expectEqualSlices(u8, &.{ 1, 1, 1, 1 }, frames.items[0].pixels.asBytes());
    try std.testing.expectEqual(@as(f32, 0), frames.items[0].duration);
    try std.testing.expectEqualDeep(zigimg.color.Rgba32{ .r = 4, .g = 5, .b = 6, .a = 255 }, frames.items[0].pixels.getPalette().?[1]);
    try std.testing.expectEqual(@as(u64, 20), reader.getPos());
    try std.testing.expectEqual(@as(i32, 0), codec.loopCount());
}

fn verifyGrouping() !void {
    const colors = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 };
    for ([_][]const u8{ "", "NETSCAPE", "ANIMEXTS", "UNKNWNID" }) |identifier| {
        const blocks = try concat(&.{ if (identifier.len == 0) "" else try application(identifier, if (std.mem.eql(u8, identifier, "ANIMEXTS")) "1.0" else "2.0", 7), try image(1, 1, 0, 0, 0, "", &.{1}, 2, 1), try image(1, 1, 1, 0, 0, "", &.{2}, 2, 1), &.{0x3b} });
        var reader = zigimg.io.ReadStream.initMemory(try fixture(2, 1, 0x81, 0, &colors, blocks));
        var codec = gif.GIF.init(allocator);
        defer codec.deinit();
        var frames = try codec.read(&reader);
        defer deinitFrames(&frames);
        const animated = std.mem.eql(u8, identifier, "NETSCAPE") or std.mem.eql(u8, identifier, "ANIMEXTS");
        try std.testing.expectEqual(@as(usize, if (animated) 2 else 1), frames.items.len);
        try std.testing.expectEqual(frames.items.len, codec.frames.items.len);
        try std.testing.expectEqual(@as(i32, if (animated) 7 else 0), codec.loopCount());
        try std.testing.expectEqualSlices(u8, &.{ 1, 2 }, frames.items[frames.items.len - 1].pixels.asBytes());
        try std.testing.expectEqualSlices(u8, if (animated) &.{ 1, 0 } else &.{ 1, 2 }, frames.items[0].pixels.asBytes());
        try std.testing.expectEqual(@as(u64, 13 + colors.len + blocks.len), reader.getPos());
    }
    const blocks = try concat(&.{ try application("NETSCAPE", "2.0", 0), try image(2, 1, 0, 0, 0, "", &.{ 1, 0 }, 2, 255), &.{0x3b} });
    var reader = zigimg.io.ReadStream.initMemory(try fixture(2, 1, 0x80, 0, colors[0..6], blocks));
    var decoded = try gif.GIF.readImage(allocator, &reader);
    defer decoded.deinit(allocator);
    try std.testing.expect(decoded.isAnimation());
    try std.testing.expectEqual(zigimg.ImageUnmanaged.AnimationLoopInfinite, decoded.animation.loop_count);
    decoded.pixels.indexed1.indices[0] = 0;
    try std.testing.expectEqual(@as(u1, 0), decoded.animation.frames.items[0].pixels.indexed1.indices[0]);
}

fn verifyLayout() !void {
    const colors = [_]u8{ 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    for ([_]u8{ 0, 0x40 }) |flags| {
        const blocks = try concat(&.{ try image(1, 2, 0, 0, flags, "", &.{ 1, 2 }, 2, 255), &.{0x3b} });
        var reader = zigimg.io.ReadStream.initMemory(try fixture(1, 5, 0x81, 0, &colors, blocks));
        var decoded = try gif.GIF.readImage(allocator, &reader);
        defer decoded.deinit(allocator);
        try std.testing.expectEqualSlices(u8, if (flags == 0) &.{ 1, 2, 0, 0, 0 } else &.{ 1, 0, 0, 0, 2 }, decoded.rawBytes());
    }
    const blocks = try concat(&.{ try image(3, 1, 0, 0, 0, "", &.{ 1, 2, 3 }, 2, 255), &.{0x3b} });
    var reader = zigimg.io.ReadStream.initMemory(try fixture(2, 2, 0x81, 0, &colors, blocks));
    var decoded = try gif.GIF.readImage(allocator, &reader);
    defer decoded.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 0 }, decoded.rawBytes());
    reader = zigimg.io.ReadStream.initMemory(try fixture(1, 1, 0x80, 0, colors[0..6], try concat(&.{ try image(1, 1, 0, 0, 0, "", &.{3}, 2, 255), &.{0x3b} })));
    var truncated = try gif.GIF.readImage(allocator, &reader);
    defer truncated.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{1}, truncated.rawBytes());
}

fn verifyDisposal() !void {
    const colors = [_]u8{ 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    for ([_]u8{ 0, 1, 2, 3, 7 }) |dispose| {
        const blocks = try concat(&.{ try control(dispose << 2, 37, 99), try image(1, 1, 1, 0, 0, "", &.{1}, 2, 255), try control(1, 25, 0), try image(2, 1, 0, 0, 0, "", &.{ 1, 0 }, 2, 255), &.{0x3b} });
        var reader = zigimg.io.ReadStream.initMemory(try fixture(3, 1, 0x81, 0, &colors, blocks));
        var decoded = try gif.GIF.readImage(allocator, &reader);
        defer decoded.deinit(allocator);
        const frames = decoded.animation.frames.items;
        try std.testing.expectEqual(@as(usize, 2), frames.len);
        try std.testing.expectEqual(zigimg.PixelFormat.indexed2, decoded.pixelFormat());
        try std.testing.expectEqualSlices(u8, &.{ 0, 1, 0 }, frames[0].pixels.asBytes());
        try std.testing.expectEqualSlices(u8, &.{ 1, if (dispose == 2 or dispose == 3) 0 else @as(u8, 1), 0 }, frames[1].pixels.asBytes());
        try std.testing.expectEqual(@as(f32, 37) * @as(f32, 0.01), frames[0].duration);
        try std.testing.expectEqual(@as(f32, 0.25), frames[1].duration);
        try std.testing.expectEqual(@as(u8, 255), frames[1].pixels.getPalette().?[0].a);
    }
    const blocks = try concat(&.{ try image(1, 1, 0, 0, 0, "", &.{1}, 2, 255), try control(0, 10, 0), try image(1, 1, 1, 0, 0, "", &.{2}, 2, 255), &.{0x3b} });
    var reader = zigimg.io.ReadStream.initMemory(try fixture(3, 1, 0x81, 0, &colors, blocks));
    var codec = gif.GIF.init(allocator);
    defer codec.deinit();
    var frames = try codec.read(&reader);
    defer deinitFrames(&frames);
    try std.testing.expectEqual(@as(usize, 2), codec.frames.items.len);
    try std.testing.expectEqual(@as(usize, 1), frames.items.len);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 0 }, frames.items[0].pixels.asBytes());
    try std.testing.expectEqual(@as(f32, 10) * @as(f32, 0.01), frames.items[0].duration);
}

fn verifyFormats() !void {
    for (0..8) |size| {
        const count = @as(usize, 1) << @intCast(size + 1);
        const colors = try allocator.alloc(u8, count * 3);
        @memset(colors, 0);
        @memcpy(colors[3..6], &[_]u8{ 11, 22, 33 });
        const blocks = try concat(&.{ try image(1, 1, 0, 0, 0, "", &.{1}, 2, 255), &.{0x3b} });
        var reader = zigimg.io.ReadStream.initMemory(try fixture(1, 1, 0x80 | @as(u8, @intCast(size)), 0, colors, blocks));
        var decoded = try gif.GIF.readImage(allocator, &reader);
        defer decoded.deinit(allocator);
        const format: zigimg.PixelFormat = if (size == 0) .indexed1 else if (size == 1) .indexed2 else if (size < 4) .indexed4 else .indexed8;
        try std.testing.expectEqual(format, decoded.pixelFormat());
        try std.testing.expectEqualSlices(u8, &.{1}, decoded.rawBytes());
        try std.testing.expectEqualDeep(zigimg.color.Rgba32{ .r = 11, .g = 22, .b = 33, .a = 255 }, decoded.pixels.getPalette().?[1]);
    }
    var global_colors = [_]u8{0} ** 768;
    @memcpy(global_colors[6..9], &[_]u8{ 10, 20, 30 });
    const local = [_]u8{ 4, 5, 6, 7, 8, 9 };
    for ([_]bool{ false, true }) |transparent| {
        const blocks = try concat(&.{ if (transparent) try control(1, 100, 1) else "", try image(2, 1, 0, 0, 0x80, &local, &.{ 0, 1 }, 2, 255), &.{0x3b} });
        var reader = zigimg.io.ReadStream.initMemory(try fixture(2, 1, 0x87, 2, &global_colors, blocks));
        var decoded = try gif.GIF.readImage(allocator, &reader);
        defer decoded.deinit(allocator);
        try std.testing.expectEqual(if (transparent) zigimg.PixelFormat.rgba32 else .rgb24, decoded.pixelFormat());
        try std.testing.expectEqualSlices(u8, if (transparent) &.{ 4, 5, 6, 255, 0, 10, 20, 30 } else &.{ 4, 5, 6, 7, 8, 9 }, decoded.rawBytes());
    }
    const blocks = try concat(&.{ try image(1, 1, 0, 0, 0x80, &local, &.{1}, 2, 255), &.{0x3b} });
    var reader = zigimg.io.ReadStream.initMemory(try fixture(1, 1, 0, 0, "", blocks));
    var decoded = try gif.GIF.readImage(allocator, &reader);
    defer decoded.deinit(allocator);
    try std.testing.expectEqual(zigimg.PixelFormat.indexed1, decoded.pixelFormat());
    try std.testing.expectEqualDeep(zigimg.color.Rgba32{ .r = 7, .g = 8, .b = 9, .a = 255 }, decoded.pixels.getPalette().?[1]);
}

fn verifyExtensions() !void {
    const blocks = try concat(&.{ &.{ 0x21, 0xfe, 2, 'a', 0, 1, 'b', 0 }, try application("UNKNWNID", "abc", 42), &.{ 0x21, 0xee, 2, 'x', 'y', 0, 0x21, 1, 0, 254 }, &([1]u8{'A'} ** 254), &.{ 0, 0x3b } });
    var reader = zigimg.io.ReadStream.initMemory(try fixture(1, 1, 0x80, 0, &.{ 1, 2, 3, 4, 5, 6 }, blocks));
    var codec = gif.GIF.init(allocator);
    defer codec.deinit();
    var frames = try codec.read(&reader);
    defer deinitFrames(&frames);
    try std.testing.expectEqual(@as(usize, 1), frames.items.len);
    try std.testing.expectEqual(@as(usize, 1), codec.comments.items.len);
    try std.testing.expectEqualSlices(u8, &.{ 'a', 0, 'b' }, codec.comments.items[0].comment);
    try std.testing.expectEqual(@as(usize, 1), codec.application_infos.items.len);
    try std.testing.expectEqualStrings("UNKNWNID", &codec.application_infos.items[0].application_identifier);
    try std.testing.expectEqualStrings("abc", &codec.application_infos.items[0].authentification_code);
    try std.testing.expectEqualSlices(u8, &.{ 99, 42, 0 }, codec.application_infos.items[0].data);
    try std.testing.expectEqual(@as(i32, 0), codec.loopCount());
    try std.testing.expectEqual(@as(u64, 19 + blocks.len), reader.getPos());
}

fn verifyErrors() !void {
    const full = try fixture(1, 1, 0x80, 0, &.{ 1, 2, 3, 4, 5, 6 }, &.{0x3b});
    for ([_]usize{ 0, 6, 12, 13, 17, 19 }) |size| {
        var reader = zigimg.io.ReadStream.initMemory(full[0..size]);
        var codec = gif.GIF.init(allocator);
        defer codec.deinit();
        try std.testing.expectError(if (size == 19) error.InvalidData else error.EndOfStream, codec.read(&reader));
        try std.testing.expectEqual(@as(u64, if (size < 13) 0 else if (size < 16) 13 else if (size < 19) 16 else 19), reader.getPos());
    }
    full[0] = 'X';
    var reader = zigimg.io.ReadStream.initMemory(full);
    var codec = gif.GIF.init(allocator);
    defer codec.deinit();
    try std.testing.expectError(error.InvalidData, codec.read(&reader));
    try std.testing.expectEqual(@as(u64, 13), reader.getPos());
    try std.testing.expectEqual(@as(usize, 0), codec.global_color_table.data.len);
    full[0] = 'G';
    for ([_][]const u8{ "\x00", "\x21\xee\x02A", "\x21\xfe\x04AB" }, [_]u64{ 20, 23, 24 }) |suffix, position| {
        reader = zigimg.io.ReadStream.initMemory(try concat(&.{ full[0..19], suffix }));
        var failed = gif.GIF.init(allocator);
        defer failed.deinit();
        try std.testing.expectError(if (suffix.len == 1) error.InvalidData else error.EndOfStream, failed.read(&reader));
        try std.testing.expectEqual(position, reader.getPos());
        if (suffix.len == 5) try std.testing.expectEqual(@as(usize, 1), failed.comments.items.len);
    }
    const blocks = [_]u8{ 0x2c, 0, 0, 0, 0, 0, 0, 1, 0, 0x80, 0x3b };
    reader = zigimg.io.ReadStream.initMemory(try fixture(1, 1, 0x80, 1, &.{ 1, 2, 3, 4, 5, 6 }, &blocks));
    var zero_width = gif.GIF.init(allocator);
    defer zero_width.deinit();
    var frames = try zero_width.read(&reader);
    defer deinitFrames(&frames);
    try std.testing.expectEqual(@as(usize, 1), frames.items.len);
    try std.testing.expectEqual(@as(usize, 0), zero_width.frames.items[0].sub_images.items[0].pixels.len);
    try std.testing.expectEqual(@as(usize, 0), zero_width.frames.items[0].sub_images.items[0].local_color_table.data.len);
    try std.testing.expectEqualSlices(u8, &.{1}, frames.items[0].pixels.asBytes());
    const excess = try concat(&.{ try image(1, 1, 0, 0, 0, "", &.{ 1, 2, 3 }, 2, 255), &.{0x3b} });
    reader = zigimg.io.ReadStream.initMemory(try fixture(1, 1, 0x81, 0, &.{ 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 }, excess));
    var decoded = try gif.GIF.readImage(allocator, &reader);
    defer decoded.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{1}, decoded.rawBytes());
    try std.testing.expectEqual(@as(u64, 25 + excess.len), reader.getPos());
    var output: [0]u8 = undefined;
    var writer = zigimg.io.WriteStream.initMemory(&output);
    try gif.GIF.writeImage(allocator, &writer, .{ .width = 99, .height = 1 }, .{ .gif = {} });
    try std.testing.expectEqual(@as(u64, 0), writer.getPos());
}

fn verifyFrameCopies() !void {
    const first = [_]u8{ 1, 2, 3, 4, 5, 6 };
    const last = [_]u8{ 7, 8, 9, 10, 11, 12 };
    const blocks = try concat(&.{ try image(1, 1, 0, 0, 0x80, &first, &.{1}, 2, 255), try image(1, 1, 1, 0, 0x80, &last, &.{0}, 2, 255), &.{0x3b} });
    var reader = zigimg.io.ReadStream.initMemory(try fixture(2, 1, 0, 0, "", blocks));
    var codec = gif.GIF.init(allocator);
    defer codec.deinit();
    var frames = try codec.read(&reader);
    defer deinitFrames(&frames);
    try std.testing.expectEqual(@as(usize, 1), frames.items.len);
    try std.testing.expectEqual(zigimg.PixelFormat.indexed2, std.meta.activeTag(frames.items[0].pixels));
    try std.testing.expectEqualSlices(u8, &.{ 1, 0 }, frames.items[0].pixels.asBytes());
    try std.testing.expectEqualDeep(zigimg.color.Rgba32{ .r = 10, .g = 11, .b = 12, .a = 255 }, frames.items[0].pixels.getPalette().?[1]);
    codec.frames.items[0].sub_images.items[0].pixels[0] = 0;
    try std.testing.expectEqual(@as(u8, 1), frames.items[0].pixels.asBytes()[0]);
    var colors = [_]u8{0} ** 768;
    @memcpy(colors[6..9], &[_]u8{ 10, 20, 30 });
    const restore = try concat(&.{ try control(9, 20, 1), try image(2, 1, 0, 0, 0x80, &last, &.{ 0, 1 }, 2, 255), try control(1, 30, 1), try image(2, 1, 0, 0, 0x80, &last, &.{ 1, 1 }, 2, 255), &.{0x3b} });
    reader = zigimg.io.ReadStream.initMemory(try fixture(2, 1, 0x87, 2, &colors, restore));
    var decoded = try gif.GIF.readImage(allocator, &reader);
    defer decoded.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &.{ 7, 8, 9, 255, 0, 10, 20, 30 }, decoded.animation.frames.items[0].pixels.asBytes());
    try std.testing.expectEqualSlices(u8, &.{ 10, 11, 12, 255, 10, 11, 12, 255 }, decoded.animation.frames.items[1].pixels.asBytes());
    const global_colors = [_]u8{ 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    const previous = try concat(&.{ try control(4, 0, 0), try image(1, 1, 1, 0, 0, "", &.{1}, 2, 255), try control(12, 0, 0), try image(1, 1, 0, 0, 0, "", &.{2}, 2, 255), try control(0, 0, 0), try image(1, 1, 2, 0, 0, "", &.{1}, 2, 255), &.{0x3b} });
    reader = zigimg.io.ReadStream.initMemory(try fixture(3, 1, 0x81, 0, &global_colors, previous));
    var restored = try gif.GIF.readImage(allocator, &reader);
    defer restored.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 3), restored.animation.frames.items.len);
    try std.testing.expectEqualSlices(u8, &.{ 0, 1, 0 }, restored.animation.frames.items[0].pixels.asBytes());
    try std.testing.expectEqualSlices(u8, &.{ 2, 1, 0 }, restored.animation.frames.items[1].pixels.asBytes());
    try std.testing.expectEqualSlices(u8, &.{ 0, 1, 1 }, restored.animation.frames.items[2].pixels.asBytes());
}
