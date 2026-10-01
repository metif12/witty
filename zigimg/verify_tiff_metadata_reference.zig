const std = @import("std");
const types = @import("src/formats/tiff/types.zig");
const TIFF = @import("src/formats/tiff.zig").TIFF;
const io = @import("src/io.zig");
const PixelFormat = @import("src/pixel_format.zig").PixelFormat;
const allocator = std.heap.page_allocator;
const keys = std.meta.tags(types.TagId);

fn mix(hash: *u64, value: u64) void {
    hash.* = (hash.* ^ value) *% 1099511628211;
}

fn append(bytes: *std.ArrayList(u8), value: u32, size: usize, endianess: std.builtin.Endian) !void {
    for (0..size) |index| {
        const shift: u5 = @intCast((if (endianess == .big) size - index - 1 else index) * 8);
        try bytes.append(allocator, @truncate(value >> shift));
    }
}

fn verifyFields() !void {
    try std.testing.expectEqual(@as(usize, 6), @sizeOf(types.Header));
    try std.testing.expectEqual(@as(usize, 12), @sizeOf(types.PackedTag));
    try std.testing.expectEqual(@as(usize, 10), @sizeOf(types.TagField));
    for ([_]std.builtin.Endian{ .big, .little }) |endianess| {
        const tag = types.TagField{ .data_type = 3, .data_count = 1, .data_offset = 0x12345678 };
        try std.testing.expectEqual(@as(u32, 0x12345678), tag.toLong());
        try std.testing.expectEqual(@as(u16, if (endianess == .big) 0x1234 else 0x5678), tag.toShort(endianess));
        try std.testing.expectEqual(@as(u32, tag.toShort(endianess)), tag.toLongOrShort(endianess));
        var empty = io.ReadStream.initMemory(&.{});
        const inline_data = try tag.readTagData(allocator, &empty, endianess);
        defer allocator.free(inline_data);
        try std.testing.expectEqualSlices(u32, &.{0x12345678}, inline_data);
        try std.testing.expectEqual(@as(u64, 0), empty.getPos());
        var bytes: std.ArrayList(u8) = .{};
        defer bytes.deinit(allocator);
        try bytes.append(allocator, 0);
        try append(&bytes, 0x12345678, 4, endianess);
        try append(&bytes, 0x87654321, 4, endianess);
        var stream = io.ReadStream.initMemory(bytes.items);
        const rational = try (types.TagField{ .data_type = 5, .data_count = 1, .data_offset = 1 }).readRational(&stream, endianess);
        try std.testing.expectEqual([_]u32{ 0x12345678, 0x87654321 }, rational);
        try std.testing.expectEqual(@as(u64, 9), stream.getPos());
        for ([_]u16{ 3, 4 }) |data_type| {
            bytes.clearRetainingCapacity();
            try bytes.append(allocator, 0);
            const stride: usize = if (data_type == 3) 2 else 4;
            for ([_]u32{ 0x1234, 0x5678, 0x9abc }) |value| try append(&bytes, value, stride, endianess);
            stream = io.ReadStream.initMemory(bytes.items);
            const array_tag = types.TagField{ .data_type = data_type, .data_count = 3, .data_offset = 1 };
            const values = try array_tag.readTagData(allocator, &stream, endianess);
            defer allocator.free(values);
            try std.testing.expectEqualSlices(u32, &.{ 0x1234, 0x5678, 0x9abc }, values);
            try std.testing.expectEqual(@as(u64, 1 + stride * 3), stream.getPos());
        }
        stream = io.ReadStream.initMemory(&.{0});
        const zero = try (types.TagField{ .data_type = 5, .data_count = 0, .data_offset = 0 }).readTagData(allocator, &stream, endianess);
        defer allocator.free(zero);
        try std.testing.expectEqual(@as(usize, 0), zero.len);
        try std.testing.expectEqual(@as(u64, 0), stream.getPos());
        bytes.clearRetainingCapacity();
        try bytes.append(allocator, 0);
        try append(&bytes, 0x1234, 2, endianess);
        try bytes.append(allocator, 0xab);
        stream = io.ReadStream.initMemory(bytes.items);
        const partial = try (types.TagField{ .data_type = 3, .data_count = 3, .data_offset = 1 }).readTagData(allocator, &stream, endianess);
        defer allocator.free(partial);
        try std.testing.expectEqual(@as(usize, 3), partial.len);
        try std.testing.expectEqual(@as(u32, 0x1234), partial[0]);
        try std.testing.expectEqual(@as(u64, 4), stream.getPos());
    }
}

