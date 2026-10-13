const std = @import("std");
const p = @import("src/formats/iff.zig");
const color = @import("src/color.zig");
const Image = @import("src/ImageUnmanaged.zig");
const io = @import("src/io.zig");
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_codec: ?*const p.IFF = null;
var observed_reader: ?*const io.ReadStream = null;
var observed_data: []const u8 = &.{};
var observed_op: usize = 0;
fn headerBytes(out: *W, header: p.IffHeader) !void {
    switch (header) {
        .bmhd => |h| try out.print("b:{x}", .{std.mem.asBytes(&h)}),
        .dgbl => |h| try out.print("d:{x}", .{std.mem.asBytes(&h)}),
    }
}
fn state(out: *W) !void {
    try out.print("{d}|", .{observed_reader.?.getPos()});
    if (observed_op == 11) try out.writeAll("-") else {
        const codec = observed_codec.?;
        try out.print("{d}:{d}:", .{ codec.cmap_bits, @intFromEnum(codec.format_id) });
        try headerBytes(out, codec.header);
        try out.print(":{d}:{d}:{d}:{x}", .{ codec.pitch, codec.pixel_byte_size, codec.viewport_mode, std.mem.sliceAsBytes(codec.palette.data) });
    }
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
fn num(f: [13][]const u8, i: usize) !usize {
    return std.fmt.parseInt(usize, f[i], 10);
}
fn runCase(f: [13][]const u8, data: []u8, out: *W) !void {
    const op = try num(f, 0);
    var codec = p.IFF{ .format_id = @enumFromInt(try num(f, 2)), .header = if ((try num(f, 1)) == 0) .{ .bmhd = .{ .width = @intCast(try num(f, 3)), .height = @intCast(try num(f, 4)), .x = -7, .y = -9, .planes = @intCast(try num(f, 5)), .mask_type = .has_lasso, .compression_type = .byterun2, .pad = 19, .transparent_color = 513, .x_asoect = 23, .y_aspect = 29, .page_width = 31, .page_height = 37 } } else .{ .dgbl = .{ .width = @intCast(try num(f, 3)), .height = @intCast(try num(f, 4)), .compression_type = .jpeg, .x_aspect = 23, .y_aspect = 29 } }, .cmap_bits = @intCast(try num(f, 6)), .pitch = @intCast(try num(f, 7)), .pixel_byte_size = 47, .viewport_mode = @intCast(try num(f, 8)) };
    codec.palette.resize(256);
    for (codec.palette.data, 0..) |*entry, i| entry.* = .{ .r = @truncate(i * 31), .g = @truncate(i * 71), .b = @truncate(i * 47), .a = 99 };
    codec.palette.resize(try num(f, 9));
    var reader = io.ReadStream.initMemory(data);
    const start = try num(f, 11);
    if (start > 0) _ = try reader.reader().take(start);
    observed_codec = &codec;
    observed_reader = &reader;
    observed_data = data;
    observed_op = op;
    if (op == 9) {
        const result = p.Chunk.init(data[start..]);
        const copy = result;
        const before = try a.dupe(u8, result.name);
        defer a.free(before);
        if (data.len > start) data[start] ^= 85;
        try out.print("ok|{d}|{x}|{x}|{d}|{x}|", .{ result.id, before, result.name, copy.id, copy.name });
        try state(out);
        try out.writeByte('\n');
        return;
    }
    if (op == 8) {
        try out.print("ok|{d}|{d}|", .{ codec.width(), codec.height() });
        try state(out);
        try out.writeByte('\n');
        return;
    }
    if (op == 7) {
        const format = codec.pixelFormat() catch |err| {
            try out.print("{s}|", .{@errorName(err)});
            try state(out);
            try out.writeByte('\n');
            return;
        };
        try out.print("ok|{d}|", .{@intFromEnum(format)});
        try state(out);
        try out.writeByte('\n');
        return;
    }
    if (op == 6) {
        codec.reduceHamPalette();
        try out.writeAll("ok|");
        try state(out);
        try out.writeByte('\n');
        return;
    }
    if (op == 5) {
        p.extendEhbPalette(&codec.palette);
        try out.writeAll("ok|");
        try state(out);
        try out.writeByte('\n');
        return;
    }
    if (op == 4) {
        codec.decodeCMAPChunk(&reader, &.{ .type = 37, .length = @intCast(try num(f, 10)) }) catch |err| {
            try out.print("{s}|", .{@errorName(err)});
            try state(out);
            try out.writeByte('\n');
            return;
        };
        try out.writeAll("ok|");
        try state(out);
        try out.writeByte('\n');
        return;
    }
    if (op == 3) {
        codec.decodeCAMGChunk(&reader) catch |err| {
            try out.print("{s}|", .{@errorName(err)});
            try state(out);
            try out.writeByte('\n');
            return;
        };
        try out.writeAll("ok|");
        try state(out);
        try out.writeByte('\n');
        return;
    }
    if (op == 10) {
        const result = try p.IFF.formatDetect(&reader);
        try out.print("ok|{d}|", .{@intFromBool(result)});
        try state(out);
        try out.writeByte('\n');
        return;
    }
    if (op == 12 or op == 13) {
        const format = (if (op == 12) p.peekIffFormatId(reader.reader()) else p.takeIffFormatId(reader.reader())) catch |err| {
            try out.print("{s}|", .{@errorName(err)});
            try state(out);
            try out.writeByte('\n');
            return;
        };
        try out.print("ok|{d}|", .{@intFromEnum(format)});
        try state(out);
        try out.writeByte('\n');
        return;
    }
    if (op == 0) {
        const result = p.decodeBmhdChunk(&reader) catch |err| {
            try out.print("{s}|", .{@errorName(err)});
            try state(out);
            try out.writeByte('\n');
            return;
        };
        try out.writeAll("ok|");
        try headerBytes(out, .{ .bmhd = result });
        try out.writeByte('|');
        try state(out);
        try out.writeByte('\n');
        return;
    }
    if (op == 1) {
        const result = p.loadHeader(&reader, codec.format_id) catch |err| {
            try out.print("{s}|", .{@errorName(err)});
            try state(out);
            try out.writeByte('\n');
            return;
        };
        try out.writeAll("ok|");
        try headerBytes(out, result);
        try out.writeByte('|');
        try state(out);
        try out.writeByte('\n');
        return;
    }
    const image = if (op == 2) blk: {
        const pixels = codec.read(&reader, a) catch |err| {
            try out.print("{s}|", .{@errorName(err)});
            try state(out);
            try out.writeByte('\n');
            return;
        };
        break :blk Image{ .width = codec.width(), .height = codec.height(), .pixels = pixels };
    } else p.IFF.readImage(a, &reader) catch |err| {
        try out.print("{s}|", .{@errorName(err)});
        try state(out);
        try out.writeByte('\n');
        return;
    };
    defer image.pixels.deinit(a);
    const raw = image.pixels.asBytes();
    const before = try a.dupe(u8, raw);
    defer a.free(before);
    var independent: []const u8 = "-";
    if (raw.len > 0) {
        const ptr = @intFromPtr(raw.ptr);
        independent = if (ptr < @intFromPtr(data.ptr) or ptr >= @intFromPtr(data.ptr) + data.len) "1" else "0";
        raw[0] ^= 1;
    }
    var palette_before: []const u8 = "-";
    var palette_after: []const u8 = "-";
    var separate: []const u8 = "-";
    var owned_before: ?[]u8 = null;
    var owned_after: ?[]u8 = null;
    defer if (owned_before) |value| a.free(value);
    defer if (owned_after) |value| a.free(value);
    if (image.pixels.getPalette()) |pal| {
        owned_before = try std.fmt.allocPrint(a, "{x}", .{std.mem.sliceAsBytes(pal)});
        palette_before = owned_before.?;
        if (pal.len > 0) {
            separate = if (op == 2 and pal.ptr == codec.palette.data.ptr) "0" else "1";
            pal[0].g ^= 85;
        }
        owned_after = try std.fmt.allocPrint(a, "{x}", .{std.mem.sliceAsBytes(pal)});
        palette_after = owned_after.?;
    }
    try out.print("ok|{d}|{d}|{d}|{d}|{x}|{x}|{s}|{s}|{s}|{s}|", .{ image.width, image.height, @intFromEnum(std.meta.activeTag(image.pixels)), image.pixels.len(), before, raw, independent, palette_before, palette_after, separate });
    try state(out);
    try out.writeByte('\n');
}
fn lineCase(line: []const u8, out: *W) !void {
    var parts = std.mem.splitScalar(u8, line, '|');
    var f: [13][]const u8 = undefined;
    for (&f) |*field| field.* = parts.next().?;
    const data = try a.alloc(u8, f[12].len / 2);
    defer a.free(data);
    _ = try std.fmt.hexToBytes(data, f[12]);
    try runCase(f, data, out);
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args);
    var bytes: [8192]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&bytes);
    const out = &writer.interface;
    if (args.len > 1) {
        if (std.mem.eql(u8, args[1], "--corpus")) {
            const text = try std.fs.cwd().readFileAlloc(a, args[2], 1073741824);
            defer a.free(text);
            var lines = std.mem.splitScalar(u8, text, '\n');
            while (lines.next()) |line| {
                if (line.len > 0) try lineCase(line, out);
            }
            try out.flush();
            return;
        }
        if (std.mem.eql(u8, args[1], "--boxed")) {
            const first = p.IffHeader{ .bmhd = .{ .width = 7 } };
            var copy = first;
            copy.bmhd.width = 9;
            try out.print("{d}|{d}\n", .{ first.bmhd.width, copy.bmhd.width });
            try out.flush();
            return;
        }
        observed_path = args[2];
        try lineCase(args[3], out);
        try out.flush();
        return;
    }
    try out.print("{d}|{d}|{d}\n", .{ @sizeOf(p.ChunkHeader), @sizeOf(p.BmhdHeader), @sizeOf(p.DgblHeader) });
    for ([_]p.Chunk{ p.Chunks.BMHD, p.Chunks.BODY, p.Chunks.CAMG, p.Chunks.CMAP, p.Chunks.ABIT, p.Chunks.DGBL, p.Chunks.DLOC }) |magic| try out.print("{d}|{x}\n", .{ magic.id, magic.name });
    for ([_]u32{ 0, 1, 0x80, 0x800, 0x880, 0xffffffff }) |value| try out.print("{d}|{}|{}\n", .{ value, p.ViewportMode.isEhb(value), p.ViewportMode.isHam(value) });
    var chunk = p.ChunkHeader{ .type = 0x12345678, .length = 99 };
    const view = chunk.name();
    var before: [4]u8 = undefined;
    @memcpy(&before, view);
    const copy = chunk;
    chunk.type = 0x87654321;
    try out.print("{x}|{x}|{d}|{d}\n", .{ before, view, copy.type, copy.length });
    try out.flush();
}
