const std = @import("std");
const p = @import("src/formats/qoi.zig");
const color = @import("src/color.zig");
const Image = @import("src/ImageUnmanaged.zig");
const Format = @import("src/pixel_format.zig").PixelFormat;
const io = @import("src/io.zig");
const a = std.heap.page_allocator;
const W = std.Io.Writer;
const AliasRgb = color.Rgb24;
const AliasRgba = color.Rgba32;
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_codec: ?*const p.QOI = null;
var observed_reader: ?*const io.ReadStream = null;
var observed_data: []const u8 = &.{};
var observed_entry: u8 = 0;
fn state(out: *W) !void {
    if (observed_entry == 3) {
        try out.print("{x}", .{observed_data});
        return;
    }
    try out.print("{d}|", .{observed_reader.?.getPos()});
    if (observed_entry == 0) try out.print("{x}", .{std.mem.asBytes(&observed_codec.?.header)}) else try out.writeByte('-');
    try out.print("|{x}", .{observed_data});
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
fn sample(i: usize, pattern: usize) p.QoiColor {
    const values = [_]u8{ 0, 1, 126, 127, 128, 254, 255 };
    const colors = [_]p.QoiColor{ .{ .r = 10, .g = 20, .b = 30 }, .{ .r = 11, .g = 21, .b = 31 }, .{ .r = 14, .g = 23, .b = 32 }, .{ .r = 100, .g = 150, .b = 200, .a = 50 }, .{ .r = 0, .g = 0, .b = 0, .a = 0 } };
    return switch (pattern) {
        0 => .{ .r = 0, .g = 0, .b = 0 },
        1 => .{ .r = @truncate(i * 37 + 19), .g = @truncate(i * 71 + 53), .b = @truncate(i * 97 + 11), .a = @truncate(i * 13 + 29) },
        2 => .{ .r = @intCast(128 + i % 20), .g = @intCast(127 + i % 20), .b = @intCast(126 + i % 20) },
        3 => .{ .r = values[i % 7], .g = values[(i + 2) % 7], .b = values[(i + 4) % 7], .a = values[(i + 6) % 7] },
        4 => .{ .r = @intCast((i / 62) % 2), .g = @intCast((i / 62) % 2), .b = @intCast((i / 62) % 2) },
        else => colors[i % colors.len],
    };
}
fn makePixels(format: Format, count: usize, pattern: usize) !color.PixelStorage {
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
        .rgb24 => for (pixels.rgb24, 0..) |*pixel, i| {
            pixel.* = sample(i, pattern).toRgb24();
        },
        .rgba32 => for (pixels.rgba32, 0..) |*pixel, i| {
            pixel.* = sample(i, pattern).toRgba32();
        },
        else => {},
    }
    return pixels;
}
fn readCase(entry: u8, start: usize, data: []const u8, out: *W) !void {
    var reader = io.ReadStream.initMemory(data);
    if (start > 0) _ = try reader.reader().take(start);
    var codec = p.QOI{ .header = .{ .width = 7, .height = 9, .format = .rgba, .colorspace = .linear } };
    observed_reader = &reader;
    observed_codec = &codec;
    observed_data = data;
    observed_entry = entry;
    if (entry == 2) {
        var status: []const u8 = "ok";
        const result = p.QOI.formatDetect(&reader) catch |err| blk: {
            status = @errorName(err);
            break :blk false;
        };
        try out.print("{s}|{d}|{d}|{x}\n", .{ status, @intFromBool(result), reader.getPos(), data });
        return;
    }
    const result = if (entry == 0) blk: {
        const pixels = codec.read(a, &reader) catch |err| {
            try out.print("{s}|", .{@errorName(err)});
            try state(out);
            try out.writeByte('\n');
            return;
        };
        break :blk Image{ .width = codec.width(), .height = codec.height(), .pixels = pixels };
    } else p.QOI.readImage(a, &reader) catch |err| {
        try out.print("{s}|", .{@errorName(err)});
        try state(out);
        try out.writeByte('\n');
        return;
    };
    defer result.pixels.deinit(a);
    try out.writeAll("ok|");
    try state(out);
    const raw = result.pixels.asBytes();
    try out.print("|{d}|{d}|{d}|{d}|{x}|", .{ result.width, result.height, @intFromEnum(std.meta.activeTag(result.pixels)), result.pixels.len(), raw });
    if (raw.len > 0) {
        const pointer = @intFromPtr(raw.ptr);
        try out.print("{d}", .{@intFromBool(pointer < @intFromPtr(data.ptr) or pointer >= @intFromPtr(data.ptr) + data.len)});
        raw[0] ^= 255;
    } else try out.writeByte('-');
    try out.print("|{x}\n", .{raw});
}
fn writeCase(format: Format, count: usize, pattern: usize, width: usize, height: usize, space: p.Colorspace, capacity: usize, entry: usize, out: *W) !void {
    const pixels = try makePixels(format, count, pattern);
    defer pixels.deinit(a);
    const codec = p.QOI{ .header = .{ .width = @truncate(width), .height = @truncate(height), .format = .rgba, .colorspace = space } };
    var buffer: [1024]u8 = @splat(165);
    var writer = io.WriteStream.initMemory(buffer[0..capacity]);
    const image = Image{ .width = width, .height = height, .pixels = pixels };
    var status: []const u8 = "ok";
    if (entry == 0) {
        codec.write(&writer, pixels) catch |err| {
            status = @errorName(err);
        };
    } else {
        p.QOI.writeImage(a, &writer, image, if (entry == 1) .{ .qoi = .{ .colorspace = space } } else .{ .farbfeld = {} }) catch |err| {
            status = @errorName(err);
        };
    }
    try out.print("W|{d}|{d}|{d}|{d}|{d}|{d}|{d}|{d}|{s}|{d}|{x}|{x}\n", .{ @intFromEnum(format), count, pattern, width, height, @intFromEnum(space), capacity, entry, status, writer.getPos(), buffer[0..capacity], pixels.asBytes() });
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    var bytes: [8192]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&bytes);
    const out = &writer.interface;
    if (args.len > 1) {
        if (std.mem.eql(u8, args[1], "--corpus")) {
            const text = try std.fs.cwd().readFileAlloc(a, args[2], 1073741824);
            defer a.free(text);
            var lines = std.mem.splitScalar(u8, text, '\n');
            while (lines.next()) |line| {
                if (line.len == 0) continue;
                var fields = std.mem.splitScalar(u8, line, '|');
                const entry = try std.fmt.parseInt(u8, fields.next().?, 10);
                const start = try std.fmt.parseInt(usize, fields.next().?, 10);
                const hex = fields.next().?;
                const data = try a.alloc(u8, hex.len / 2);
                defer a.free(data);
                _ = try std.fmt.hexToBytes(data, hex);
                try readCase(entry, start, data, out);
            }
            try out.flush();
            return;
        }
        observed_path = args[2];
        if (std.mem.eql(u8, args[1], "--read")) {
            const data = try std.fs.cwd().readFileAlloc(a, args[5], 65536);
            try readCase(try std.fmt.parseInt(u8, args[3], 10), try std.fmt.parseInt(usize, args[4], 10), data, out);
        } else {
            observed_entry = 3;
            const kind = args[3];
            if (std.mem.eql(u8, kind, "int")) {
                const value: i32 = 7;
                observed_data = std.mem.asBytes(&value);
                _ = p.QoiColor.from(value);
            } else if (std.mem.eql(u8, kind, "color")) {
                const value = p.QoiColor{ .r = 1, .g = 2, .b = 3, .a = 4 };
                observed_data = std.mem.asBytes(&value);
                _ = p.QoiColor.from(value);
            } else if (std.mem.eql(u8, kind, "rgb48")) {
                const value = color.Rgb48{ .r = 1, .g = 2, .b = 3 };
                observed_data = std.mem.asBytes(&value);
                _ = p.QoiColor.from(value);
            } else if (std.mem.eql(u8, kind, "pointer")) {
                const value = color.Rgb24{ .r = 1, .g = 2, .b = 3 };
                observed_data = std.mem.asBytes(&value);
                _ = p.QoiColor.from(&value);
            } else {
                const value = true;
                observed_data = std.mem.asBytes(&value);
                _ = p.QoiColor.from(value);
            }
            std.debug.print("UNEXPECTED: factory returned\n", .{});
        }
        try out.flush();
        return;
    }
    for (0..256) |r| for ([_]u8{ 0, 1, 127, 128, 254, 255 }) |g| for ([_]u8{ 0, 1, 127, 128, 254, 255 }) |b| for ([_]u8{ 0, 1, 127, 255 }) |alpha| {
        const c = p.QoiColor{ .r = @intCast(r), .g = g, .b = b, .a = alpha };
        var other = c;
        other.a ^= 255;
        const rgb = p.QoiColor.from(c.toRgb24());
        const rgba = p.QoiColor.from(c.toRgba32());
        try out.print("C|{x}|{d}|{d}|{x}|{x}\n", .{ std.mem.asBytes(&c), @intFromBool(c.eql(c)), @intFromBool(c.eql(other)), std.mem.asBytes(&rgb), std.mem.asBytes(&rgba) });
    };
    const alias_rgb = p.QoiColor.from(AliasRgb{ .r = 1, .g = 2, .b = 3 });
    const alias_rgba = p.QoiColor.from(AliasRgba{ .r = 1, .g = 2, .b = 3, .a = 4 });
    try out.print("A|{x}|{x}\n", .{ std.mem.asBytes(&alias_rgb), std.mem.asBytes(&alias_rgba) });
    var options = p.QOI.EncoderOptions{};
    const copy = options;
    options.colorspace = .linear;
    try out.print("O|{d}|{d}\nS|{d}|{d}\n", .{ @intFromEnum(copy.colorspace), @intFromEnum(options.colorspace), @sizeOf(p.QoiColor), @sizeOf(p.Header) });
    for ([_]u32{ 0, 1, 2, 0x80000000, 0xffffffff }) |width| for ([_]u32{ 0, 1, 2, 0x80000000, 0xffffffff }) |height| for (std.meta.tags(p.Format)) |format| for (std.meta.tags(p.Colorspace)) |space| {
        const codec = p.QOI{ .header = .{ .width = width, .height = height, .format = format, .colorspace = space } };
        var changed = codec;
        changed.header.width ^= 0x12345678;
        changed.header.height ^= 0x87654321;
        try out.print("H|{x}|{d}|{d}|{d}|{x}\n", .{ std.mem.asBytes(&codec.header), codec.width(), codec.height(), @intFromEnum(try codec.pixelFormat()), std.mem.asBytes(&changed.header) });
    };
    for (std.meta.tags(Format)) |format| for (0..3) |count| for ([_][2]usize{ .{ 0, 0 }, .{ 1, 2 }, .{ 0xffffffff, 0 }, .{ 0x100000001, 0x100000002 }, .{ 0xffffffffffffffff, 0xffffffffffffffff } }) |dim| for (std.meta.tags(p.Colorspace)) |space| for ([_]usize{ 0, 3, 4, 13, 14, 15, 21, 22, 23, 32 }) |capacity| for (0..3) |entry| {
        try writeCase(format, count, 1, dim[0], dim[1], space, capacity, entry, out);
    };
    for ([_]Format{ .rgb24, .rgba32 }) |format| for ([_]usize{ 0, 1, 2, 3, 61, 62, 63, 64, 124, 125 }) |count| for (0..6) |pattern| for (std.meta.tags(p.Colorspace)) |space| for ([_]usize{ 0, 14, 15, 16, 17, 21, 22, 23, 31, 32, 64, 256, 1024 }) |capacity| for (0..2) |entry| {
        try writeCase(format, count, pattern, 1, count, space, capacity, entry, out);
    };
    try out.flush();
}
