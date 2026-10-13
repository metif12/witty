const std = @import("std");
const p = @import("src/color.zig");
const C = @import("src/PixelFormatConverter.zig");
const Image = @import("src/ImageUnmanaged.zig");
const Format = @import("src/pixel_format.zig").PixelFormat;
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_pixels: ?*const p.PixelStorage = null;
var observed_image: ?*const Image = null;
fn snapshot(out: *W) !void {
    const pixels = if (observed_image) |image| image.pixels else observed_pixels.?.*;
    try out.print("{d}|{d}|{x}|", .{ @intFromEnum(std.meta.activeTag(pixels)), pixels.len(), pixels.asBytes() });
    if (pixels.getPalette()) |pal| try out.print("{x}", .{std.mem.sliceAsBytes(pal)}) else try out.writeByte('-');
    if (observed_image) |image| {
        try out.print("|{d}|{d}|{d}|", .{ image.width, image.height, image.animation.loop_count });
        for (image.animation.frames.items) |frame| try out.print("{x}:{x};", .{ std.mem.asBytes(&frame.duration), frame.pixels.asBytes() });
    }
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
fn makePixels(format: Format, count: usize, offset: usize, owned: bool) !p.PixelStorage {
    var pixels = if (format == .float32 and !owned) blk: {
        const length = @max(count, 1) * 16;
        const bytes = try a.alloc(u8, length + 16);
        @memset(bytes, 0);
        const all = try p.PixelStorage.initRawPixels(bytes[offset..][0..length], format);
        break :blk all.slice(0, count);
    } else try p.PixelStorage.init(a, format, count);
    const raw = pixels.asBytes();
    for (raw, 0..) |*byte, i| byte.* = @truncate(i * 37 + 19);
    if (format == .float32) {
        for (0..count * 4) |i| std.mem.writeInt(u32, raw[i * 4 ..][0..4], @bitCast(@as(f32, @floatFromInt((i * 31 + 17) % 257)) / 256.0), .little);
    } else if (format == .bgr555) {
        for (0..count) |i| raw[i * 2 + 1] &= 127;
    } else if (pixels.getPalette()) |pal| {
        pixels.resizePalette(1);
        pal[0] = p.Rgba32.from.rgba(31, 73, 127, 191);
        for (0..count) |i| {
            if (format == .indexed16) std.mem.writeInt(u16, raw[i * 2 ..][0..2], 1, .little) else raw[i] = 1;
        }
    }
    return pixels;
}
fn put(pixels: p.PixelStorage, pixel: usize, channel: usize, bits: u32) void {
    std.mem.writeInt(u32, pixels.asBytes()[(pixel * 4 + channel) * 4 ..][0..4], bits, .little);
}
fn returning(out: *W, pixels: *const p.PixelStorage, destination: Format) !void {
    const result = C.convert(a, pixels, destination) catch |err| {
        try out.print("{s}|{d}|{x}\n", .{ @errorName(err), pixels.len(), pixels.asBytes() });
        return;
    };
    defer result.deinit(a);
    try out.print("ok|{d}|{x}|{x}\n", .{ result.len(), result.asBytes(), pixels.asBytes() });
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    if (args.len > 1) {
        observed_path = args[2];
        const source: Format = @enumFromInt(try std.fmt.parseInt(u32, args[3], 10));
        const destination: Format = @enumFromInt(try std.fmt.parseInt(u32, args[4], 10));
        const count = try std.fmt.parseInt(usize, args[5], 10);
        const offset = try std.fmt.parseInt(usize, args[6], 10);
        const pixels = try makePixels(source, count, offset, std.mem.eql(u8, args[7], "owned"));
        if (source == .float32 and count != 0 and args.len > 8) put(pixels, try std.fmt.parseInt(usize, args[8], 10), try std.fmt.parseInt(usize, args[9], 10), try std.fmt.parseInt(u32, args[10], 10));
        observed_pixels = &pixels;
        if (std.mem.eql(u8, args[1], "--direct")) {
            _ = C.convert(a, &pixels, destination) catch |err| {
                std.debug.print("UNEXPECTED: recoverable {s}\n", .{@errorName(err)});
                return;
            };
        } else {
            var image: Image = .{ .width = 7, .height = 3, .pixels = pixels, .animation = .{ .loop_count = 4 } };
            const frame = try makePixels(.rgb24, 1, 0, true);
            try image.animation.frames.append(a, .{ .pixels = frame, .duration = 0.25 });
            observed_image = &image;
            if (std.mem.eql(u8, args[1], "--image")) image.convert(a, destination) catch |err| {
                std.debug.print("UNEXPECTED: recoverable {s}\n", .{@errorName(err)});
                return;
            } else image.convertNoFree(a, destination) catch |err| {
                std.debug.print("UNEXPECTED: recoverable {s}\n", .{@errorName(err)});
                return;
            };
        }
        std.debug.print("UNEXPECTED: operation returned\n", .{});
        return;
    }
    var buffer: [8192]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&buffer);
    const out = &writer.interface;
    try out.print("V|{d}\n", .{std.simd.suggestVectorLength(u8) orelse 4});
    for ([_]Format{ .rgba32, .bgra32 }) |destination| {
        for (1..18) |count| {
            for (0..8) |seed| {
                const pixels = try makePixels(.float32, count, 0, true);
                defer pixels.deinit(a);
                for (0..count * 4) |i| put(pixels, i / 4, i % 4, @bitCast(@as(f32, @floatFromInt((i * 31 + seed * 17) % 257)) / 256.0));
                try out.print("R|{d}|{d}|{d}|", .{ @intFromEnum(destination), count, seed });
                try returning(out, &pixels, destination);
            }
        }
        const values = [_]f32{ -0.003, 1.003, -0.0, 0.0, 0.5, 1.0, std.math.nan(f32), std.math.floatTrueMin(f32) };
        for (1..18) |count| {
            for (values, 0..) |value, v| {
                for (0..4) |channel| {
                    const pixels = try makePixels(.float32, count, 0, true);
                    defer pixels.deinit(a);
                    for (0..count) |i| put(pixels, i, channel, @bitCast(value));
                    try out.print("B|{d}|{d}|{d}|{d}|", .{ @intFromEnum(destination), count, v, channel });
                    try returning(out, &pixels, destination);
                }
            }
        }
        for ([_]usize{ 1, 2, 3, 5, 6, 7, 9, 10, 11, 13, 14, 15, 17 }) |count| {
            for ([_]f32{ -1, 2, std.math.inf(f32), -std.math.inf(f32), std.math.nan(f32) }, 0..) |value, v| {
                for (0..4) |channel| {
                    const pixels = try makePixels(.float32, count, 0, true);
                    defer pixels.deinit(a);
                    put(pixels, count - 1, channel, @bitCast(value));
                    try out.print("T|{d}|{d}|{d}|{d}|", .{ @intFromEnum(destination), count, v, channel });
                    try returning(out, &pixels, destination);
                }
            }
        }
    }
    for ([_]Format{ .rgba32, .bgra32 }) |source| {
        for (1..18) |count| {
            for (0..8) |seed| {
                const pixels = try makePixels(source, count, 0, true);
                defer pixels.deinit(a);
                for (pixels.asBytes(), 0..) |*byte, i| byte.* = @truncate(i * 73 + seed * 29);
                try out.print("U|{d}|{d}|{d}|", .{ @intFromEnum(source), count, seed });
                try returning(out, &pixels, .float32);
            }
        }
    }
    for ([_]Format{ .float32, .grayscale16, .rgb24, .rgba64, .rgba32, .bgra32 }) |destination| {
        for ([_]usize{ 0, 1, 4 }) |count| {
            for (0..4) |offset| {
                if (offset != 0 and (destination == .rgba32 or destination == .bgra32)) continue;
                const pixels = try makePixels(.float32, count, offset, false);
                try out.print("O|{d}|{d}|{d}|", .{ @intFromEnum(destination), count, offset });
                try returning(out, &pixels, destination);
            }
        }
    }
    try out.flush();
}
