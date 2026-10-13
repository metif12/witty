const std = @import("std");
const p = @import("src/color.zig");
const PixelFormat = @import("src/pixel_format.zig").PixelFormat;
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_len: ?*const usize = null;
var observed_bytes: []const u8 = &.{};
fn observe(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var buffer: [1024]u8 = undefined;
            var writer = file.writer(&buffer);
            const out = &writer.interface;
            if (observed_len) |len| out.print("{d}|", .{len.*}) catch {} else out.writeAll("-|") catch {};
            out.print("{x}", .{observed_bytes}) catch {};
            out.flush() catch {};
        } else |_| {}
    }
    std.debug.defaultPanic(message, address);
}
fn aligned(format: PixelFormat) bool {
    return switch (format) {
        .grayscale16Alpha, .rgb555, .rgb565, .bgr555 => true,
        else => false,
    };
}
fn supported(format: PixelFormat) bool {
    return switch (format) {
        .invalid, .indexed1, .indexed2, .indexed4, .indexed8, .indexed16, .grayscale16 => false,
        else => true,
    };
}
fn typedPointer(storage: p.PixelStorage) usize {
    return switch (storage) {
        inline else => |data, tag| if (comptime tag == .invalid) 0 else if (comptime @intFromEnum(tag) <= 16) @intFromPtr(data.indices.ptr) else @intFromPtr(data.ptr),
    };
}
fn indexed(comptime bits: u16, out: *W) !void {
    const T = std.meta.Int(.unsigned, bits);
    const S = p.IndexedStorage(T);
    const cap = S.PaletteSize;
    const sizes: ?[]const usize = if (bits == 16) &[_]usize{ 0, 1, 2, 15, 16, 255, 256, 32767, 65535, 65536 } else null;
    const size_count = if (sizes) |list| list.len else cap + 1;
    for (0..size_count) |step| {
        const size = if (sizes) |list| list[step] else step;
        for ([_]usize{ 0, 1, 7, 31 }) |count| {
            var x = try S.initPaletteSize(a, count, size);
            defer x.deinit(a);
            var black = true;
            for (x.palette) |color| {
                black = black and color.r == 0 and color.g == 0 and color.b == 0 and color.a == 255;
            }
            for (x.indices, 0..) |*value, i| value.* = @intCast(i % cap);
            try out.print("I|{d}|{d}|{d}|{d}|{}|{x}\n", .{ bits, size, count, x.palette.len, black, std.mem.sliceAsBytes(x.indices) });
        }
    }
    var x = try S.init(a, 7);
    defer x.deinit(a);
    for (x.palette, 0..) |*color, i| color.* = p.Rgba32.from.rgba(@truncate(i), @truncate(i >> 8), @truncate(i * 7), 255);
    for (x.indices, 0..) |*value, i| value.* = @intCast(i % cap);
    const copied = x;
    const original = x.palette.ptr;
    for ([_]usize{ 0, 1, cap / 2, cap - 1, cap }) |size| {
        x.resizePalette(size);
        var storage: p.PixelStorage = @unionInit(p.PixelStorage, std.fmt.comptimePrint("indexed{d}", .{bits}), x);
        storage.resizePalette(size);
        const sub = storage.slice(1, 6);
        const pal = sub.getPalette().?;
        if (pal.len != 0) pal[0] = p.Rgba32.from.rgba(9, 8, 7, 6);
        try out.print("R|{d}|{d}|{d}|{}|{d}|{}|{x}|{x}\n", .{ bits, size, copied.palette.len, x.palette.ptr == original, sub.len(), pal.ptr == original, std.mem.sliceAsBytes(copied.palette[0..1]), sub.asBytes() });
    }
}
fn indexedTrap(comptime bits: u16, mode: []const u8, size: usize) !void {
    const S = p.IndexedStorage(std.meta.Int(.unsigned, bits));
    if (std.mem.eql(u8, mode, "--init")) {
        _ = try S.initPaletteSize(a, 7, size);
    } else {
        var x = try S.init(a, 7);
        observed_len = &x.palette.len;
        observed_bytes = std.mem.sliceAsBytes(x.palette[0..2]);
        if (std.mem.eql(u8, mode, "--resize")) x.resizePalette(size) else {
            var storage: p.PixelStorage = @unionInit(p.PixelStorage, std.fmt.comptimePrint("indexed{d}", .{bits}), x);
            observed_len = &@field(storage, std.fmt.comptimePrint("indexed{d}", .{bits})).palette.len;
            storage.resizePalette(size);
        }
    }
    std.debug.print("UNEXPECTED: indexed operation returned\n", .{});
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    if (args.len > 1) {
        if (std.mem.eql(u8, args[1], "--boxed")) {
            const bits = try std.fmt.parseInt(u16, args[2], 10);
            var buffer: [1024]u8 = undefined;
            var writer = std.fs.File.stdout().writer(&buffer);
            const out = &writer.interface;
            inline for (.{ 1, 2, 4, 8, 16 }) |b| {
                if (bits == b) {
                    var storage = try p.PixelStorage.init(a, @enumFromInt(b), 7);
                    const copied = storage;
                    storage.resizePalette(1);
                    try out.print("{d}|{d}\n", .{ storage.getPalette().?.len, copied.getPalette().?.len });
                }
            }
            try out.flush();
            return;
        }
        observed_path = args[2];
        if (std.mem.eql(u8, args[1], "--raw")) {
            var bytes: [64]u8 align(16) = @splat(165);
            observed_bytes = &bytes;
            const format: PixelFormat = @enumFromInt(try std.fmt.parseInt(u32, args[3], 10));
            const offset = try std.fmt.parseInt(usize, args[4], 10);
            const len = try std.fmt.parseInt(usize, args[5], 10);
            _ = try p.PixelStorage.initRawPixels(bytes[offset..][0..len], format);
            std.debug.print("UNEXPECTED: raw operation returned\n", .{});
        } else {
            const bits = try std.fmt.parseInt(u16, args[3], 10);
            const size = try std.fmt.parseInt(usize, args[4], 10);
            inline for (.{ 1, 2, 4, 8, 16 }) |b| {
                if (bits == b) try indexedTrap(b, args[1], size);
            }
        }
        return;
    }
    var buffer: [8192]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&buffer);
    const out = &writer.interface;
    inline for (.{ 1, 2, 4, 8, 16 }) |bits| try indexed(bits, out);
    const formats = [_]PixelFormat{ .invalid, .indexed1, .indexed2, .indexed4, .indexed8, .indexed16, .grayscale1, .grayscale2, .grayscale4, .grayscale8, .grayscale16, .grayscale8Alpha, .grayscale16Alpha, .rgb332, .rgb555, .rgb565, .rgb24, .rgba32, .bgr555, .bgr24, .bgra32, .rgb48, .rgba64, .float32 };
    for (formats) |format| {
        for (0..4) |offset| {
            for (0..9) |count| {
                for (0..4) |seed| {
                    if (supported(format) and count != 0 and aligned(format) and offset % 2 != 0) continue;
                    var bytes: [160]u8 align(16) = undefined;
                    for (&bytes, 0..) |*byte, i| byte.* = @truncate(i * 17 + seed * 61);
                    const stride = if (supported(format)) format.pixelStride() else 1;
                    const input = bytes[offset..][0 .. count * stride];
                    const result = p.PixelStorage.initRawPixels(input, format) catch |err| {
                        try out.print("E|{d}|{d}|{d}|{d}|{s}\n", .{ @intFromEnum(format), offset, count, seed, @errorName(err) });
                        continue;
                    };
                    // Source empty slice pointers are undefined, so observe only lengths.
                    const pointer_ok = count == 0 or typedPointer(result) == @intFromPtr(input.ptr);
                    const raw = result.asBytes();
                    if (raw.len != 0) raw[raw.len - 1] = @truncate(seed + 97);
                    const sub = result.slice(count / 2, count);
                    try out.print("B|{d}|{d}|{d}|{d}|{d}|{}|{x}|{x}|{x}\n", .{ @intFromEnum(format), offset, count, seed, result.len(), pointer_ok, raw, input, sub.asBytes() });
                }
            }
        }
    }
    try out.flush();
}
