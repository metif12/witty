const std = @import("std");
const TIFF = @import("src/formats/tiff.zig").TIFF;
const types = @import("src/formats/tiff/types.zig");
const io = @import("src/io.zig");
const color = @import("src/color.zig");
const PixelFormat = @import("src/pixel_format.zig").PixelFormat;
const allocator = std.heap.page_allocator;

fn mix(hash: *u64, value: u64) void {
    hash.* = (hash.* ^ value) *% 1099511628211;
}

fn pixelHash(pixels: color.PixelStorage) u64 {
    var hash: u64 = 14695981039346656037;
    mix(&hash, pixels.len());
    switch (pixels) {
        inline .grayscale1, .grayscale8, .grayscale16 => |data| for (data) |pixel| {
            mix(&hash, pixel.value);
        },
        .indexed8 => |storage| {
            for (storage.indices) |index| mix(&hash, index);
            for (storage.palette) |c| {
                for ([_]u8{ c.r, c.g, c.b, c.a }) |channel| mix(&hash, channel);
            }
        },
        .rgb24 => |data| for (data) |c| {
            for ([_]u8{ c.r, c.g, c.b }) |channel| mix(&hash, channel);
        },
        .rgba32 => |data| for (data) |c| {
            for ([_]u8{ c.r, c.g, c.b, c.a }) |channel| mix(&hash, channel);
        },
        else => @panic("unexpected test format"),
    }
    return hash;
}

fn initialize(pixels: color.PixelStorage) void {
    switch (pixels) {
        .grayscale1 => |data| for (data) |*p| {
            p.value = 1;
        },
        .grayscale8 => |data| for (data) |*p| {
            p.value = 0xa5;
        },
        .grayscale16 => |data| for (data) |*p| {
            p.value = 0x5aa5;
        },
        .indexed8 => |storage| @memset(storage.indices, 0xa5),
        .rgb24 => |data| @memset(data, .{ .r = 0xa5, .g = 0x5a, .b = 0x81 }),
        .rgba32 => |data| @memset(data, .{ .r = 0xa5, .g = 0x5a, .b = 0x81, .a = 0x7e }),
        else => @panic("unexpected test format"),
    }
}

fn number(text: []const u8) !u32 {
    return std.fmt.parseInt(u32, text, 10);
}
fn numbers(text: []const u8) ![]u32 {
    var values: std.ArrayList(u32) = .{};
    var iterator = std.mem.splitScalar(u8, text, ',');
    while (iterator.next()) |item| {
        if (item.len > 0) try values.append(allocator, try number(item));
    }
    return values.toOwnedSlice(allocator);
}

fn boundary(name: []const u8, fixed_path: []const u8) !void {
    var stream = io.ReadStream.initMemory(&.{ 0, 0x7e, 0x7e });
    var codec = TIFF{ .bitmap = .{ .image_width = 1, .image_height = 1, .rows_per_strip = 1, .strip_offsets = @constCast(&[_]u32{1}), .strip_byte_counts = @constCast(&[_]u32{1}) } };
    codec.bitmap.bits_per_sample.resize(1);
    codec.bitmap.bits_per_sample.data[0] = 8;
    var pixels = try color.PixelStorage.init(allocator, .grayscale8, 2);
    if (std.mem.eql(u8, name, "sum_overflow")) codec.bitmap.image_height = 0xffffffff else if (std.mem.eql(u8, name, "sum_underflow")) {
        codec.bitmap.image_height = 0;
        codec.bitmap.rows_per_strip = 0;
    } else if (std.mem.eql(u8, name, "zero_rows")) codec.bitmap.rows_per_strip = 0 else if (std.mem.eql(u8, name, "empty_height")) codec.bitmap.image_height = 0 else if (std.mem.eql(u8, name, "missing_counts")) codec.bitmap.strip_byte_counts = null else if (std.mem.eql(u8, name, "missing_offsets")) codec.bitmap.strip_offsets = null else if (std.mem.eql(u8, name, "short_counts")) {
        codec.bitmap.image_height = 2;
        codec.bitmap.strip_offsets = @constCast(&[_]u32{ 1, 2 });
    } else if (std.mem.eql(u8, name, "short_offsets")) {
        codec.bitmap.image_height = 2;
        codec.bitmap.strip_byte_counts = @constCast(&[_]u32{ 1, 1 });
    } else if (std.mem.eql(u8, name, "zero_pixels")) pixels = try color.PixelStorage.init(allocator, .grayscale8, 0) else if (std.mem.eql(u8, name, "rgb_stride")) pixels = try color.PixelStorage.init(allocator, .rgb24, 1) else if (std.mem.eql(u8, name, "palette_bounds")) {
        pixels = try color.PixelStorage.init(allocator, .indexed8, 1);
        pixels.indexed8.palette = pixels.indexed8.palette[0..1];
        codec.bitmap.color_map.resize(2);
    } else if (std.mem.eql(u8, name, "packbits_overrun")) {
        codec.bitmap.compression = .packbits;
        codec.bitmap.strip_byte_counts = @constCast(&[_]u32{2});
        stream = io.ReadStream.initMemory(&.{ 0, 0x82, 0x7e });
    } else if (std.mem.eql(u8, name, "ccitt_run")) {
        stream = io.ReadStream.initMemory(&.{0x98});
        var destination: [1]u8 = undefined;
        try codec.uncompressCCITT(&stream, &destination, 1, 1);
        std.debug.print("UNEXPECTED: CCITT returned\n", .{});
        return;
    } else if (std.mem.eql(u8, name, "fixed_window")) {
        const bytes = try std.fs.cwd().readFileAlloc(allocator, fixed_path, 1024 * 1024);
        stream = io.ReadStream.initMemory(bytes);
        var destination: [70000]u8 = undefined;
        try codec.uncompressDeflate(&stream, &destination);
        std.debug.print("UNEXPECTED: fixed block returned\n", .{});
        return;
    } else if (std.mem.eql(u8, name, "pixel_overflow")) {
        var bytes: std.ArrayList(u8) = .{};
        try bytes.appendSlice(allocator, "II");
        try bytes.appendSlice(allocator, &.{ 0, 0, 8, 0, 0, 0, 3, 0 });
        for ([_]u16{ 256, 257, 258 }) |tag| {
            try bytes.appendSlice(allocator, &.{ @truncate(tag), @truncate(tag >> 8), if (tag == 258) 3 else 4, 0, 1, 0, 0, 0 });
            try bytes.appendSlice(allocator, if (tag == 258) &.{ 8, 0, 0, 0 } else &.{ 0, 0, 1, 0 });
        }
        try bytes.appendSlice(allocator, &.{ 0, 0, 0, 0 });
        stream = io.ReadStream.initMemory(bytes.items);
        _ = try codec.read(allocator, &stream);
        std.debug.print("UNEXPECTED: read returned\n", .{});
        return;
    } else @panic("unknown boundary");
    try codec.readStrips(allocator, &stream, &pixels);
    std.debug.print("UNEXPECTED: strip operation returned\n", .{});
}

