const std = @import("std");
const p = @import("src/color.zig");
const Format = @import("src/pixel_format.zig").PixelFormat;
const a = std.heap.page_allocator;
const W = std.Io.Writer;
const formats = [_]Format{ .invalid, .indexed1, .indexed2, .indexed4, .indexed8, .indexed16, .grayscale1, .grayscale2, .grayscale4, .grayscale8, .grayscale16, .grayscale8Alpha, .grayscale16Alpha, .rgb332, .rgb555, .rgb565, .rgb24, .rgba32, .bgr555, .bgr24, .bgra32, .rgb48, .rgba64, .float32 };
const floats = [_]u32{ 0, 0x80000000, 0x3e800000, 0xbf800000, 0x3f800000, 0x40400000, 0x7f800000, 0xff800000, 0x7fc01234, 0x7fa01234 };
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_pixels: ?*const p.PixelStorage = null;
var observed_iter: ?*const p.PixelStorageIterator = null;
fn paletteBytes(out: *W, pixels: p.PixelStorage) !void {
    if (pixels.getPalette()) |pal| try out.print("{x}", .{std.mem.sliceAsBytes(pal)}) else try out.writeByte('-');
}
fn snapshot(out: *W) !void {
    const pixels = observed_pixels.?.*;
    try out.print("{d}|{d}|{x}|", .{ @intFromEnum(std.meta.activeTag(pixels)), pixels.len(), pixels.asBytes() });
    try paletteBytes(out, pixels);
    if (observed_iter) |iter| try out.print("|{d}|{d}", .{ iter.current_index, iter.end });
}
fn observe(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var buffer: [4096]u8 = undefined;
            var writer = file.writer(&buffer);
            snapshot(&writer.interface) catch {};
            writer.interface.flush() catch {};
        } else |_| {}
    }
    std.debug.defaultPanic(message, address);
}
fn typedPointer(pixels: p.PixelStorage) usize {
    return switch (pixels) {
        .invalid => 0,
        inline else => |data, tag| if (comptime @intFromEnum(tag) <= 16) @intFromPtr(data.indices.ptr) else @intFromPtr(data.ptr),
    };
}
fn makePixels(format: Format, count: usize, seed: usize) !p.PixelStorage {
    var pixels = try p.PixelStorage.init(a, format, count);
    if (format == .invalid) return pixels;
    const raw = pixels.asBytes();
    for (raw, 0..) |*byte, i| byte.* = @truncate(i * 17 + seed * 61);
    if (pixels.getPalette()) |palette| {
        const length = @min(palette.len, 16);
        for (palette[0..length], 0..) |*color, i| color.* = p.Rgba32.from.rgba(@truncate(i * 29 + seed), @truncate(i * 13 + seed * 7), @truncate(i * 11 + seed * 19), @truncate(i * 31 + seed * 17));
        pixels.resizePalette(length);
        const stride = format.pixelStride();
        for (0..count) |i| {
            const value = (i + seed) % length;
            if (stride == 1) raw[i] = @intCast(value) else std.mem.writeInt(u16, raw[i * 2 ..][0..2], @intCast(value), .little);
        }
    } else switch (format) {
        .grayscale1, .grayscale2, .grayscale4 => {
            const mask: u8 = if (format == .grayscale1) 1 else if (format == .grayscale2) 3 else 15;
            for (raw) |*byte| byte.* &= mask;
        },
        .rgb555, .bgr555 => {
            for (0..count) |i| raw[i * 2 + 1] &= 127;
        },
        .float32 => {
            for (0..count * 4) |i| std.mem.writeInt(u32, raw[i * 4 ..][0..4], floats[(i + seed) % floats.len], .little);
        },
        else => {},
    }
    return pixels;
}
fn colors(out: *W, iter: *p.PixelStorageIterator) !void {
    while (iter.next()) |color| try out.print("{x},", .{std.mem.asBytes(&color)});
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    if (args.len > 1) {
        observed_path = args[2];
        const format: Format = @enumFromInt(try std.fmt.parseInt(u32, args[3], 10));
        const count = try std.fmt.parseInt(usize, args[4], 10);
        var pixels = try makePixels(format, count, 1);
        observed_pixels = &pixels;
        if (std.mem.eql(u8, args[1], "--slice")) {
            _ = pixels.slice(try std.fmt.parseInt(usize, args[5], 10), try std.fmt.parseInt(usize, args[6], 10));
        } else {
            var iter = p.PixelStorageIterator.init(&pixels);
            observed_iter = &iter;
            iter.current_index = try std.fmt.parseInt(usize, args[5], 10);
            iter.end = try std.fmt.parseInt(usize, args[6], 10);
            if (std.mem.eql(u8, args[1], "--palette")) pixels.resizePalette(try std.fmt.parseInt(usize, args[7], 10));
            if (std.mem.eql(u8, args[1], "--replace")) {
                // Keep the same storage address and captured end while replacing its variant.
                const old = pixels;
                pixels = try makePixels(.rgb24, 1, 2);
                old.deinit(a);
            }
            _ = iter.next();
        }
        std.debug.print("UNEXPECTED: operation returned\n", .{});
        return;
    }
    var buffer: [8192]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&buffer);
    const out = &writer.interface;
    for (formats) |format| {
        for (0..9) |count| {
            for (0..4) |seed| {
                var pixels = try makePixels(format, count, seed);
                defer pixels.deinit(a);
                for (0..count + 1) |begin| {
                    for (begin..count + 1) |end| {
                        const view = pixels.slice(begin, end);
                        const pointer_ok = format == .invalid or count == 0 or typedPointer(view) == typedPointer(pixels) + begin * format.pixelStride();
                        const palette_ok = if (view.getPalette()) |pal| pal.ptr == pixels.getPalette().?.ptr else true;
                        const raw = view.asBytes();
                        if (raw.len != 0) raw[raw.len - (if (view.isIndexed()) format.pixelStride() else 1)] ^= 1;
                        try out.print("S|{d}|{d}|{d}|{d}|{d}|{d}|{}|{}|{x}|{x}|", .{ @intFromEnum(format), count, seed, begin, end, view.len(), pointer_ok, palette_ok, raw, pixels.asBytes() });
                        var iter = p.PixelStorageIterator.init(&view);
                        try colors(out, &iter);
                        try out.print("|{d}|{d}\n", .{ iter.current_index, iter.end });
                        if (raw.len != 0) raw[raw.len - (if (view.isIndexed()) format.pixelStride() else 1)] ^= 1;
                    }
                }
                // Copies keep independent cursors while borrowing the same live storage.
                var iter = p.PixelStorageIterator.init(&pixels);
                var copied = iter;
                _ = iter.next();
                try out.print("C|{d}|{d}|{d}|{d}|{d}|{}|", .{ @intFromEnum(format), count, seed, iter.current_index, copied.current_index, iter.pixels == copied.pixels });
                try colors(out, &copied);
                try out.print("|{d}|{d}\n", .{ iter.current_index, copied.current_index });
            }
        }
    }
    for (formats) |initial| {
        for (formats) |replacement| {
            for ([_]usize{ 0, 2 }) |start| {
                var pixels = try makePixels(initial, 4, 0);
                var iter = p.PixelStorageIterator.init(&pixels);
                iter.current_index = start;
                const old = pixels;
                pixels = try makePixels(replacement, 8, 2);
                defer pixels.deinit(a);
                old.deinit(a);
                try out.print("L|{d}|{d}|{d}|{d}|", .{ @intFromEnum(initial), @intFromEnum(replacement), start, iter.end });
                try colors(out, &iter);
                try out.print("|{d}|{}\n", .{ iter.current_index, iter.pixels == &pixels });
            }
        }
    }
    for (formats) |format| {
        var pixels = try makePixels(format, 4, 1);
        defer pixels.deinit(a);
        for ([_][2]usize{ .{ 4, 4 }, .{ 5, 4 }, .{ std.math.maxInt(usize), std.math.maxInt(usize) }, .{ std.math.maxInt(usize), 0 }, .{ 0x100000000, 0x80000000 }, .{ 0, 0 } }) |range| {
            var iter = p.PixelStorageIterator.init(&pixels);
            iter.current_index = range[0];
            iter.end = range[1];
            const exhausted = iter.next() == null;
            try out.print("E|{d}|{d}|{d}|{}|{d}\n", .{ @intFromEnum(format), range[0], range[1], exhausted, iter.current_index });
        }
    }
    var invalid: p.PixelStorage = .invalid;
    for ([_]usize{ 0, 1, 0x80000000, 0x100000000, std.math.maxInt(usize) }) |begin| {
        for ([_]usize{ 0, 1, 0x80000000, 0x100000000, std.math.maxInt(usize) }) |end| {
            const view = invalid.slice(begin, end);
            try out.print("B|{d}|{d}|{d}|{d}\n", .{ begin, end, @intFromEnum(std.meta.activeTag(view)), view.len() });
        }
    }
    var defaults: p.PixelStorageIterator = .{};
    try out.print("D|{}|{d}|{d}\n", .{ defaults.next() == null, defaults.current_index, defaults.end });
    defaults.current_index = std.math.maxInt(usize);
    defaults.end = std.math.maxInt(usize);
    try out.print("D|{}|{d}|{d}\n", .{ defaults.next() == null, defaults.current_index, defaults.end });
    var wide = p.PixelStorageIterator.init(&invalid);
    wide.current_index = std.math.maxInt(usize) - 1;
    wide.end = std.math.maxInt(usize);
    try out.writeAll("W|");
    try colors(out, &wide);
    try out.print("|{d}|{d}\n", .{ wide.current_index, wide.end });
    try out.flush();
}
