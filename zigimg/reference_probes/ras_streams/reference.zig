const std = @import("std");
const p = @import("src/formats/ras.zig");
const Image = @import("src/ImageUnmanaged.zig");
const color = @import("src/color.zig");
const io = @import("src/io.zig");
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_codec: ?*const p.RAS = null;
var observed_reader: ?*io.ReadStream = null;
var observed_buffer: []const u8 = &.{};
var observed_output: []const u8 = &.{};
var observed_data: []const u8 = &.{};

fn pixelsText(out: *W, pixels: color.PixelStorage) !void {
    try out.print("{d}:{d}:", .{ @intFromEnum(std.meta.activeTag(pixels)), pixels.len() });
    switch (pixels) {
        .grayscale1 => |values| for (values) |value| try out.print("{x:0>2}", .{@as(u8, value.value)}),
        else => try out.print("{x}", .{pixels.asBytes()}),
    }
    try out.writeByte(':');
    if (pixels.getPalette()) |pal| try out.print("{x}", .{std.mem.sliceAsBytes(pal)}) else try out.writeByte('-');
}
fn snapshot(out: *W) !void {
    const reader = observed_reader.?;
    try out.print("{d}:{d}|", .{ reader.getPos(), reader.reader().bufferedLen() });
    if (observed_codec) |codec| {
        try out.print("{x}:{x}", .{ std.mem.asBytes(&codec.header), std.mem.sliceAsBytes(codec.palette.data) });
    } else try out.writeByte('-');
    try out.print("|{x}|{x}|{x}", .{ observed_buffer, observed_output, observed_data });
}
fn observe(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var buffer: [8192]u8 = undefined;
            var writer = file.writer(&buffer);
            snapshot(&writer.interface) catch {};
            writer.interface.flush() catch {};
        } else |_| {}
    }
    std.debug.defaultPanic(message, address);
}
fn record(line: []const u8, path: []const u8, out: *W) !void {
    var fields: [9][]const u8 = undefined;
    var it = std.mem.splitScalar(u8, line, '|');
    for (&fields) |*field| field.* = it.next().?;
    const cap = try std.fmt.parseInt(i32, fields[0], 10);
    const op = try std.fmt.parseInt(u8, fields[1], 10);
    const data = try a.alloc(u8, fields[8].len / 2);
    defer a.free(data);
    _ = try std.fmt.hexToBytes(data, fields[8]);
    const buffer = try a.alloc(u8, if (cap < 0) 0 else @intCast(cap));
    defer a.free(buffer);
    @memset(buffer, 165);
    const output = try a.alloc(u8, try std.fmt.parseInt(usize, fields[5], 10));
    defer a.free(output);
    @memset(output, 165);
    var codec = p.RAS{ .header = .{
        .width = 7,
        .height = 9,
        .depth = 8,
        .length = 123,
        .type = @enumFromInt(try std.fmt.parseInt(u32, fields[2], 10)),
        .color_map_type = @enumFromInt(try std.fmt.parseInt(u32, fields[3], 10)),
        .color_map_length = try std.fmt.parseInt(u32, fields[4], 10),
    } };
    codec.palette.resize(256);
    for (codec.palette.data, 0..) |*entry, i| entry.* = .{ .r = @truncate(i * 31), .g = @truncate(i * 71), .b = @truncate(i * 47), .a = 99 };
    codec.palette.resize(4);
    var reader = io.ReadStream.initMemory(data);
    var file: ?std.fs.File = null;
    defer if (file) |value| value.close();
    if (cap >= 0) {
        try std.fs.cwd().writeFile(.{ .sub_path = path, .data = data });
        file = try std.fs.cwd().openFile(path, .{});
        try file.?.seekTo(data.len);
        reader = io.ReadStream.initFile(file.?, buffer);
    }
    observed_reader = &reader;
    observed_codec = if (op <= 2) &codec else null;
    observed_buffer = buffer;
    observed_output = output;
    observed_data = data;
    const start = try std.fmt.parseInt(usize, fields[6], 10);
    if (start > 0) try reader.reader().discardAll(start);
    const attempts = try std.fmt.parseInt(usize, fields[7], 10);
    const iface = p.RAS.formatInterface();
    for (0..attempts) |_| {
        if (op == 4 or op == 6) {
            var status: []const u8 = "ok";
            const found = (if (op == 6) iface.formatDetect(&reader) else p.RAS.formatDetect(&reader)) catch |err| blk: {
                status = @errorName(err);
                break :blk false;
            };
            try out.print("{s}:{d}|", .{ status, @intFromBool(found) });
        } else if (op == 1 or op == 2) {
            var status: []const u8 = "ok";
            if (op == 1) codec.readPalette(a, reader.reader()) catch |err| {
                status = @errorName(err);
            } else codec.uncompressBitmap(reader.reader(), output) catch |err| {
                status = @errorName(err);
            };
            try out.print("{s}|", .{status});
        } else {
            const image = if (op == 0) blk: {
                const pixels = codec.read(a, &reader) catch |err| {
                    try out.print("{s}|", .{@errorName(err)});
                    try snapshot(out);
                    try out.writeByte('~');
                    continue;
                };
                break :blk Image{ .width = codec.width(), .height = codec.height(), .pixels = pixels };
            } else (if (op == 5) iface.readImage(a, &reader) else p.RAS.readImage(a, &reader)) catch |err| {
                try out.print("{s}|", .{@errorName(err)});
                try snapshot(out);
                try out.writeByte('~');
                continue;
            };
            defer image.pixels.deinit(a);
            try out.print("ok|{d}:{d}:", .{ image.width, image.height });
            try pixelsText(out, image.pixels);
            try out.writeByte('|');
            switch (image.pixels) {
                .grayscale1 => |values| {
                    if (values.len > 0) values[0].value ^= 1;
                },
                else => {
                    const raw = image.pixels.asBytes();
                    if (raw.len > 0) raw[0] ^= 85;
                },
            }
            if (image.pixels.getPalette()) |pal| {
                if (pal.len > 0) pal[0].g ^= 85;
            }
            try pixelsText(out, image.pixels);
            try out.writeByte('|');
        }
        try snapshot(out);
        try out.writeByte('~');
    }
    if (cap >= 0) {
        const disk = try std.fs.cwd().readFileAlloc(a, path, 65536);
        defer a.free(disk);
        try out.print("disk|{x}", .{disk});
    } else try out.writeAll("disk|-");
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args);
    var buffer: [8192]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&buffer);
    const out = &writer.interface;
    if (std.mem.eql(u8, args[1], "--trap")) {
        observed_path = args[2];
        const path = try std.fmt.allocPrint(a, "{s}.bin", .{args[2]});
        defer a.free(path);
        try record(args[3], path, out);
        try out.writeByte('\n');
    } else {
        const text = try std.fs.cwd().readFileAlloc(a, args[1], 1073741824);
        defer a.free(text);
        const path = try std.fmt.allocPrint(a, "{s}.native.bin", .{args[1]});
        defer a.free(path);
        var lines = std.mem.splitScalar(u8, text, '\n');
        while (lines.next()) |line| {
            if (line.len == 0) continue;
            try record(line, path, out);
            try out.writeByte('\n');
        }
    }
    try out.flush();
}
