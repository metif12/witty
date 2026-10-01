const std = @import("std");
const png = @import("src/formats/png/types.zig");
const reader = @import("src/formats/png/reader.zig");
const filtering = @import("src/formats/png/filtering.zig");
const color = @import("src/color.zig");
const PixelFormat = @import("src/pixel_format.zig").PixelFormat;
const io = @import("src/io.zig");
const allocator = std.heap.page_allocator;

fn mix(hash: *u64, value: u64) void {
    hash.* = (hash.* ^ value) *% 1099511628211;
}
fn bytesHash(hash: *u64, bytes: []const u8) void {
    for (bytes) |byte| mix(hash, byte);
}

fn append32(bytes: *std.ArrayList(u8), value: u32) !void {
    var data: [4]u8 = undefined;
    std.mem.writeInt(u32, &data, value, .big);
    try bytes.appendSlice(allocator, &data);
}
fn headerBytes() ![]u8 {
    var bytes: std.ArrayList(u8) = .{};
    try bytes.appendSlice(allocator, png.magic_header);
    try append32(&bytes, 13);
    try bytes.appendSlice(allocator, "IHDR");
    try append32(&bytes, 17);
    try append32(&bytes, 3);
    try bytes.appendSlice(allocator, &.{ 8, 6, 0, 0, 0 });
    try append32(&bytes, std.hash.Crc32.hash(bytes.items[12..29]));
    return bytes.toOwnedSlice(allocator);
}
fn headerHash(hash: *u64, bytes: []const u8) !void {
    var stream = io.ReadStream.initMemory(bytes);
    if (reader.loadHeader(&stream)) |header| {
        mix(hash, 0);
        for ([_]u64{ header.width, header.height, header.bit_depth, @intFromEnum(header.color_type), @intFromEnum(header.compression_method), @intFromEnum(header.filter_method), @intFromEnum(header.interlace_method) }) |value| mix(hash, value);
    } else |err| mix(hash, if (err == error.InvalidData) 1 else if (err == error.EndOfStream) 2 else 3);
    mix(hash, stream.getPos());
}
fn verifyHeaders() !void {
    const base = try headerBytes();
    defer allocator.free(base);
    var hash: u64 = 14695981039346656037;
    for (0..34) |cut| try headerHash(&hash, base[0..cut]);
    for (0..33) |position| for (0..256) |value| {
        const bytes = try allocator.dupe(u8, base);
        defer allocator.free(bytes);
        bytes[position] = @intCast(value);
        if (position >= 16 and position < 29) std.mem.writeInt(u32, bytes[29..33], std.hash.Crc32.hash(bytes[12..29]), .big);
        try headerHash(&hash, bytes);
    };
    std.debug.print("PNG headers: 8482 cases, {x:0>16}\n", .{hash});
    try std.testing.expectEqual(@as(u64, 0x8cb5945cdde99fe7), hash);
}

const formats = [_]PixelFormat{ .indexed1, .indexed2, .indexed4, .indexed8, .grayscale1, .grayscale2, .grayscale4, .grayscale8, .grayscale16, .grayscale8Alpha, .grayscale16Alpha, .rgb24, .rgb48, .rgba32, .rgba64 };
fn headerFor(format: PixelFormat, width: u32, height: u32) !png.HeaderData {
    return .{ .width = width, .height = height, .bit_depth = format.bitsPerChannel(), .color_type = try png.ColorType.fromPixelFormat(format), .compression_method = .deflate, .filter_method = .adaptive, .interlace_method = .none };
}
fn pixelsFor(format: PixelFormat, count: usize, seed: usize) !color.PixelStorage {
    const pixels = try color.PixelStorage.init(allocator, format, count);
    const bytes = pixels.asBytes();
    const depth = format.bitsPerChannel();
    for (bytes, 0..) |*byte, index| {
        byte.* = @truncate(index * 37 + seed * 19 + index / 7);
        if (depth < 8) byte.* &= (@as(u8, 1) << @intCast(depth)) - 1;
    }
    return pixels;
}
fn verifyFiltering() !void {
    var hash: u64 = 14695981039346656037;
    var cases: usize = 0;
    for (formats) |format| for ([_]u32{ 1, 3, 9, 17 }) |width| for ([_]u32{ 0, 1, 3 }) |height| for (0..8) |seed| {
        var pixels = try pixelsFor(format, width * height, seed);
        defer pixels.deinit(allocator);
        const header = try headerFor(format, width, height);
        const length = (header.lineBytes() + 1) * height;
        for (0..6) |choice| for ([_]usize{ 0, 1, if (length > 0) length - 1 else 0, length, length + 5 }) |capacity| {
            const bytes = try allocator.alloc(u8, capacity);
            defer allocator.free(bytes);
            @memset(bytes, 0xa5);
            var writer = std.Io.Writer.fixed(bytes);
            const selected: filtering.FilterChoice = if (choice == 5) .heuristic else .{ .specified = @enumFromInt(choice) };
            var failed = false;
            filtering.filter(allocator, &writer, pixels, selected, header) catch |err| {
                try std.testing.expectEqual(error.InvalidData, err);
                failed = true;
            };
            mix(&hash, @intFromBool(failed));
            mix(&hash, writer.end);
            bytesHash(&hash, bytes);
            cases += 1;
        };
    };
    std.debug.print("PNG filtering: {d} cases, {x:0>16}\n", .{ cases, hash });
    try std.testing.expectEqual(@as(usize, 43200), cases);
    try std.testing.expectEqual(@as(u64, 0x809cede448778a71), hash);
}

