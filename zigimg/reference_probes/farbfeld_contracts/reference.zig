const std = @import("std");
const p = @import("src/formats/farbfeld.zig");
const color = @import("src/color.zig");
const Image = @import("src/ImageUnmanaged.zig");
const Format = @import("src/pixel_format.zig").PixelFormat;
const io = @import("src/io.zig");
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_image: ?*const Image = null;
var observed_writer: ?*const io.WriteStream = null;
var observed_buffer: []const u8 = &.{};

fn state(out: *W) !void {
    const image = observed_image.?.*;
    try out.print("{d}|{d}|{d}|{d}|{x}|{d}|{x}", .{ image.width, image.height, @intFromEnum(std.meta.activeTag(image.pixels)), image.pixels.len(), image.pixels.asBytes(), observed_writer.?.getPos(), observed_buffer });
}
fn observe(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var bytes: [4096]u8 = undefined;
            var writer = file.writer(&bytes);
            state(&writer.interface) catch {};
            writer.interface.flush() catch {};
        } else |_| {}
    }
    std.debug.defaultPanic(message, address);
}
fn makePixels(format: Format, count: usize) !color.PixelStorage {
    var pixels = try color.PixelStorage.init(a, format, count);
    const raw = pixels.asBytes();
    for (raw, 0..) |*byte, i| byte.* = @truncate(i * 37 + 19);
    switch (format) {
        .indexed1, .indexed2, .indexed4, .grayscale1, .grayscale2, .grayscale4 => {
            const mask: u8 = if (format == .indexed1 or format == .grayscale1) 1 else if (format == .indexed2 or format == .grayscale2) 3 else 15;
            for (raw) |*byte| byte.* &= mask;
        },
        .rgb555, .bgr555 => for (0..count) |i| {
            raw[i * 2 + 1] &= 127;
        },
        else => {},
    }
    return pixels;
}
fn readCase(args: []const []const u8, out: *W) !void {
    const entry = try std.fmt.parseInt(u8, args[2], 10);
    const start = try std.fmt.parseInt(u64, args[3], 10);
    const data = try std.fs.cwd().readFileAlloc(a, args[4], 1048576);
    defer a.free(data);
    var reader = io.ReadStream.initMemory(data);
    if (start > 0) _ = try reader.reader().take(@intCast(start));
    if (entry == 2) {
        var status: []const u8 = "ok";
        const result = p.Farbfeld.formatDetect(&reader) catch |err| blk: {
            status = @errorName(err);
            break :blk false;
        };
        try out.print("{s}|{d}|{d}|{x}\n", .{ status, @intFromBool(result), reader.getPos(), data });
        return;
    }
    var codec = p.Farbfeld{ .header = .{ .width = 7, .height = 9 } };
    const result = if (entry == 0) blk: {
        const pixels = codec.read(a, &reader) catch |err| {
            try out.print("{s}|{d}|{x}|{x}\n", .{ @errorName(err), reader.getPos(), std.mem.asBytes(&codec.header), data });
            return;
        };
        break :blk Image{ .width = codec.header.width, .height = codec.header.height, .pixels = pixels };
    } else p.Farbfeld.readImage(a, &reader) catch |err| {
        try out.print("{s}|{d}|-|{x}\n", .{ @errorName(err), reader.getPos(), data });
        return;
    };
    defer result.pixels.deinit(a);
    try out.print("ok|{d}|", .{reader.getPos()});
    if (entry == 0) try out.print("{x}", .{std.mem.asBytes(&codec.header)}) else try out.writeByte('-');
    const raw = result.pixels.asBytes();
    try out.print("|{d}|{d}|{d}|{d}|{x}|", .{ result.width, result.height, @intFromEnum(std.meta.activeTag(result.pixels)), result.pixels.len(), raw });
    if (raw.len > 0) {
        const pointer = @intFromPtr(raw.ptr);
        const separate = pointer < @intFromPtr(data.ptr) or pointer >= @intFromPtr(data.ptr) + data.len;
        try out.print("{d}", .{@intFromBool(separate)});
        raw[0] ^= 255;
    } else try out.writeByte('-');
    try out.print("|{x}|{x}\n", .{ raw, data });
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    var bytes: [8192]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&bytes);
    const out = &writer.interface;
    if (args.len > 1) {
        if (std.mem.eql(u8, args[1], "--read")) {
            try readCase(args, out);
            try out.flush();
            return;
        }
        observed_path = args[2];
        const image = Image{ .width = try std.fmt.parseInt(usize, args[3], 10), .height = try std.fmt.parseInt(usize, args[4], 10), .pixels = try makePixels(@enumFromInt(try std.fmt.parseInt(u32, args[5], 10)), 2) };
        var buffer: [64]u8 = @splat(165);
        const capacity = try std.fmt.parseInt(usize, args[6], 10);
        var stream = io.WriteStream.initMemory(buffer[0..capacity]);
        const start = try std.fmt.parseInt(u64, args[7], 10);
        if (start > 0) try stream.seekTo(start);
        observed_image = &image;
        observed_writer = &stream;
        observed_buffer = buffer[0..capacity];
        p.Farbfeld.writeImage(a, &stream, image, .{ .farbfeld = {} }) catch |err| {
            try out.print("{s}|", .{@errorName(err)});
            try state(out);
            try out.writeByte('\n');
            try out.flush();
            return;
        };
        try out.writeAll("ok|");
        try state(out);
        try out.writeByte('\n');
        try out.flush();
        return;
    }
    try out.print("H|{d}|{x}|{x}\n", .{ @sizeOf(p.Header), std.mem.asBytes(&p.Header{}), std.mem.asBytes(&(p.Farbfeld{}).header) });
    for ([_]u32{ 0, 1, 2, 0x80000000, 0xffffffff }) |width| for ([_]u32{ 0, 1, 2, 0x80000000, 0xffffffff }) |height| {
        const codec = p.Farbfeld{ .header = .{ .width = width, .height = height } };
        var copy = codec;
        copy.header.width ^= 0x12345678;
        copy.header.height ^= 0x87654321;
        try out.print("H|{x}|{x}\n", .{ std.mem.asBytes(&codec.header), std.mem.asBytes(&copy.header) });
    };
    for (std.meta.tags(Format)) |format| for (0..3) |count| {
        const pixels = try makePixels(format, count);
        defer pixels.deinit(a);
        for ([_]u32{ 0, 1, 2, 0x80000000, 0xffffffff }) |width| for ([_]u32{ 0, 1, 2, 0x80000000, 0xffffffff }) |height| {
            const codec = p.Farbfeld{ .header = .{ .width = width, .height = height } };
            for ([_]usize{ 0, 1, 7, 8, 15, 16, 17, 23, 24, 31, 32, 33 }) |capacity| for (0..2) |entry| {
                var buffer: [33]u8 = @splat(165);
                var stream = io.WriteStream.initMemory(buffer[0..capacity]);
                var status: []const u8 = "ok";
                if (entry == 0) {
                    codec.write(&stream, pixels) catch |err| {
                        status = @errorName(err);
                    };
                } else {
                    p.Farbfeld.writeImage(a, &stream, .{ .width = width, .height = height, .pixels = pixels }, .{ .farbfeld = {} }) catch |err| {
                        status = @errorName(err);
                    };
                }
                try out.print("W|{d}|{d}|{d}|{d}|{d}|{d}|{s}|{d}|{x}|{x}|{x}\n", .{ @intFromEnum(format), count, width, height, capacity, entry, status, stream.getPos(), buffer[0..capacity], std.mem.asBytes(&codec.header), pixels.asBytes() });
            };
        };
    };
    try out.flush();
}
