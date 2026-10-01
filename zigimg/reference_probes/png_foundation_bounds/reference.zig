const std = @import("std");
const png = @import("src/formats/png/types.zig");
const reader = @import("src/formats/png/reader.zig");
const filtering = @import("src/formats/png/filtering.zig");
const color = @import("src/color.zig");
const io = @import("src/io.zig");
const allocator = std.heap.page_allocator;

pub fn main() void {
    const args = std.process.argsAlloc(allocator) catch unreachable;
    std.debug.assert(args.len == 2);
    const name = args[1];
    var bytes: [32]u8 = @splat(0);
    var writer = std.Io.Writer.fixed(&bytes);
    var stream = io.ReadStream.initMemory(&bytes);
    var header = png.HeaderData{ .width = 1, .height = 1, .bit_depth = 8, .color_type = .grayscale, .compression_method = .deflate, .filter_method = .adaptive, .interlace_method = .none };
    if (std.mem.eql(u8, name, "pixel_bits")) {
        header.bit_depth = 255;
        header.color_type = .rgba_color;
        std.mem.doNotOptimizeAway(header.pixelBits());
    } else if (std.mem.eql(u8, name, "line_bytes")) {
        header.width = 0x1fffffff;
        header.bit_depth = 16;
        std.mem.doNotOptimizeAway(header.lineBytes());
    } else if (std.mem.eql(u8, name, "short_pixels") or std.mem.eql(u8, name, "channels8") or std.mem.eql(u8, name, "channels16") or std.mem.eql(u8, name, "try_all")) {
        const pixels = color.PixelStorage.init(allocator, if (std.mem.eql(u8, name, "channels16")) .grayscale16 else .grayscale8, 1) catch |err| {
            std.debug.print("UNEXPECTED: {s}\n", .{@errorName(err)});
            return;
        };
        if (std.mem.eql(u8, name, "short_pixels")) header.width = 2;
        if (std.mem.eql(u8, name, "channels8") or std.mem.eql(u8, name, "channels16")) header.color_type = .rgba_color;
        if (std.mem.eql(u8, name, "channels16")) header.bit_depth = 16;
        const choice: filtering.FilterChoice = if (std.mem.eql(u8, name, "try_all")) .try_all else .{ .specified = .none };
        filtering.filter(allocator, &writer, pixels, choice, header) catch |err| {
            std.debug.print("UNEXPECTED: {s}\n", .{@errorName(err)});
            return;
        };
    } else if (std.mem.eql(u8, name, "palette_bounds")) {
        var alpha = [_]u8{ 0, 17 };
        var palette = [_]color.Rgba32{.{}};
        var processor = reader.TrnsProcessor{ .trns_data = .{ .index_alpha = &alpha } };
        var data = reader.PaletteProcessData{ .palette = &palette, .temp_allocator = allocator };
        processor.processPalette(&data) catch |err| {
            std.debug.print("UNEXPECTED: {s}\n", .{@errorName(err)});
            return;
        };
    } else if (std.mem.eql(u8, name, "skip_overflow")) {
        var processor = reader.TrnsProcessor{ .processed = true };
        var data = reader.ChunkProcessData{ .read_stream = &stream, .header = &header, .chunk_id = png.Chunks.tRNS.id, .chunk_length = 0xffffffff, .current_format = .grayscale8, .temp_allocator = allocator };
        _ = processor.processChunk(&data) catch |err| {
            std.debug.print("UNEXPECTED: {s}\n", .{@errorName(err)});
            return;
        };
    } else if (std.mem.eql(u8, name, "plte_index")) {
        var palette = [_]color.Rgba32{.{}};
        var row = [_]u8{ 1, 0, 0, 0 };
        var processor = reader.PlteProcessor{ .palette = &palette };
        var data = reader.RowProcessData{ .header = &header, .src_format = .indexed8, .dest_format = .rgba32, .dest_row = &row, .temp_allocator = allocator };
        _ = processor.processDataRow(&data) catch |err| {
            std.debug.print("UNEXPECTED: {s}\n", .{@errorName(err)});
            return;
        };
    } else if (std.mem.eql(u8, name, "gray_source") or std.mem.eql(u8, name, "rgb_source") or std.mem.eql(u8, name, "trns_arm") or std.mem.eql(u8, name, "gray16_odd") or std.mem.eql(u8, name, "rgb48_odd") or std.mem.eql(u8, name, "zero_stride")) {
        var processor = reader.TrnsProcessor{ .trns_data = .{ .gray = 0 } };
        var data = reader.RowProcessData{ .header = &header, .src_format = .rgb24, .dest_format = .rgba32, .dest_row = bytes[0..4], .temp_allocator = allocator };
        if (std.mem.eql(u8, name, "rgb_source")) {
            processor.trns_data = .{ .rgb = .{} };
            data.src_format = .grayscale8;
        }
        if (std.mem.eql(u8, name, "trns_arm")) {
            processor.trns_data = .{ .index_alpha = &.{} };
            data.src_format = .grayscale8;
        }
        if (std.mem.eql(u8, name, "gray16_odd")) {
            data.src_format = .grayscale16;
            data.dest_format = .grayscale16Alpha;
            data.dest_row = bytes[0..3];
        }
        if (std.mem.eql(u8, name, "rgb48_odd")) {
            processor.trns_data = .{ .rgb = .{} };
            data.src_format = .rgb48;
        }
        if (std.mem.eql(u8, name, "zero_stride")) {
            processor.trns_data = .{ .rgb = .{} };
            data.dest_format = .grayscale8Alpha;
            std.debug.print("READY: zero-stride row\n", .{});
        }
        _ = processor.processDataRow(&data) catch |err| {
            std.debug.print("UNEXPECTED: {s}\n", .{@errorName(err)});
            return;
        };
    } else {
        std.debug.print("UNEXPECTED: unknown probe\n", .{});
        return;
    }
    std.debug.print("UNEXPECTED: PNG operation returned\n", .{});
}