fn verifyMap() !void {
    var hash: u64 = 14695981039346656037;
    for (0..32) |seed| {
        var map = std.AutoHashMap(types.TagId, types.TagField).init(allocator);
        defer map.deinit();
        for (0..96) |iteration| {
            const key = keys[(iteration * 13 + seed * 7) % keys.len];
            try map.put(key, .{ .data_type = 0, .data_count = 0, .data_offset = @intCast(iteration + seed * 100) });
            mix(&hash, map.capacity());
            mix(&hash, map.count());
            var iterator = map.keyIterator();
            while (iterator.next()) |item| {
                mix(&hash, @intFromEnum(item.*));
                mix(&hash, map.get(item.*).?.data_offset);
            }
        }
    }
    std.debug.print("TIFF tag map: 3072 insertions, {x:0>16}\n", .{hash});
    try std.testing.expectEqual(@as(u64, 0x219bfd777d44f15d), hash);
}

fn verifyIFD() !void {
    for ([_]std.builtin.Endian{ .big, .little }) |endianess| {
        var bytes: std.ArrayList(u8) = .{};
        defer bytes.deinit(allocator);
        try bytes.append(allocator, 0);
        try append(&bytes, 3, 2, endianess);
        for (0..3) |i| {
            try append(&bytes, @intFromEnum(types.TagId.image_width), 2, endianess);
            try append(&bytes, 3, 2, endianess);
            try append(&bytes, 1, 4, endianess);
            try append(&bytes, @as(u32, @intCast(i + 1)) << @as(u5, if (endianess == .big) 16 else 0), 4, endianess);
        }
        try append(&bytes, 0x12345678, 4, endianess);
        for (0..bytes.items.len + 1) |length| {
            var stream = io.ReadStream.initMemory(bytes.items[0..length]);
            var directory = try types.IFD.init(allocator, &stream, 1);
            defer directory.deinit();
            directory.readTags(endianess) catch |err| {
                try std.testing.expectEqual(@as(u16, 0), directory.num_tag_entries);
                try std.testing.expectEqual(@as(u32, 0), directory.tags_map.count());
                const position: u64 = if (length <= 1) 0 else if (length < 3) 1 else if (length < 39) length else 39;
                try std.testing.expectEqual(position, stream.getPos());
                try std.testing.expectEqual(if (length <= 1) error.Unseekable else error.EndOfStream, err);
                continue;
            };
            try std.testing.expectEqual(bytes.items.len, length);
            try std.testing.expectEqual(@as(u64, bytes.items.len), stream.getPos());
            try std.testing.expectEqual(@as(u16, 3), directory.num_tag_entries);
            try std.testing.expectEqual(@as(u32, 0x12345678), directory.next_ifd_offset);
            try std.testing.expectEqual(@as(u32, 1), directory.tags_map.count());
            try std.testing.expectEqual(@as(u16, 3), directory.tags_map.get(.image_width).?.toShort(endianess));
        }
    }
}

fn verifyBitmaps() !void {
    var hash: u64 = 14695981039346656037;
    var cases: usize = 0;
    for (std.meta.tags(types.CompressionType)) |compression| {
        for (0..6) |photo| {
            for (1..9) |count| {
                for ([_]u16{ 1, 4, 8, 16, 255 }) |bits| {
                    for (0..4) |extra| {
                        for (0..4) |flags| {
                            var codec = TIFF{ .bitmap = .{} };
                            codec.bitmap.compression = compression;
                            codec.bitmap.photometric_interpretation = @intCast(photo);
                            codec.bitmap.fill_order = @intCast(1 + (flags & 1));
                            codec.bitmap.predictor = @intCast(1 + (flags >> 1));
                            codec.bitmap.bits_per_sample.resize(count);
                            @memset(codec.bitmap.bits_per_sample.data, bits);
                            codec.bitmap.extra_samples.resize(1);
                            codec.bitmap.extra_samples.data[0] = @intCast(extra);
                            const format = codec.bitmap.guessPixelFormat() catch |err| blk: {
                                try std.testing.expectEqual(error.Unsupported, err);
                                break :blk PixelFormat.invalid;
                            };
                            for ([_]u64{ @intFromEnum(compression), photo, count, bits, extra, flags, @intFromEnum(format) }) |value| mix(&hash, value);
                            cases += 1;
                            for ([_]u32{ 0, 1, 7, 8, 17, 65535 }) |width| {
                                codec.bitmap.image_width = width;
                                codec.bitmap.samples_per_pixel = @intCast(count);
                                const row = codec.calRowByteSize() catch |err| blk: {
                                    try std.testing.expectEqual(error.Unsupported, err);
                                    break :blk std.math.maxInt(usize);
                                };
                                mix(&hash, row);
                                try std.testing.expectEqual(@as(usize, width), codec.width());
                            }
                        }
                    }
                }
            }
        }
    }
    std.debug.print("TIFF bitmap matrix: {d} cases, {x:0>16}\n", .{ cases, hash });
    try std.testing.expectEqual(@as(usize, 38400), cases);
    try std.testing.expectEqual(@as(u64, 0x31cf888a600f81f5), hash);
}

