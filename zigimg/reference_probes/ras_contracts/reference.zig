const std = @import("std");
const p = @import("src/formats/ras.zig");
const color = @import("src/color.zig");
const Image = @import("src/ImageUnmanaged.zig");
const Format = @import("src/pixel_format.zig").PixelFormat;
const io = @import("src/io.zig");
const a = std.heap.page_allocator;
const W = std.Io.Writer;
const Header = @TypeOf((p.RAS{}).header);
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_codec: ?*const p.RAS = null;
var observed_reader: ?*const io.ReadStream = null;
var observed_data: []const u8 = &.{};
var observed_buffer: []const u8 = &.{};
var observed_op: u8 = 0;
fn header(w: u32, h: u32, d: u32, kind: p.Type, map: p.ColorMapType, length: u32) Header {
    return .{ .width = w, .height = h, .depth = d, .length = 123, .type = kind, .color_map_type = map, .color_map_length = length };
}
fn palette(out: *W, pixels: color.PixelStorage) !void {
    if (pixels.getPalette()) |pal| try out.print("{x}", .{std.mem.sliceAsBytes(pal)}) else try out.writeByte('-');
}
fn state(out: *W) !void {
    try out.print("{d}|", .{observed_reader.?.getPos()});
    if (observed_op == 3 or observed_op == 4) try out.writeAll("-|-|") else {
        try out.print("{x}|{x}|", .{ std.mem.asBytes(&observed_codec.?.header), std.mem.sliceAsBytes(observed_codec.?.palette.data) });
    }
    try out.print("{x}|{x}", .{ observed_buffer, observed_data });
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

fn runCase(op: u8, kind: u32, map: u32, length: u32, capacity: usize, start: usize, data: []const u8, out: *W) !void {
    var codec = p.RAS{ .header = header(7, 9, 8, @enumFromInt(kind), @enumFromInt(map), length) };
    codec.palette.resize(256);
    for (codec.palette.data, 0..) |*entry, i| entry.* = .{ .r = @truncate(i * 31), .g = @truncate(i * 71), .b = @truncate(i * 47), .a = 99 };
    codec.palette.resize(4);
    var reader = io.ReadStream.initMemory(data);
    if (start > 0) _ = try reader.reader().take(start);
    observed_codec = &codec;
    observed_reader = &reader;
    observed_data = data;
    observed_op = op;
    observed_buffer = &.{};
    if (op == 4) {
        var status: []const u8 = "ok";
        const result = p.RAS.formatDetect(&reader) catch |err| blk: {
            status = @errorName(err);
            break :blk false;
        };
        try out.print("{s}|{d}|", .{ status, @intFromBool(result) });
        try state(out);
        try out.writeByte('\n');
        return;
    }
    if (op == 1) {
        codec.readPalette(a, reader.reader()) catch |err| {
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
    if (op == 2) {
        var buffer: [257]u8 = @splat(165);
        observed_buffer = buffer[0..capacity];
        codec.uncompressBitmap(reader.reader(), buffer[0..capacity]) catch |err| {
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
    const result = if (op == 0) blk: {
        const pixels = codec.read(a, &reader) catch |err| {
            try out.print("{s}|", .{@errorName(err)});
            try state(out);
            try out.writeByte('\n');
            return;
        };
        break :blk Image{ .width = codec.width(), .height = codec.height(), .pixels = pixels };
    } else p.RAS.readImage(a, &reader) catch |err| {
        try out.print("{s}|", .{@errorName(err)});
        try state(out);
        try out.writeByte('\n');
        return;
    };
    defer result.pixels.deinit(a);
    const raw = result.pixels.asBytes();
    // Preserve pre-mutation records independently of the live storage.
    const before = try a.dupe(u8, raw);
    defer a.free(before);
    var pal_before: []const u8 = "-";
    var pal_owned: ?[]u8 = null;
    defer if (pal_owned) |owned| a.free(owned);
    if (result.pixels.getPalette()) |pal| {
        pal_owned = try std.fmt.allocPrint(a, "{x}", .{std.mem.sliceAsBytes(pal)});
        pal_before = pal_owned.?;
    }
    var separate: []const u8 = "-";
    if (raw.len > 0) {
        const ptr = @intFromPtr(raw.ptr);
        separate = if (ptr < @intFromPtr(data.ptr) or ptr >= @intFromPtr(data.ptr) + data.len) "1" else "0";
        raw[0] ^= 255;
    }
    var pal_separate: []const u8 = "-";
    if (result.pixels.getPalette()) |pal| if (pal.len > 0) {
        pal_separate = if (op == 0 and pal.ptr == codec.palette.data.ptr) "0" else "1";
        pal[0].g ^= 85;
    };
    try out.writeAll("ok|");
    try state(out);
    try out.print("|{d}|{d}|{d}|{d}|{x}|{s}|{s}|{s}|{x}|", .{ result.width, result.height, @intFromEnum(std.meta.activeTag(result.pixels)), result.pixels.len(), before, pal_before, separate, pal_separate, raw });
    try palette(out, result.pixels);
    try out.writeByte('\n');
}
fn lineCase(line: []const u8, out: *W) !void {
    var fields = std.mem.splitScalar(u8, line, '|');
    const op = try std.fmt.parseInt(u8, fields.next().?, 10);
    const kind = try std.fmt.parseInt(u32, fields.next().?, 10);
    const map = try std.fmt.parseInt(u32, fields.next().?, 10);
    const length = try std.fmt.parseInt(u32, fields.next().?, 10);
    const capacity = try std.fmt.parseInt(usize, fields.next().?, 10);
    const start = try std.fmt.parseInt(usize, fields.next().?, 10);
    const hex = fields.next().?;
    const data = try a.alloc(u8, hex.len / 2);
    defer a.free(data);
    _ = try std.fmt.hexToBytes(data, hex);
    try runCase(op, kind, map, length, capacity, start, data, out);
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
                try lineCase(line, out);
            }
            try out.flush();
            return;
        }
        if (std.mem.eql(u8, args[1], "--debug")) {
            for (std.meta.tags(p.Type)) |kind| for (std.meta.tags(p.ColorMapType)) |map| {
                const h = header(7, 9, 8, kind, map, 6);
                h.debug();
            };
            return;
        }
        observed_path = args[2];
        try lineCase(args[3], out);
        try out.flush();
        return;
    }
    try out.print("S|{d}|{d}|{d}\n", .{ @sizeOf(Header), @sizeOf(p.Type), @sizeOf(p.ColorMapType) });
    for ([_]u32{ 0, 1, 0x80000000, 0xffffffff }) |w| for ([_]u32{ 0, 1, 0x80000000, 0xffffffff }) |h| {
        var codec = p.RAS{ .header = header(w, h, 8, .old, .no_color_map, 0) };
        var changed = codec.header;
        changed.width ^= 0x12345678;
        changed.height ^= 0x87654321;
        try out.print("H|{x}|{d}|{d}|{x}\n", .{ std.mem.asBytes(&codec.header), codec.width(), codec.height(), std.mem.asBytes(&changed) });
    };
    for ([_]u32{ 0, 1, 2, 8, 16, 24, 32, 0xffffffff }) |d| for (std.meta.tags(p.Type)) |kind| for (std.meta.tags(p.ColorMapType)) |map| for ([_]u32{ 0, 1, 2, 3, 0xffffffff }) |length| {
        var codec = p.RAS{ .header = header(1, 1, d, kind, map, length) };
        var status: []const u8 = "ok";
        const pf = codec.pixelFormat() catch |err| blk: {
            status = @errorName(err);
            break :blk @as(Format, .invalid);
        };
        try out.print("P|{d}|{d}|{d}|{d}|{s}|{d}\n", .{ d, @intFromEnum(kind), @intFromEnum(map), length, status, @intFromEnum(pf) });
    };
    for (std.meta.tags(Format)) |format| for (0..3) |count| {
        const pixels = try makePixels(format, count);
        defer pixels.deinit(a);
        for ([_][2]usize{ .{ 0, 0 }, .{ 1, 2 }, .{ 0xffffffffffffffff, 0xffffffffffffffff } }) |dims| for ([_]usize{ 0, 1, 8, 16 }) |capacity| for (0..2) |entry| {
            var buffer: [16]u8 = @splat(165);
            var stream = io.WriteStream.initMemory(buffer[0..capacity]);
            if (capacity > 1) try stream.seekTo(1);
            const image = Image{ .width = dims[0], .height = dims[1], .pixels = pixels };
            if (entry == 0) try p.RAS.writeImage(a, &stream, image, .{ .ras = {} }) else {
                const iface = p.RAS.formatInterface();
                try iface.writeImage(a, &stream, image, .{ .ras = {} });
            }
            try out.print("W|{d}|{d}|{d}|{d}|{d}|{d}|{d}|{x}|{x}\n", .{ @intFromEnum(format), count, dims[0], dims[1], capacity, entry, stream.getPos(), buffer[0..capacity], pixels.asBytes() });
        };
    };
    try out.flush();
}