pub fn main() !void {
    const args = try std.process.argsAlloc(allocator);
    if (std.mem.eql(u8, args[1], "--bounds")) {
        try boundary(args[2], args[3]);
        return;
    }
    const contents = try std.fs.cwd().readFileAlloc(allocator, args[1], 128 * 1024 * 1024);
    const formats = [_]PixelFormat{ .grayscale1, .grayscale8, .indexed8, .rgb24, .rgba32, .grayscale16 };
    var lines = std.mem.tokenizeScalar(u8, contents, '\n');
    var stdout = std.fs.File.stdout().writer(&.{});
    while (lines.next()) |line| {
        var iterator = std.mem.splitScalar(u8, line, '|');
        var fields: [13][]const u8 = undefined;
        for (&fields) |*field| field.* = iterator.next().?;
        const operation = try number(fields[0]);
        const bytes = try allocator.alloc(u8, fields[12].len / 2);
        _ = try std.fmt.hexToBytes(bytes, fields[12]);
        defer allocator.free(bytes);
        var stream = io.ReadStream.initMemory(bytes);
        var codec = TIFF{ .endianess = .big, .header = .{ .version = 123, .idf_offset = 77 }, .bitmap = .{} };
        var status: []const u8 = "ok";
        var hash: u64 = 0;
        if (operation <= 2) {
            const destination = try allocator.alloc(u8, try number(fields[8]));
            defer allocator.free(destination);
            @memset(destination, 0xa5);
            switch (operation) {
                0 => codec.uncompressDeflate(&stream, destination) catch |err| {
                    status = @errorName(err);
                },
                1 => codec.uncompressLZW(allocator, &stream, destination) catch |err| {
                    status = @errorName(err);
                },
                2 => {
                    codec.bitmap.photometric_interpretation = @intCast(try number(fields[3]));
                    codec.uncompressCCITT(&stream, destination, try number(fields[5]), try number(fields[6])) catch |err| {
                        status = @errorName(err);
                    };
                },
                else => unreachable,
            }
            hash = 14695981039346656037;
            for (destination) |byte| mix(&hash, byte);
        } else if (operation == 3) {
            codec.bitmap.compression = @enumFromInt(try number(fields[2]));
            codec.bitmap.photometric_interpretation = @intCast(try number(fields[3]));
            codec.bitmap.predictor = @intCast(try number(fields[4]));
            codec.bitmap.image_width = try number(fields[5]);
            codec.bitmap.image_height = try number(fields[6]);
            codec.bitmap.rows_per_strip = try number(fields[7]);
            const bits = try numbers(fields[9]);
            defer allocator.free(bits);
            codec.bitmap.samples_per_pixel = @intCast(bits.len);
            codec.bitmap.bits_per_sample.resize(bits.len);
            for (bits, 0..) |value, index| codec.bitmap.bits_per_sample.data[index] = @intCast(value);
            codec.bitmap.strip_offsets = try numbers(fields[10]);
            codec.bitmap.strip_byte_counts = try numbers(fields[11]);
            defer codec.bitmap.deinit(allocator);
            codec.bitmap.color_map.resize(256);
            for (codec.bitmap.color_map.data, 0..) |*c, index| c.* = .{ .r = @truncate(index), .g = @truncate(index * 7), .b = @truncate(index * 13), .a = 255 };
            var pixels = try color.PixelStorage.init(allocator, formats[try number(fields[1])], try number(fields[8]));
            defer pixels.deinit(allocator);
            initialize(pixels);
            codec.readStrips(allocator, &stream, &pixels) catch |err| {
                status = @errorName(err);
            };
            hash = pixelHash(pixels);
        } else if (operation == 4) {
            if (codec.read(allocator, &stream)) |pixels| {
                defer pixels.deinit(allocator);
                hash = pixelHash(pixels);
            } else |err| status = @errorName(err);
        } else {
            if (TIFF.readImage(allocator, &stream)) |result| {
                var image = result;
                defer image.deinit(allocator);
                hash = pixelHash(image.pixels);
                codec.bitmap.image_width = @intCast(image.width);
                codec.bitmap.image_height = @intCast(image.height);
            } else |err| status = @errorName(err);
        }
        try stdout.interface.print("{s}|{d}|{d}|{d}|{d}|{d}|{d}|{x:0>16}\n", .{ status, stream.getPos(), codec.width(), codec.height(), codec.header.version, codec.header.idf_offset, @intFromEnum(codec.endianess), hash });
    }
}
