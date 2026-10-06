const std = @import("std");
const types = @import("src/formats/tiff/types.zig");
const TIFF = @import("src/formats/tiff.zig").TIFF;
const io = @import("src/io.zig");

fn returning() !void {
    const allocator = std.heap.page_allocator;
    var bytes: [48]u8 = undefined;
    for (&bytes, 0..) |*byte, index| byte.* = @truncate(index * 37 + 11);
    var output = std.fs.File.stdout().writer(&.{});
    const writer = &output.interface;
    for ([_]std.builtin.Endian{ .big, .little }, 0..) |endianess, endian_index| {
        for ([_]u16{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 65535 }) |data_type| {
            for ([_]u32{ 0, 1, 2, 3, 8 }) |count| {
                if (count > 1 and data_type != 3 and data_type != 4) continue;
                var stream = io.ReadStream.initMemory(&bytes);
                const tag = types.TagField{ .data_type = data_type, .data_count = count, .data_offset = if (count == 1) 0x12345678 else 3 };
                const values = try tag.readTagData(allocator, &stream, endianess);
                defer allocator.free(values);
                try writer.print("A|{d}|{d}|{d}|{d}|{d}|{d}|{d}|", .{ endian_index, data_type, count, tag.toLong(), tag.toShort(endianess), tag.toLongOrShort(endianess), stream.getPos() });
                for (values) |value| try writer.print("{d},", .{value});
                try writer.writeByte('\n');
            }
        }
        for (0..9) |length| {
            var stream = io.ReadStream.initMemory(bytes[0..length]);
            const tag = types.TagField{ .data_type = 5, .data_count = 1, .data_offset = 0 };
            var status: []const u8 = "ok";
            const values = tag.readRational(&stream, endianess) catch |err| blk: {
                status = @errorName(err);
                break :blk [2]u32{ 0, 0 };
            };
            try writer.print("R|{d}|{d}|{s}|{d}|{d}|{d}\n", .{ endian_index, length, status, stream.getPos(), values[0], values[1] });
        }
    }
    try writer.flush();
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    std.debug.assert(args.len == 2);
    const name = args[1];
    if (std.mem.eql(u8, name, "--returning")) return returning();
    const bytes = try allocator.alloc(u8, 1536);
    @memset(bytes, 0);
    var stream = io.ReadStream.initMemory(bytes);
    var codec = TIFF{ .endianess = .little, .bitmap = .{}, .ifd = try types.IFD.init(allocator, &stream, 0) };
    if (std.mem.eql(u8, name, "map_capacity_cast") or std.mem.eql(u8, name, "map_capacity_power")) {
        try codec.ifd.tags_map.ensureTotalCapacity(if (std.mem.eql(u8, name, "map_capacity_cast")) 0xffffffff else 0x80000000);
    } else if (std.mem.eql(u8, name, "unknown_tag")) {
        stream = io.ReadStream.initMemory(&.{ 1, 0, 0xe7, 3, 3, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 });
        try codec.ifd.readTags(.little);
    } else if (std.mem.eql(u8, name, "compression_enum") or std.mem.eql(u8, name, "resolution_enum")) {
        const key: types.TagId = if (std.mem.eql(u8, name, "compression_enum")) .compression else .resolution_unit;
        try codec.ifd.tags_map.put(key, .{ .data_type = 3, .data_count = 1, .data_offset = 0 });
        try codec.decodeBitmap(allocator, &stream);
    } else if (std.mem.eql(u8, name, "bits_capacity") or std.mem.eql(u8, name, "extra_capacity")) {
        const key: types.TagId = if (std.mem.eql(u8, name, "bits_capacity")) .bits_per_sample else .extra_samples;
        try codec.ifd.tags_map.put(key, .{ .data_type = 3, .data_count = 9, .data_offset = 0 });
        try codec.decodeBitmap(allocator, &stream);
    } else if (std.mem.eql(u8, name, "empty_bits")) {
        _ = try codec.bitmap.guessPixelFormat();
    } else if (std.mem.eql(u8, name, "missing_alpha")) {
        codec.bitmap.photometric_interpretation = 2;
        codec.bitmap.bits_per_sample.resize(4);
        @memset(codec.bitmap.bits_per_sample.data, 8);
        _ = try codec.bitmap.guessPixelFormat();
    } else if (std.mem.eql(u8, name, "row_components")) {
        codec.bitmap.samples_per_pixel = 2;
        codec.bitmap.bits_per_sample.resize(1);
        codec.bitmap.bits_per_sample.data[0] = 8;
        _ = try codec.calRowByteSize();
    } else if (std.mem.eql(u8, name, "byte_overflow") or std.mem.eql(u8, name, "array_type")) {
        const tag = types.TagField{ .data_type = if (std.mem.eql(u8, name, "byte_overflow")) 4 else 5, .data_count = if (std.mem.eql(u8, name, "byte_overflow")) std.math.maxInt(u32) else 2, .data_offset = 0 };
        _ = try tag.readTagData(allocator, &stream, .little);
    } else if (std.mem.eql(u8, name, "palette_capacity") or std.mem.eql(u8, name, "palette_power") or std.mem.eql(u8, name, "short_palette")) {
        if (!std.mem.eql(u8, name, "short_palette")) try codec.ifd.tags_map.put(.bits_per_sample, .{ .data_type = 3, .data_count = 1, .data_offset = if (std.mem.eql(u8, name, "palette_power")) 16 else 9 });
        try codec.ifd.tags_map.put(.color_map, .{ .data_type = 3, .data_count = if (std.mem.eql(u8, name, "short_palette")) 1 else 768, .data_offset = 0 });
        try codec.decodeBitmap(allocator, &stream);
    } else @panic("unknown case");
    std.debug.print("UNEXPECTED: TIFF metadata operation returned\n", .{});
}