fn appendChunk(bytes: *std.ArrayList(u8), name: []const u8, data: []const u8) !void {
    try append32(bytes, @intCast(data.len));
    try bytes.appendSlice(allocator, name);
    try bytes.appendSlice(allocator, data);
    var crc = std.hash.Crc32.init();
    crc.update(name);
    crc.update(data);
    try append32(bytes, crc.final());
}
fn verifyRows() !void {
    var hash: u64 = 14695981039346656037;
    var cases: usize = 0;
    for (formats) |format| for ([_]u32{ 1, 9, 17 }) |width| for ([_]u32{ 1, 3 }) |height| for (0..4) |seed| for (0..5) |filter| {
        var pixels = try pixelsFor(format, width * height, seed);
        defer pixels.deinit(allocator);
        const header = try headerFor(format, width, height);
        const encoded = try allocator.alloc(u8, (header.lineBytes() + 1) * height);
        defer allocator.free(encoded);
        var writer = std.Io.Writer.fixed(encoded);
        try filtering.filter(allocator, &writer, pixels, .{ .specified = @enumFromInt(filter) }, header);
        var bytes: std.ArrayList(u8) = .{};
        defer bytes.deinit(allocator);
        try bytes.appendSlice(allocator, png.magic_header);
        var fields: std.ArrayList(u8) = .{};
        defer fields.deinit(allocator);
        try append32(&fields, width);
        try append32(&fields, height);
        try fields.appendSlice(allocator, &.{ header.bit_depth, @intFromEnum(header.color_type), 0, 0, 0 });
        try appendChunk(&bytes, "IHDR", fields.items);
        if (format.isIndexed()) {
            var palette: std.ArrayList(u8) = .{};
            defer palette.deinit(allocator);
            for (0..header.maxPaletteSize()) |index| try palette.appendSlice(allocator, &.{ @truncate(index), @truncate(index * 7), @truncate(index * 13) });
            try appendChunk(&bytes, "PLTE", palette.items);
        }
        var compressed: std.ArrayList(u8) = .{};
        defer compressed.deinit(allocator);
        const length: u16 = @intCast(encoded.len);
        try compressed.appendSlice(allocator, &.{ 0x78, 0, 1, @truncate(length), @truncate(length >> 8), @truncate(~length), @truncate(~length >> 8) });
        try compressed.appendSlice(allocator, encoded);
        try compressed.appendSlice(allocator, &.{ 0, 0, 0, 0 });
        try appendChunk(&bytes, "IDAT", compressed.items);
        try appendChunk(&bytes, "IEND", &.{});
        var stream = io.ReadStream.initMemory(bytes.items);
        var image = try reader.load(&stream, allocator, .{});
        defer image.deinit(allocator);
        bytesHash(&hash, image.pixels.asConstBytes());
        cases += 1;
    };
    std.debug.print("PNG defilter/spread: {d} cases, {x:0>16}\n", .{ cases, hash });
    try std.testing.expectEqual(@as(usize, 1800), cases);
    try std.testing.expectEqual(@as(u64, 0x2ad35f81b5cd96cd), hash);
}

