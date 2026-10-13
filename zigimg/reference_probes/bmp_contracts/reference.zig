const std = @import("std");
const p = @import("src/formats/bmp.zig");
const color = @import("src/color.zig");
const io = @import("src/io.zig");
const Format = @import("src/pixel_format.zig").PixelFormat;
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_codec: ?*const p.BMP = null;
var observed_reader: ?*io.ReadStream = null;
var observed_writer: ?*io.WriteStream = null;
var observed_output: []const u8 = &.{};

fn info(out: *W, value: p.BitmapInfoHeader) !void {
    switch (value) {
        inline else => |header| try out.print("{d}|{x}", .{ @sizeOf(@TypeOf(header)), std.mem.asBytes(&header) }),
    }
}
fn codecState(out: *W, codec: p.BMP) !void {
    try out.print("{x}|", .{std.mem.asBytes(&codec.file_header)});
    try info(out, codec.info_header);
}
fn observe(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var buf: [4096]u8 = undefined;
            var w = file.writer(&buf);
            const out = &w.interface;
            if (observed_reader) |reader| out.print("{d}|", .{reader.getPos()}) catch {};
            if (observed_writer) |writer| out.print("{d}|{x}|", .{ writer.getPos(), observed_output }) catch {};
            if (observed_codec) |codec| codecState(out, codec.*) catch {};
            out.flush() catch {};
        } else |_| {}
    }
    std.debug.defaultPanic(message, address);
}
fn makeCodec(kind: usize, width: i32, height: i32) p.BMP {
    return .{ .file_header = .{ .magic_header = .{ 'X', 'Y' }, .size = 1, .reserved = 0x12345678, .pixel_offset = 9000 }, .info_header = switch (kind) {
        40 => .{ .windows31 = .{ .header_size = 40, .width = width, .height = height, .bit_count = 99, .compression_method = .png, .horizontal_resolution = 17 } },
        108 => .{ .v4 = .{ .header_size = 108, .width = width, .height = height, .bit_count = 99, .compression_method = .png, .horizontal_resolution = 17 } },
        else => .{ .v5 = .{ .header_size = 124, .width = width, .height = height, .bit_count = 99, .compression_method = .png, .horizontal_resolution = 17 } },
    } };
}
fn pixels(format: Format, count: usize, seed: usize) !color.PixelStorage {
    const result = try color.PixelStorage.init(a, format, count);
    for (result.asBytes(), 0..) |*byte, i| byte.* = @truncate(if (seed == 0) @as(usize, 1) else if (seed == 1) i * 17 else @as(usize, 192));
    return result;
}
fn writeCase(out: *W, kind: usize, format: Format, width: usize, height: usize, seed: usize, capacity: usize) !void {
    const data = try pixels(format, width * height, seed);
    defer data.deinit(a);
    var buf: [1024]u8 = @splat(165);
    var writer = io.WriteStream.initMemory(buf[0..capacity]);
    var status: []const u8 = "ok";
    if (kind == 0) p.BMP.writeImage(a, &writer, .{ .width = width, .height = height, .pixels = data }, .{ .bmp = .{} }) catch |err| {
        status = @errorName(err);
    } else makeCodec(kind, @intCast(width), @intCast(height)).write(&writer, data) catch |err| {
        status = @errorName(err);
    };
    try out.print("W|{d}|{d}|{d}|{d}|{d}|{d}|{s}|{d}|{x}\n", .{ kind, @intFromEnum(format), width, height, seed, capacity, status, writer.getPos(), buf[0..capacity] });
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    var buf: [8192]u8 = undefined;
    var w = std.fs.File.stdout().writer(&buf);
    const out = &w.interface;
    if (args.len > 1) {
        if (!std.mem.eql(u8, args[2], "-")) observed_path = args[2];
        if (std.mem.startsWith(u8, args[1], "--read")) {
            const bytes = try std.fs.cwd().readFileAlloc(a, args[3], 1048576);
            var reader = io.ReadStream.initMemory(bytes);
            observed_reader = &reader;
            if (std.mem.eql(u8, args[1], "--read-image")) {
                var image = p.BMP.readImage(a, &reader) catch |err| {
                    if (observed_path != null) {
                        std.debug.print("UNEXPECTED: recoverable {s}\n", .{@errorName(err)});
                        return;
                    }
                    try out.print("{s}|{d}\n", .{ @errorName(err), reader.getPos() });
                    try out.flush();
                    return;
                };
                defer image.deinit(a);
                if (observed_path == null) {
                    try out.print("ok|{d}|{d}|{d}|{x}\n", .{ reader.getPos(), image.width, image.height, image.rawBytes() });
                    try out.flush();
                    return;
                }
            } else {
                var codec = makeCodec(124, 7, 9);
                observed_codec = &codec;
                const result = codec.read(a, &reader) catch |err| {
                    if (observed_path != null) {
                        std.debug.print("UNEXPECTED: recoverable {s}\n", .{@errorName(err)});
                        return;
                    }
                    try out.print("{s}|{d}|", .{ @errorName(err), reader.getPos() });
                    try codecState(out, codec);
                    try out.writeByte('\n');
                    try out.flush();
                    return;
                };
                defer result.deinit(a);
                if (observed_path == null) {
                    try out.print("ok|{d}|", .{reader.getPos()});
                    try codecState(out, codec);
                    try out.print("|{d}|", .{result.len()});
                    if (codec.width() >= 0 and codec.height() >= 0) try out.print("{x}", .{result.asBytes()}) else try out.writeByte('-');
                    try out.writeByte('\n');
                    try out.flush();
                    return;
                }
            }
        } else {
            const capacity = try std.fmt.parseInt(usize, args[3], 10);
            var output: [1024]u8 = @splat(165);
            var writer = io.WriteStream.initMemory(output[0..capacity]);
            observed_writer = &writer;
            observed_output = output[0..capacity];
            const format: Format = @enumFromInt(try std.fmt.parseInt(u32, args[6], 10));
            const data = try pixels(format, try std.fmt.parseInt(usize, args[7], 10), 1);
            defer data.deinit(a);
            var status: []const u8 = "ok";
            if (std.mem.eql(u8, args[1], "--image")) p.BMP.writeImage(a, &writer, .{
                .width = try std.fmt.parseInt(usize, args[4], 10),
                .height = try std.fmt.parseInt(usize, args[5], 10),
                .pixels = data,
            }, .{ .bmp = .{} }) catch |err| {
                status = @errorName(err);
            } else {
                const codec = makeCodec(try std.fmt.parseInt(usize, args[8], 10), try std.fmt.parseInt(i32, args[4], 10), try std.fmt.parseInt(i32, args[5], 10));
                observed_codec = &codec;
                codec.write(&writer, data) catch |err| {
                    status = @errorName(err);
                };
            }
            if (observed_path == null) {
                try out.print("{s}|{d}|{x}\n", .{ status, writer.getPos(), output[0..capacity] });
                try out.flush();
                return;
            }
        }
        std.debug.print("UNEXPECTED: operation returned\n", .{});
        return;
    }
    try out.print("H|{d}|{d}|{d}|{d}|{x}|{x}|{x}|{x}\n", .{ @sizeOf(p.BitmapFileHeader), @sizeOf(p.BitmapInfoHeaderWindows31), @sizeOf(p.BitmapInfoHeaderV4), @sizeOf(p.BitmapInfoHeaderV5), std.mem.asBytes(&p.BitmapFileHeader{}), std.mem.asBytes(&p.BitmapInfoHeaderWindows31{}), std.mem.asBytes(&p.BitmapInfoHeaderV4{}), std.mem.asBytes(&p.BitmapInfoHeaderV5{}) });
    for ([_]usize{ 40, 108, 124 }) |kind| {
        for ([_]i32{ -2147483648, -3, 0, 1, 2147483647 }) |width| {
            for ([_]i32{ -2147483648, -2, 0, 2, 2147483647 }) |height| {
                const codec = makeCodec(kind, width, height);
                try out.print("D|{d}|{d}|{d}\n", .{ kind, codec.width(), codec.height() });
            }
        }
        for ([_]u16{ 0, 1, 8, 16, 24, 32, 64, 65535 }) |bits| {
            for (std.meta.tags(p.CompressionMethod)) |compression| {
                var codec = makeCodec(kind, 1, 1);
                switch (codec.info_header) {
                    inline else => |*header| {
                        header.bit_count = bits;
                        header.compression_method = compression;
                    },
                }
                var status: []const u8 = "ok";
                const format = codec.pixelFormat() catch |err| blk: {
                    status = @errorName(err);
                    break :blk Format.invalid;
                };
                try out.print("P|{d}|{d}|{d}|{s}|{d}\n", .{ kind, bits, @intFromEnum(compression), status, @intFromEnum(format) });
            }
        }
    }
    for ([_]usize{ 0, 40, 108, 124 }) |kind| {
        for ([_]Format{ .bgr24, .bgra32, .grayscale8 }) |format| {
            for ([_]usize{ 0, 1, 2, 3, 8, 17 }) |width| {
                for (0..4) |height| {
                    for (0..3) |seed| {
                        for ([_]usize{ 0, 1, 13, 14, 121, 122, 123, 137, 138, 139, 256, 1024 }) |capacity| try writeCase(out, kind, format, width, height, seed, capacity);
                    }
                }
            }
        }
    }
    try out.flush();
}
