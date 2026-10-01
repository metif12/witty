const std = @import("std");
const Info = @import("src/formats/png/InfoProcessor.zig");
const png = @import("src/formats/png/types.zig");
const reader = @import("src/formats/png/reader.zig");
const io = @import("src/io.zig");
const color = @import("src/color.zig");
const PixelFormat = @import("src/pixel_format.zig").PixelFormat;
const allocator = std.heap.page_allocator;

fn hashBytes(bytes: []const u8) u64 {
    var hash: u64 = 14695981039346656037;
    for (bytes) |byte| hash = (hash ^ byte) *% 1099511628211;
    return hash;
}
fn headerFor() png.HeaderData {
    return .{ .width = 17, .height = 3, .bit_depth = 8, .color_type = .grayscale, .compression_method = .deflate, .filter_method = .adaptive, .interlace_method = .adam7 };
}
fn number(text: []const u8) !u64 {
    return std.fmt.parseInt(u64, text, 10);
}
fn bounds(name: []const u8) !void {
    var bytes: [4096]u8 = @splat(0);
    var writer = std.Io.Writer.fixed(&bytes);
    var contents: [20]u8 = @splat(1);
    var input = io.ReadStream.initMemory(&contents);
    var processor = Info.init(&writer);
    var header = headerFor();
    var data = reader.ChunkProcessData{ .read_stream = &input, .header = &header, .current_format = .grayscale8, .chunk_id = 0, .chunk_length = 0, .temp_allocator = allocator };
    if (std.mem.eql(u8, name, "count_overflow")) {
        data.chunk_id = png.Chunks.IDAT.id;
        processor.idat_count = 0xffffffff;
    } else if (std.mem.eql(u8, name, "size_overflow")) {
        data.chunk_id = png.Chunks.IDAT.id;
        data.chunk_length = 1;
        processor.idat_size = std.math.maxInt(u64);
    } else if (std.mem.eql(u8, name, "compression_tag")) {
        data.chunk_id = png.Chunks.IHDR.id;
        header.compression_method = @enumFromInt(255);
    } else if (std.mem.eql(u8, name, "filter_tag")) {
        data.chunk_id = png.Chunks.IHDR.id;
        header.filter_method = @enumFromInt(255);
    } else if (std.mem.eql(u8, name, "color_tag")) {
        data.chunk_id = png.Chunks.IHDR.id;
        @as(*u8, @ptrCast(&header.color_type)).* = 255;
    } else if (std.mem.eql(u8, name, "interlace_tag")) {
        data.chunk_id = png.Chunks.IHDR.id;
        @as(*u8, @ptrCast(&header.interlace_method)).* = 255;
    } else if (std.mem.eql(u8, name, "text_null")) {
        data.chunk_id = png.Chunks.tEXt.id;
        data.chunk_length = 6;
    } else if (std.mem.eql(u8, name, "ztxt_null")) {
        data.chunk_id = png.Chunks.zTXt.id;
        data.chunk_length = 6;
    } else if (std.mem.eql(u8, name, "ztxt_method")) {
        data.chunk_id = png.Chunks.zTXt.id;
        data.chunk_length = 1;
        input = io.ReadStream.initMemory(&.{ 0, 0, 0, 0, 0, 0 });
    } else if (std.mem.eql(u8, name, "itxt_flags")) {
        data.chunk_id = png.Chunks.iTXt.id;
        data.chunk_length = 1;
        input = io.ReadStream.initMemory(&.{0});
    } else if (std.mem.eql(u8, name, "itxt_language")) {
        data.chunk_id = png.Chunks.iTXt.id;
        data.chunk_length = 4;
        input = io.ReadStream.initMemory(&.{ 0, 0, 0, 1 });
    } else if (std.mem.eql(u8, name, "itxt_translation")) {
        data.chunk_id = png.Chunks.iTXt.id;
        data.chunk_length = 5;
        input = io.ReadStream.initMemory(&.{ 0, 0, 0, 0, 1 });
    } else {
        std.debug.print("UNEXPECTED: unknown probe\n", .{});
        return;
    }
    var callback = processor.processor();
    _ = callback.processChunk(&data) catch |err| {
        std.debug.print("UNEXPECTED: {s}\n", .{@errorName(err)});
        return;
    };
    std.debug.print("UNEXPECTED: PNG info returned\n", .{});
}
pub fn main() !void {
    const args = try std.process.argsAlloc(allocator);
    if (std.mem.eql(u8, args[1], "--bounds")) {
        try bounds(args[2]);
        return;
    }
    const contents = try std.fs.cwd().readFileAlloc(allocator, args[1], 128 * 1024 * 1024);
    defer allocator.free(contents);
    var lines = std.mem.tokenizeScalar(u8, contents, '\n');
    var stdout = std.fs.File.stdout().writer(&.{});
    while (lines.next()) |line| {
        var fields: [9][]const u8 = undefined;
        var parts = std.mem.splitScalar(u8, line, '|');
        for (&fields) |*field| field.* = parts.next().?;
        const bytes = try allocator.alloc(u8, @intCast(try number(fields[4])));
        defer allocator.free(bytes);
        @memset(bytes, 0xa5);
        var writer = std.Io.Writer.fixed(bytes);
        const contents_bytes = try allocator.alloc(u8, fields[5].len / 2);
        defer allocator.free(contents_bytes);
        _ = try std.fmt.hexToBytes(contents_bytes, fields[5]);
        var input = io.ReadStream.initMemory(contents_bytes);
        var processor = Info.init(&writer);
        processor.idat_count = @intCast(try number(fields[6]));
        processor.idat_size = try number(fields[7]);
        var header = headerFor();
        header.bit_depth = @intCast(try number(fields[3]));
        header.color_type = @enumFromInt(try number(fields[2]));
        var callback = processor.processor();
        var status: []const u8 = "ok";
        var result: u32 = @intFromEnum(PixelFormat.grayscale8);
        if (std.mem.eql(u8, fields[8], "0")) {
            var data = reader.ChunkProcessData{ .read_stream = &input, .header = &header, .current_format = .grayscale8, .chunk_id = @intCast(try number(fields[0])), .chunk_length = @intCast(try number(fields[1])), .temp_allocator = allocator };
            if (callback.processChunk(&data)) |format| result = @intFromEnum(format) else |err| {
                status = @errorName(err);
                result = @intFromEnum(PixelFormat.invalid);
            }
        } else {
            const palette = try allocator.alloc(color.Rgba32, @intCast(try number(fields[1])));
            defer allocator.free(palette);
            var data = reader.PaletteProcessData{ .palette = palette, .temp_allocator = allocator };
            callback.processPalette(&data) catch |err| {
                status = @errorName(err);
            };
        }
        try stdout.interface.print("{s}|{d}|{d}|{d}|{d}|{d}|{x:0>16}\n", .{ status, input.getPos(), result, processor.idat_count, processor.idat_size, writer.end, hashBytes(bytes) });
    }
}