fn trnsHash(hash: *u64, processor: reader.TrnsProcessor) void {
    mix(hash, @intFromBool(processor.processed));
    switch (processor.trns_data) {
        .unset => mix(hash, 0),
        .gray => |value| {
            mix(hash, 1);
            mix(hash, value);
        },
        .rgb => |c| {
            mix(hash, 2);
            mix(hash, c.r);
            mix(hash, c.g);
            mix(hash, c.b);
        },
        .index_alpha => |alpha| {
            mix(hash, 3);
            mix(hash, alpha.len);
            bytesHash(hash, alpha);
        },
    }
}
fn verifyProcessors() !void {
    var hash: u64 = 14695981039346656037;
    var cases: usize = 0;
    for (formats) |format| for (0..13) |length| for ([_]bool{ false, true }) |processed| for (0..4) |seed| {
        const header = try headerFor(format, 1, 1);
        const bytes = try allocator.alloc(u8, length + 5);
        defer allocator.free(bytes);
        for (bytes, 0..) |*byte, index| byte.* = @truncate(index * 37 + seed * 19);
        var stream = io.ReadStream.initMemory(bytes);
        var processor = reader.TrnsProcessor{ .processed = processed };
        if (seed == 1) processor.trns_data = .{ .gray = 0x1234 };
        if (seed == 2) processor.trns_data = .{ .rgb = .{ .r = 1, .g = 257, .b = 65535 } };
        if (seed == 3) processor.trns_data = .{ .index_alpha = @constCast(&[_]u8{ 17, 32 }) };
        var callback = processor.processor();
        var data = reader.ChunkProcessData{ .read_stream = &stream, .chunk_id = png.Chunks.tRNS.id, .chunk_length = @intCast(length), .current_format = format, .header = &header, .temp_allocator = allocator };
        const result = try callback.processChunk(&data);
        mix(&hash, @intFromEnum(result));
        mix(&hash, stream.getPos());
        trnsHash(&hash, processor);
        cases += 1;
        if (processor.trns_data == .index_alpha and length <= header.maxPaletteSize() and !processed and format.isIndexed()) allocator.free(processor.trns_data.index_alpha);
    };
    for ([_]PixelFormat{ .grayscale1, .grayscale2, .grayscale4, .grayscale8, .grayscale16, .rgb24, .rgb48, .indexed8 }) |source| for ([_]PixelFormat{ .grayscale8Alpha, .grayscale16Alpha, .rgba32, .bgra32, .rgba64 }) |destination| for (0..8) |seed| {
        // These direct-API combinations enter an unreachable arm, an infinite
        // zero-stride loop, or a mis-sized Rgba64 slice in the source.
        if (source == .rgb24 and (destination == .grayscale8Alpha or destination == .grayscale16Alpha)) continue;
        if (source == .rgb48 and destination.pixelStride() < 8) continue;
        const row = try allocator.alloc(u8, 5 * destination.pixelStride());
        defer allocator.free(row);
        for (row, 0..) |*byte, index| byte.* = @truncate(index * 37 + seed * 19);
        var processor = reader.TrnsProcessor{};
        if (source == .rgb24 or source == .rgb48) processor.trns_data = .{ .rgb = .{ .r = @as(u16, @intCast(seed)) * 19, .g = 37, .b = 74 } } else processor.trns_data = .{ .gray = @as(u16, @intCast(seed)) * 19 };
        var data = reader.RowProcessData{ .dest_row = row, .src_format = source, .dest_format = destination, .header = undefined, .temp_allocator = allocator };
        const result = try processor.processDataRow(&data);
        mix(&hash, @intFromEnum(result));
        trnsHash(&hash, processor);
        bytesHash(&hash, row);
        cases += 1;
    };
    for (0..4) |kind| {
        var processor = reader.TrnsProcessor{};
        if (kind == 1) processor.trns_data = .{ .gray = 17 };
        if (kind == 2) processor.trns_data = .{ .rgb = .{ .r = 1, .g = 2, .b = 3 } };
        if (kind == 3) processor.trns_data = .{ .index_alpha = @constCast(&[_]u8{ 17, 32 }) };
        var palette = [_]color.Rgba32{ .{ .r = 1, .g = 2, .b = 3, .a = 255 }, .{ .r = 4, .g = 5, .b = 6, .a = 255 } };
        var data = reader.PaletteProcessData{ .palette = &palette, .temp_allocator = allocator };
        var failed = false;
        processor.processPalette(&data) catch |err| {
            try std.testing.expectEqual(error.InvalidData, err);
            failed = true;
        };
        mix(&hash, @intFromBool(failed));
        trnsHash(&hash, processor);
        bytesHash(&hash, std.mem.sliceAsBytes(palette[0..]));
        cases += 1;
    }
    for (formats) |format| for ([_]bool{ false, true }) |processed| {
        var processor = reader.PlteProcessor{ .processed = processed, .palette = &.{} };
        var data = reader.ChunkProcessData{ .current_format = format, .header = undefined, .read_stream = undefined, .chunk_id = png.Chunks.PLTE.id, .chunk_length = 0, .temp_allocator = allocator };
        const result = try processor.processChunk(&data);
        mix(&hash, @intFromEnum(result));
        mix(&hash, @intFromBool(processor.processed));
        cases += 1;
    };
    for ([_]PixelFormat{ .indexed1, .indexed2, .indexed4, .indexed8, .indexed16, .grayscale8 }) |source| for ([_]PixelFormat{ .rgba32, .bgra32, .rgba64, .grayscale8 }) |destination| for (0..8) |seed| {
        const row = try allocator.alloc(u8, 5 * destination.pixelStride());
        defer allocator.free(row);
        @memset(row, 0xa5);
        if (destination != .grayscale8) for (0..5) |index| {
            const at = index * destination.pixelStride();
            row[at] = @intCast((index + seed) % 4);
            if (source == .indexed16) row[at + 1] = 0;
        };
        var palette = [_]color.Rgba32{ .{ .r = 1, .g = 2, .b = 3, .a = 4 }, .{ .r = 5, .g = 6, .b = 7, .a = 8 }, .{ .r = 9, .g = 10, .b = 11, .a = 12 }, .{ .r = 13, .g = 14, .b = 15, .a = 16 } };
        var processor = reader.PlteProcessor{};
        var palette_data = reader.PaletteProcessData{ .palette = &palette, .temp_allocator = allocator };
        try processor.processPalette(&palette_data);
        var callback = processor.processor();
        var data = reader.RowProcessData{ .dest_row = row, .src_format = source, .dest_format = destination, .header = undefined, .temp_allocator = allocator };
        const result = try callback.processDataRow(&data);
        mix(&hash, @intFromEnum(result));
        mix(&hash, @intFromBool(processor.processed));
        bytesHash(&hash, row);
        cases += 1;
    };
    std.debug.print("PNG processors: {d} cases, {x:0>16}\n", .{ cases, hash });
    try std.testing.expectEqual(@as(usize, 2058), cases);
    try std.testing.expectEqual(@as(u64, 0xb0a838ddd9ac9218), hash);
}

