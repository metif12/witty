const std = @import("std");
const E = @import("src/ImageEditor.zig");
const p = @import("src/color.zig");
const I = @import("src/ImageUnmanaged.zig");
const Format = @import("src/pixel_format.zig").PixelFormat;
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_image: ?*const I = null;
var observed_box: ?*const E.Box = null;
fn pixelState(out: *W, pixels: p.PixelStorage) !void {
    try out.print("{d}|{d}|{x}|", .{ @intFromEnum(std.meta.activeTag(pixels)), pixels.len(), pixels.asBytes() });
    if (pixels.getPalette()) |pal| try out.print("{x}", .{std.mem.sliceAsBytes(pal)}) else try out.writeByte('-');
}
fn imageState(out: *W, image: I) !void {
    try out.print("{d}|{d}|", .{ image.width, image.height });
    try pixelState(out, image.pixels);
    try out.print("|{d}|{d}", .{ image.animation.loop_count, image.animation.frames.items.len });
    for (image.animation.frames.items) |frame| {
        try out.print("|{x}|", .{std.mem.asBytes(&frame.duration)});
        try pixelState(out, frame.pixels);
    }
}
fn boxState(out: *W, box: E.Box) !void {
    try out.print("{d}|{d}|{d}|{d}", .{ box.x, box.y, box.width, box.height });
}
fn observe(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var buffer: [4096]u8 = undefined;
            var writer = file.writer(&buffer);
            if (observed_image) |image| imageState(&writer.interface, image.*) catch {};
            if (observed_box) |box| {
                writer.interface.writeByte('|') catch {};
                boxState(&writer.interface, box.*) catch {};
            }
            writer.interface.flush() catch {};
        } else |_| {}
    }
    std.debug.defaultPanic(message, address);
}
fn makePixels(format: Format, count: usize, seed: usize) !p.PixelStorage {
    var result = try p.PixelStorage.init(a, format, count);
    const raw = result.asBytes();
    for (raw, 0..) |*byte, i| byte.* = @truncate(i * 37 + seed * 19);
    switch (format) {
        .indexed1, .grayscale1 => for (raw) |*byte| {
            byte.* &= 1;
        },
        .indexed2, .grayscale2 => for (raw) |*byte| {
            byte.* &= 3;
        },
        .indexed4, .grayscale4 => for (raw) |*byte| {
            byte.* &= 15;
        },
        .rgb555, .bgr555 => for (0..count) |i| {
            raw[i * 2 + 1] &= 127;
        },
        else => {},
    }
    if (result.getPalette()) |pal| {
        const length = @min(pal.len, 4);
        result.resizePalette(length);
        for (pal[0..length], 0..) |*entry, i| entry.* = p.Rgba32.from.rgba(@truncate(i * 31 + seed), @truncate(i * 71), @truncate(i * 113), @truncate(i * 47));
    }
    return result;
}
fn makeImage(format: Format, count: usize, width: usize, height: usize, seed: usize) !I {
    var image = I{ .width = width, .height = height, .pixels = try makePixels(format, count, seed), .animation = .{ .loop_count = 4 } };
    try image.animation.frames.append(a, .{ .pixels = image.pixels, .duration = 0.25 });
    try image.animation.frames.append(a, .{ .pixels = try makePixels(.rgba32, 2, 9), .duration = 0.5 });
    return image;
}
fn flip(image: *const I, api: usize) !void {
    if (api == 0) try E.flipVertically(&image.pixels, image.height, a) else if (api == 1) try image.flipVertically(a) else {
        const managed = image.toManaged(a);
        try managed.flipVertically();
    }
}
fn crop(image: *const I, box: E.Box, api: usize) !I {
    if (api == 0) return E.crop(image, a, box);
    if (api == 1) return image.crop(a, box);
    const managed = image.toManaged(a);
    return (try managed.crop(a, box)).toUnmanaged();
}
fn flipReturns(length: usize, height: usize) bool {
    const row = length / height;
    if (row == 0) return length == 0;
    var remaining = length;
    while (remaining > row) {
        if (row > remaining - row) return false;
        remaining -= row * 2;
    }
    return true;
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    var buffer: [8192]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&buffer);
    const out = &writer.interface;
    if (args.len > 1) {
        if (!std.mem.eql(u8, args[2], "-")) observed_path = args[2];
        const api = try std.fmt.parseInt(usize, args[3], 10);
        const format: Format = @enumFromInt(try std.fmt.parseInt(u32, args[4], 10));
        const count = try std.fmt.parseInt(usize, args[5], 10);
        const width = try std.fmt.parseInt(usize, args[6], 10);
        const height = try std.fmt.parseInt(usize, args[7], 10);
        var image = try makeImage(format, count, width, height, 1);
        defer image.deinit(a);
        observed_image = &image;
        if (std.mem.eql(u8, args[1], "--row")) {
            _ = if (api == 1) image.rowByteSize() else image.toManaged(a).rowByteSize();
        } else if (std.mem.eql(u8, args[1], "--flip")) {
            try flip(&image, api);
        } else {
            const box = E.Box{ .x = try std.fmt.parseInt(usize, args[8], 10), .y = try std.fmt.parseInt(usize, args[9], 10), .width = try std.fmt.parseInt(usize, args[10], 10), .height = try std.fmt.parseInt(usize, args[11], 10) };
            observed_box = &box;
            if (std.mem.eql(u8, args[1], "--clamp")) {
                const result = box.clamp(width, height);
                if (observed_path == null) {
                    try boxState(out, result);
                    try out.writeByte('\n');
                    try out.flush();
                    return;
                }
            } else {
                var result = try crop(&image, box, api);
                defer result.deinit(a);
                if (observed_path == null) {
                    try imageState(out, result);
                    try out.writeByte('|');
                    try imageState(out, image);
                    try out.writeByte('\n');
                    try out.flush();
                    return;
                }
            }
        }
        std.debug.print("UNEXPECTED: operation returned\n", .{});
        return;
    }
    const original = E.Box{};
    var copied = original;
    copied.x = std.math.maxInt(usize);
    copied.height = 9;
    try out.writeAll("H|");
    try boxState(out, original);
    try out.writeByte('|');
    try boxState(out, copied);
    try out.writeByte('\n');
    for (0..5) |width| for (0..5) |height| {
        for (0..width + 1) |x| for (0..height + 1) |y| {
            for (0..6) |w| for (0..6) |h| {
                const box = E.Box{ .x = x, .y = y, .width = w, .height = h };
                try out.print("B|{d}|{d}|", .{ width, height });
                try boxState(out, box);
                try out.writeByte('|');
                try boxState(out, box.clamp(width, height));
                try out.writeByte('\n');
            };
        };
    };
    for (std.meta.tags(Format)) |format| {
        for (0..10) |count| {
            for (1..14) |v| {
                const height = if (v == 13) std.math.maxInt(usize) else v;
                var image = try makeImage(format, count, 99, height, 1);
                defer image.deinit(a);
                try out.print("R|{d}|{d}|{d}|{d}|{d}|", .{ @intFromEnum(format), count, height, image.rowByteSize(), image.toManaged(a).rowByteSize() });
                try imageState(out, image);
                try out.writeByte('\n');
            }
            for (1..9) |height| {
                if (!flipReturns(count * format.pixelStride(), height)) continue;
                for (0..3) |seed| for (0..3) |api| {
                    var image = try makeImage(format, count, 99, height, seed);
                    defer image.deinit(a);
                    try out.print("F|{d}|{d}|{d}|{d}|{d}|", .{ @intFromEnum(format), count, height, seed, api });
                    try flip(&image, api);
                    try imageState(out, image);
                    try out.writeByte('|');
                    try flip(&image, api);
                    try imageState(out, image);
                    try out.writeByte('\n');
                };
            }
        }
        if (format == .invalid) continue;
        for (0..4) |width| for (0..4) |height| {
            const boxes = [_]E.Box{
                .{},                                                           .{ .width = width, .height = height },                                                                        .{ .x = width, .y = height, .width = 1, .height = 1 },
                .{ .x = width / 2, .y = height / 2, .width = 5, .height = 5 }, .{ .width = 1, .height = 1 },                                                                                 .{ .x = width, .width = 1, .height = 5 },
                .{ .y = height, .width = 5, .height = 1 },                     .{ .x = if (width == 0) 0 else width - 1, .y = if (height == 0) 0 else height - 1, .width = 5, .height = 5 },
            };
            for (boxes, 0..) |box, b| for (0..2) |seed| for (0..3) |api| {
                var image = try makeImage(format, width * height, width, height, seed);
                defer image.deinit(a);
                var result = try crop(&image, box, api);
                defer result.deinit(a);
                try out.print("C|{d}|{d}|{d}|{d}|{d}|{d}|", .{ @intFromEnum(format), width, height, b, seed, api });
                try imageState(out, result);
                if (result.rawBytes().len != 0) {
                    try out.print("|{}", .{result.rawBytes().ptr != image.rawBytes().ptr});
                    result.pixels.asBytes()[0] ^= 1;
                } else try out.writeAll("|-");
                if (result.pixels.getPalette()) |pal| {
                    try out.print("|{}", .{pal.ptr != image.pixels.getPalette().?.ptr});
                    pal[0].r ^= 1;
                } else try out.writeAll("|-");
                try out.writeByte('|');
                try imageState(out, image);
                try out.writeByte('|');
                try imageState(out, result);
                try out.writeByte('\n');
            };
        };
    }
    try out.flush();
}