pub fn main() !void {
    try verifyFields();
    try verifyMap();
    try verifyIFD();
    try verifyBitmaps();
    try verifyMetadata();
    try verifyComponents();
    std.debug.print("PASS: unchanged TIFF packed fields, IFD parsing, tag iteration, and bitmap selection\n", .{});
}

fn verifyComponents() !void {
    for ([_]std.builtin.Endian{ .big, .little }) |endianess| {
        for ([_]usize{ 3, 4 }) |count| {
            var bytes: std.ArrayList(u8) = .{};
            defer bytes.deinit(allocator);
            try bytes.append(allocator, 0);
            for (0..count) |i| try append(&bytes, (@as(u32, @intCast(i + 1)) << 16) | 8, 4, endianess);
            var stream = io.ReadStream.initMemory(bytes.items);
            var codec = TIFF{ .endianess = endianess, .bitmap = .{}, .ifd = try types.IFD.init(allocator, &stream, 0) };
            defer codec.ifd.deinit();
            codec.bitmap.photometric_interpretation = 2;
            codec.bitmap.image_width = 7;
            try codec.ifd.tags_map.put(.bits_per_sample, .{ .data_type = 4, .data_count = @intCast(count), .data_offset = 1 });
            if (count == 4) try codec.ifd.tags_map.put(.extra_samples, .{ .data_type = 3, .data_count = 1, .data_offset = if (endianess == .big) 2 << 16 else 2 });
            try codec.decodeBitmap(allocator, &stream);
            try std.testing.expectEqual(count, codec.bitmap.bits_per_sample.data.len);
            for (codec.bitmap.bits_per_sample.data) |bits| try std.testing.expectEqual(@as(u16, 8), bits);
            try std.testing.expectEqual(@as(u16, 1), codec.bitmap.samples_per_pixel);
            try std.testing.expectEqual(if (count == 3) PixelFormat.rgb24 else PixelFormat.rgba32, try codec.bitmap.guessPixelFormat());
            try std.testing.expectEqual(@as(usize, 7), try codec.calRowByteSize());
            try std.testing.expectEqual(@as(u64, bytes.items.len), stream.getPos());
        }
        for ([_]types.TagId{ .bits_per_sample, .extra_samples }) |key| {
            var stream = io.ReadStream.initMemory(&.{});
            var codec = TIFF{ .endianess = endianess, .bitmap = .{}, .ifd = try types.IFD.init(allocator, &stream, 0) };
            defer codec.ifd.deinit();
            try codec.ifd.tags_map.put(key, .{ .data_type = 3, .data_count = 2, .data_offset = 0 });
            try std.testing.expectError(error.Unsupported, codec.decodeBitmap(allocator, &stream));
            try std.testing.expectEqual(@as(u64, 0), stream.getPos());
            try std.testing.expectEqual(@as(usize, 2), if (key == .bits_per_sample) codec.bitmap.bits_per_sample.data.len else codec.bitmap.extra_samples.data.len);
        }
    }
}