fn verifyTrnsTruncations() !void {
    var hash: u64 = 14695981039346656037;
    var cases: usize = 0;
    for (formats) |format| for (0..13) |length| for ([_]bool{ false, true }) |processed| for (0..4) |seed| for (0..length + 6) |cut| {
        const header = try headerFor(format, 1, 1);
        const bytes = try allocator.alloc(u8, cut);
        defer allocator.free(bytes);
        for (bytes, 0..) |*byte, index| byte.* = @truncate(index * 37 + seed * 19);
        var stream = io.ReadStream.initMemory(bytes);
        var processor = reader.TrnsProcessor{ .processed = processed };
        if (seed == 1) processor.trns_data = .{ .gray = 0x1234 };
        if (seed == 2) processor.trns_data = .{ .rgb = .{ .r = 1, .g = 257, .b = 65535 } };
        if (seed == 3) processor.trns_data = .{ .index_alpha = @constCast(&[_]u8{ 17, 32 }) };
        var data = reader.ChunkProcessData{ .read_stream = &stream, .header = &header, .chunk_id = png.Chunks.tRNS.id, .chunk_length = @intCast(length), .current_format = format, .temp_allocator = allocator };
        if (processor.processChunk(&data)) |result| {
            mix(&hash, 0);
            mix(&hash, @intFromEnum(result));
        } else |err| mix(&hash, if (err == error.EndOfStream) 1 else if (err == error.Unseekable) 2 else 3);
        mix(&hash, stream.getPos());
        const short_scalar = !processed and ((header.color_type == .grayscale and length == 2 and cut < 2) or (header.color_type == .rgb_color and length == 6 and cut < 6));
        if (short_scalar) {
            // Failed native scalar assignments can leave an undefined union payload.
            mix(&hash, @intFromBool(processor.processed));
        } else if (!processed and format.isIndexed() and length <= header.maxPaletteSize()) {
            // Only the prefix assigned by readSliceAll is defined on failure.
            mix(&hash, @intFromBool(processor.processed));
            mix(&hash, 3);
            mix(&hash, processor.trns_data.index_alpha.len);
            bytesHash(&hash, processor.trns_data.index_alpha[0..@min(cut, length)]);
            allocator.free(processor.trns_data.index_alpha);
        } else trnsHash(&hash, processor);
        cases += 1;
    };
    std.debug.print("PNG tRNS truncations: {d} cases, {x:0>16}\n", .{ cases, hash });
    try std.testing.expectEqual(@as(usize, 18720), cases);
    try std.testing.expectEqual(@as(u64, 0x0975e75ee48838d7), hash);
}

pub fn main() !void {
    try verifyHeaders();
    try verifyFiltering();
    try verifyRows();
    try verifyProcessors();
    try verifyTrnsTruncations();
}
