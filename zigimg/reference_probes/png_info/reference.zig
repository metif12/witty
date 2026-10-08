const std = @import("std");
const Info = @import("src/formats/png/InfoProcessor.zig");
const png = @import("src/formats/png/types.zig");
const reader = @import("src/formats/png/reader.zig");
const io = @import("src/io.zig");
const color = @import("src/color.zig");
const PixelFormat = @import("src/pixel_format.zig").PixelFormat;
const allocator = std.heap.page_allocator;

pub const panic = std.debug.FullPanic(observePanic);
var observed_processor: ?*Info = null;
var observed_writer: ?*std.Io.Writer = null;
var observed_input: ?*io.ReadStream = null;
var observed_bytes: []const u8 = &.{};
var observed_path: ?[]const u8 = null;

fn observePanic(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| if (observed_processor) |processor| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var output = file.writer(&.{});
            output.interface.print("{d}|{d}|{d}|{d}|{x:0>16}", .{ processor.idat_count, processor.idat_size, observed_input.?.getPos(), observed_writer.?.end, hashBytes(observed_bytes) }) catch {};
        } else |_| {}
    };
    std.debug.defaultPanic(message, address);
}

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
fn bounds(name: []const u8, path: []const u8) !void {
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
    } else if (std.mem.eql(u8, name, "both_overflow")) {
        data.chunk_id = png.Chunks.IDAT.id;
        data.chunk_length = 1;
        processor.idat_count = 0xffffffff;
        processor.idat_size = std.math.maxInt(u64);
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
    } else if (std.mem.startsWith(u8, name, "itxt_one_")) {
        data.chunk_id = png.Chunks.iTXt.id;
        data.chunk_length = 2;
        contents[0] = 0;
        contents[1] = if (std.mem.eql(u8, name, "itxt_one_yes")) 1 else if (std.mem.eql(u8, name, "itxt_one_no")) 0 else 2;
        input = io.ReadStream.initMemory(contents[0..2]);
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
    observed_processor = &processor;
    observed_writer = &writer;
    observed_input = &input;
    observed_bytes = &bytes;
    observed_path = path;
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
        try bounds(args[2], args[3]);
        return;
    }
    if (std.mem.eql(u8, args[1], "--contracts")) {
        try contracts();
        return;
    }
    const contents = try std.fs.cwd().readFileAlloc(allocator, args[1], 128 * 1024 * 1024);
    defer allocator.free(contents);
    var lines = std.mem.tokenizeScalar(u8, contents, '\n');
    var stdout = std.fs.File.stdout().writer(&.{});
    while (lines.next()) |line| {
        var fields: [12][]const u8 = @splat("0");
        fields[11] = "1";
        var parts = std.mem.splitScalar(u8, line, '|');
        var length: usize = 0;
        while (parts.next()) |field| {
            fields[length] = field;
            length += 1;
        }
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
        @as(*u8, @ptrCast(&header.color_type)).* = @intCast(try number(fields[2]));
        header.compression_method = @enumFromInt(try number(fields[9]));
        header.filter_method = @enumFromInt(try number(fields[10]));
        @as(*u8, @ptrCast(&header.interlace_method)).* = @intCast(try number(fields[11]));
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
            @memset(palette, std.mem.zeroes(color.Rgba32));
            var data = reader.PaletteProcessData{ .palette = palette, .temp_allocator = allocator };
            callback.processPalette(&data) catch |err| {
                status = @errorName(err);
            };
        }
        try stdout.interface.print("{s}|{d}|{d}|{d}|{d}|{d}|{x:0>16}\n", .{ status, input.getPos(), result, processor.idat_count, processor.idat_size, writer.end, hashBytes(bytes) });
    }
}

fn contracts() !void {
    var bytes: [256]u8 = @splat(0xa5);
    var writer = std.Io.Writer.fixed(&bytes);
    var original: Info = .{ .writer = &writer };
    const initialized = Info.init(&writer);
    var output = std.fs.File.stdout().writer(&.{});
    try output.interface.print("{d}|{d}|{d}|{d}|{d}|", .{ original.idat_count, original.idat_size, initialized.idat_count, initialized.idat_size, @intFromBool(original.writer == initialized.writer) });
    original.idat_count = 17;
    original.idat_size = 23;
    var copy = original;
    var input = io.ReadStream.initMemory(&.{});
    var header = headerFor();
    var data: reader.ChunkProcessData = .{ .read_stream = &input, .header = &header, .chunk_id = png.Chunks.IDAT.id, .chunk_length = 7, .current_format = .grayscale8, .temp_allocator = allocator };
    var callback = copy.processor();
    _ = try callback.processChunk(&data);
    data.chunk_id = png.Chunks.IEND.id;
    _ = try callback.processChunk(&data);
    try output.interface.print("{d}|{d}|{d}|{d}|{d}|{d}|{x:0>16}\n", .{ original.idat_count, original.idat_size, copy.idat_count, copy.idat_size, @intFromBool(copy.writer == original.writer), writer.end, hashBytes(&bytes) });
}
