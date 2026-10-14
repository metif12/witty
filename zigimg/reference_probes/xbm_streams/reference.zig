const std = @import("std");
const p = @import("src/formats/xbm.zig").XBM;
const Image = @import("src/ImageUnmanaged.zig");
const color = @import("src/color.zig");
const io = @import("src/io.zig");
const a = std.heap.page_allocator;
const W = std.Io.Writer;

fn pixelsText(out: *W, pixels: color.PixelStorage) !void {
    try out.print("{d}:{d}:{x}:{x}", .{ @intFromEnum(std.meta.activeTag(pixels)), pixels.len(), pixels.asBytes(), std.mem.sliceAsBytes(pixels.getPalette().?) });
}
fn snapshot(out: *W, reader: *io.ReadStream, codec: p, direct: bool, buffer: []const u8, data: []const u8) !void {
    try out.print("{d}:{d}|{x}|{x}|", .{ reader.getPos(), reader.reader().bufferedLen(), buffer, data });
    if (direct) try out.print("{d}:{d}:{d}:{d}", .{ codec.width, codec.height, codec.hotspot_x, codec.hotspot_y }) else try out.writeByte('-');
}
fn record(line: []const u8, path: []const u8, out: *W, ready: bool) !void {
    var f: [7][]const u8 = undefined;
    var it = std.mem.splitScalar(u8, line, '|');
    for (&f) |*field| field.* = it.next().?;
    const capacity = try std.fmt.parseInt(i32, f[0], 10);
    const op = try std.fmt.parseInt(u8, f[1], 10);
    const start = try std.fmt.parseInt(usize, f[2], 10);
    const attempts = try std.fmt.parseInt(usize, f[3], 10);
    const data = try a.alloc(u8, f[6].len / 2);
    defer a.free(data);
    _ = try std.fmt.hexToBytes(data, f[6]);
    const buffer = try a.alloc(u8, if (capacity == -2) 32 else if (capacity < 0) 0 else @intCast(capacity));
    defer a.free(buffer);
    @memset(buffer, 165);
    var file: ?std.fs.File = null;
    defer if (file) |value| value.close();
    const iface = p.formatInterface();
    if (op <= 4) {
        var reader = io.ReadStream.initMemory(data);
        if (capacity >= 0) {
            try std.fs.cwd().writeFile(.{ .sub_path = path, .data = data });
            file = try std.fs.cwd().openFile(path, .{});
            try file.?.seekTo(data.len);
            reader = io.ReadStream.initFile(file.?, buffer);
        }
        if (start > 0) try reader.reader().discardAll(start);
        var codec = p{ .width = 97, .height = 89, .hotspot_x = 77, .hotspot_y = 66 };
        if (ready) {
            _ = try reader.reader().peekDelimiterInclusive('\n');
            try out.writeAll("ready|");
            try snapshot(out, &reader, codec, true, buffer, data);
            try out.writeByte('\n');
            try out.flush();
        }
        for (0..attempts) |_| {
            if (op == 2 or op == 4) {
                var status: []const u8 = "ok";
                const found = (if (op == 4) iface.formatDetect(&reader) else p.formatDetect(&reader)) catch |err| blk: {
                    status = @errorName(err);
                    break :blk false;
                };
                try out.print("{s}:{d}|", .{ status, @intFromBool(found) });
            } else {
                const result = if (op == 0) blk: {
                    const pixels = codec.read(a, &reader) catch |err| {
                        try out.print("{s}|", .{@errorName(err)});
                        try snapshot(out, &reader, codec, true, buffer, data);
                        try out.writeByte('~');
                        continue;
                    };
                    break :blk Image{ .width = codec.width, .height = codec.height, .pixels = pixels };
                } else (if (op == 3) iface.readImage(a, &reader) else p.readImage(a, &reader)) catch |err| {
                    try out.print("{s}|", .{@errorName(err)});
                    try snapshot(out, &reader, codec, false, buffer, data);
                    try out.writeByte('~');
                    continue;
                };
                defer result.pixels.deinit(a);
                try out.print("ok|{d}:{d}:", .{ result.width, result.height });
                try pixelsText(out, result.pixels);
                try out.writeByte('|');
                const raw = result.pixels.asBytes();
                if (raw.len > 0) raw[0] ^= 1;
                result.pixels.getPalette().?[0].g ^= 85;
                try pixelsText(out, result.pixels);
                try out.writeByte('|');
            }
            try snapshot(out, &reader, codec, op == 0 or op == 2 or op == 4, buffer, data);
            try out.writeByte('~');
        }
        if (capacity >= 0) {
            const disk = try std.fs.cwd().readFileAlloc(a, path, 65536);
            defer a.free(disk);
            try out.print("disk|{x}", .{disk});
        } else try out.writeAll("disk|-");
        return;
    }
    var writer = io.WriteStream.initMemory(buffer);
    if (capacity >= 0) {
        const initial = [_]u8{165} ** 32;
        try std.fs.cwd().writeFile(.{ .sub_path = path, .data = &initial });
        file = try std.fs.cwd().openFile(path, .{ .mode = .read_write });
        try file.?.seekTo(initial.len);
        writer = io.WriteStream.initFile(file.?, buffer);
    }
    if (start > 0) try writer.seekTo(start);
    try writer.writer().writeAll(data);
    const pixels = try color.PixelStorage.init(a, .rgba32, 1);
    defer pixels.deinit(a);
    pixels.rgba32[0] = .{ .r = 19, .g = 56, .b = 93, .a = 130 };
    const image = Image{ .width = try std.fmt.parseInt(usize, f[4], 10), .height = try std.fmt.parseInt(usize, f[5], 10), .pixels = pixels };
    const options: Image.EncoderOptions = if (op == 7) .{ .qoi = .{ .colorspace = .linear } } else .{ .bmp = .{} };
    for (0..attempts) |_| {
        if (op == 5) try p.writeImage(a, &writer, image, options) else try iface.writeImage(a, &writer, image, options);
        try out.print("ok|{d}:{d}|{x}|{d}:{d}:{x}~", .{ writer.getPos(), writer.writer().buffered().len, buffer, image.width, image.height, pixels.asBytes() });
    }
    try writer.writer().flush();
    try out.print("flush|{d}:{d}|{x}|", .{ writer.getPos(), writer.writer().buffered().len, buffer });
    if (capacity >= 0) {
        const disk = try std.fs.cwd().readFileAlloc(a, path, 65536);
        defer a.free(disk);
        try out.print("{x}", .{disk});
    } else try out.writeByte('-');
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args);
    var buffer: [8192]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&buffer);
    const out = &writer.interface;
    if (std.mem.eql(u8, args[1], "--loop")) {
        try record(args[2], args[3], out, true);
    } else {
        const text = try std.fs.cwd().readFileAlloc(a, args[1], 1073741824);
        defer a.free(text);
        const path = try std.fmt.allocPrint(a, "{s}.native.bin", .{args[1]});
        defer a.free(path);
        var lines = std.mem.splitScalar(u8, text, '\n');
        while (lines.next()) |line| {
            if (line.len == 0) continue;
            try record(line, path, out, false);
            try out.writeByte('\n');
        }
    }
    try out.flush();
}