fn metadataTag(key: types.TagId, endianess: std.builtin.Endian) types.TagField {
    const value: u32 = switch (key) {
        .image_width => 7,
        .image_height => 9,
        .compression, .samples_per_pixel => 1,
        .bits_per_sample => 8,
        .photometric_interpretation, .predictor, .rows_per_strip => 3,
        .strip_offsets => 10,
        .strip_byte_counts => 88,
        .new_subfile_type => 42,
        else => 2,
    };
    if (key == .color_map) return .{ .data_type = 3, .data_count = 768, .data_offset = 1 };
    if (key == .x_resolution or key == .y_resolution) return .{ .data_type = 5, .data_count = 1, .data_offset = 1537 };
    return .{
        .data_type = if (key == .image_width or key == .image_height) 4 else 3,
        .data_count = 1,
        .data_offset = if (endianess == .big and key != .image_width and key != .image_height) value << 16 else value,
    };
}

fn verifyMetadata() !void {
    var hash: u64 = 14695981039346656037;
    var counts: [257]usize = @splat(0);
    for ([_]std.builtin.Endian{ .big, .little }) |endianess| {
        var bytes: std.ArrayList(u8) = .{};
        defer bytes.deinit(allocator);
        try bytes.append(allocator, 0);
        for (0..768) |i| try append(&bytes, @intCast((i * 251 + 17) & 65535), 2, endianess);
        try append(&bytes, 10, 4, endianess);
        try append(&bytes, 2, 4, endianess);
        for (0..32) |seed| {
            for (0..33) |count| {
                for ([_]u32{ 0, 200 }) |reservation| {
                    var stream = io.ReadStream.initMemory(bytes.items);
                    var codec = TIFF{ .endianess = endianess, .bitmap = .{}, .ifd = try types.IFD.init(allocator, &stream, 0) };
                    defer codec.ifd.deinit();
                    defer codec.bitmap.deinit(allocator);
                    try codec.ifd.tags_map.ensureTotalCapacity(reservation);
                    for ([_]types.TagId{ .bits_per_sample, .color_map, .photometric_interpretation }) |key| try codec.ifd.tags_map.put(key, metadataTag(key, endianess));
                    for (0..count) |i| {
                        const key = keys[(i * 13 + seed * 7) % keys.len];
                        try codec.ifd.tags_map.put(key, metadataTag(key, endianess));
                    }
                    try codec.decodeBitmap(allocator, &stream);
                    const bitmap = &codec.bitmap;
                    for ([_]u64{ @intFromEnum(endianess), seed, count, reservation, stream.getPos(), @intFromEnum(bitmap.compression), bitmap.image_width, bitmap.image_height, bitmap.photometric_interpretation, bitmap.rows_per_strip, @intFromEnum(bitmap.resolution_unit), bitmap.new_subfile_type, bitmap.samples_per_pixel, bitmap.fill_order, bitmap.planar_configuration, bitmap.predictor }) |value| mix(&hash, value);
                    for ([_][]const u16{ bitmap.bits_per_sample.data, bitmap.extra_samples.data }) |values| {
                        mix(&hash, values.len);
                        for (values) |value| mix(&hash, value);
                    }
                    for ([_]?[]const u32{ bitmap.strip_offsets, bitmap.strip_byte_counts }) |optional| {
                        const values = optional orelse {
                            mix(&hash, std.math.maxInt(u64));
                            continue;
                        };
                        mix(&hash, values.len);
                        for (values) |value| mix(&hash, value);
                    }
                    for ([_]u32{ bitmap.x_resolution[0], bitmap.x_resolution[1], bitmap.y_resolution[0], bitmap.y_resolution[1] }) |value| mix(&hash, value);
                    mix(&hash, bitmap.color_map.data.len);
                    try std.testing.expect(bitmap.color_map.data.len == 2 or bitmap.color_map.data.len == 256);
                    counts[bitmap.color_map.data.len] += 1;
                    for (bitmap.color_map.data) |entry| {
                        for ([_]u8{ entry.r, entry.g, entry.b, entry.a }) |byte| mix(&hash, byte);
                    }
                    try std.testing.expectEqual(PixelFormat.indexed8, try bitmap.guessPixelFormat());
                }
            }
        }
    }
    std.debug.print("TIFF metadata matrix: 4224 cases, {x:0>16}, palettes {d}/{d}\n", .{ hash, counts[2], counts[256] });
    try std.testing.expect(counts[2] > 0 and counts[256] > 0);
    try std.testing.expectEqual(@as(u64, 0xe34da5c38c1d06cd), hash);
}
