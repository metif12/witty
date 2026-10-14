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
var observed_reader: ?*io.ReadStream = null;
var observed_data: []const u8 = &.{};
var observed_op: usize = 0;
var observed_buffer: []const u8 = &.{};
var observed_output: []const u8 = &.{};
var observed_disk: ?[]const u8 = null;
var observed_ready: ?[]const u8 = null;
fn headerBytes(out: *W, header: p.IffHeader) !void {
    switch (header) {
        .bmhd => |h| try out.print("b:{x}", .{std.mem.asBytes(&h)}),
        .dgbl => |h| try out.print("d:{x}", .{std.mem.asBytes(&h)}),
    }
}
fn state(out: *W) !void {
    try out.print("{d}:{d}|{x}|{x}|", .{ observed_reader.?.getPos(), observed_reader.?.reader().bufferedLen(), observed_buffer, observed_output });
    if (observed_op == 3 or observed_op == 4) try out.writeAll("-") else {
        const codec = observed_codec.?;
        try out.print("{d}:{d}:", .{ codec.cmap_bits, @intFromEnum(codec.format_id) });
        try headerBytes(out, codec.header);
        try out.print(":{d}:{d}:{d}:{x}", .{ codec.pitch, codec.pixel_byte_size, codec.viewport_mode, std.mem.sliceAsBytes(codec.palette.data) });
    }
    try out.print("|{x}|", .{observed_data});
    if (observed_disk) |path| {
        const bytes = try std.fs.cwd().readFileAlloc(a, path, 65536);
        defer a.free(bytes);
        try out.print("{x}", .{bytes});
    } else try out.writeByte('-');
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
fn num(f: [18][]const u8, i: usize) !usize {
    return std.fmt.parseInt(usize, f[i], 10);
}
fn runCase(f: [18][]const u8, data: []u8, path: []const u8, out: *W) !void {
    const op = try num(f, 0);
    var codec = p.IFF{ .format_id = @enumFromInt(try num(f, 2)), .header = if ((try num(f, 1)) == 0) .{ .bmhd = .{ .width = @intCast(try num(f, 3)), .height = @intCast(try num(f, 4)), .x = -7, .y = -9, .planes = @intCast(try num(f, 5)), .mask_type = .has_lasso, .compression_type = @enumFromInt(try num(f, 13)), .pad = 19, .transparent_color = 513, .x_asoect = 23, .y_aspect = 29, .page_width = 31, .page_height = 37 } } else .{ .dgbl = .{ .width = @intCast(try num(f, 3)), .height = @intCast(try num(f, 4)), .compression_type = .jpeg, .x_aspect = 23, .y_aspect = 29 } }, .cmap_bits = @intCast(try num(f, 6)), .pitch = @intCast(try num(f, 7)), .pixel_byte_size = 47, .viewport_mode = @intCast(try num(f, 8)) };
    codec.palette.resize(256);
    for (codec.palette.data, 0..) |*entry, i| entry.* = .{ .r = @truncate(i * 31), .g = @truncate(i * 71), .b = @truncate(i * 47), .a = 99 };
    codec.palette.resize(try num(f, 9));
    const cap = try std.fmt.parseInt(i32, f[15], 10);
    const buffer = try a.alloc(u8, if (cap < 0) 0 else @intCast(cap));
    defer a.free(buffer);
    @memset(buffer, 165);
    observed_buffer = buffer;
    const output = try a.alloc(u8, try num(f, 17));
    defer a.free(output);
    @memset(output, 165);
    observed_output = output;
    var file: ?std.fs.File = null;
    defer if (file) |value| value.close();
    observed_disk = null;
    var reader = io.ReadStream.initMemory(data);
    if (cap >= 0) {
        try std.fs.cwd().writeFile(.{ .sub_path = path, .data = data });
        file = try std.fs.cwd().openFile(path, .{});
        try file.?.seekTo(data.len);
        reader = io.ReadStream.initFile(file.?, buffer);
        observed_disk = path;
    }
    const start = try num(f, 11);
    if (start > 0) try reader.reader().discardAll(start);
    observed_codec = &codec;
    observed_reader = &reader;
    observed_data = data;
    observed_op = op;
    if (observed_ready) |ready| {
        const ready_file = try std.fs.cwd().createFile(ready, .{});
        defer ready_file.close();
        var ready_buffer: [8192]u8 = undefined;
        var ready_writer = ready_file.writer(&ready_buffer);
        try state(&ready_writer.interface);
        try ready_writer.interface.flush();
    }
    for (0..try num(f, 16)) |_| {
        if (op >= 5) {
            var status: []const u8 = "ok";
            if (op == 5 or op == 6) {
                const iface = p.IFF.formatInterface();
                const found = (if (op == 5) p.IFF.formatDetect(&reader) else iface.formatDetect(&reader)) catch |err| blk: {
                    status = @errorName(err);
                    break :blk false;
                };
                try out.print("{s}:{d}|", .{ status, @intFromBool(found) });
                try state(out);
                try out.writeByte('~');
                continue;
            } else if (op == 7 or op == 8) {
                const found = (if (op == 7) p.peekIffFormatId(reader.reader()) else p.takeIffFormatId(reader.reader())) catch |err| blk: {
                    status = @errorName(err);
                    break :blk p.IffFormat.bad;
                };
                try out.print("{s}:{d}|", .{ status, @intFromEnum(found) });
                try state(out);
                try out.writeByte('~');
                continue;
            } else if (op == 9) {
                codec.decodeCMAPChunk(&reader, &.{ .type = 37, .length = @intCast(try num(f, 10)) }) catch |err| {
                    status = @errorName(err);
                };
            } else if (op == 10) {
                codec.decodeCAMGChunk(&reader) catch |err| {
                    status = @errorName(err);
                };
            } else codec.decodeByteRun2(&reader, output, a) catch |err| {
                status = @errorName(err);
            };
            try out.print("{s}|", .{status});
            try state(out);
            try out.writeByte('~');
            continue;
        }
        const image = if (op < 3) blk: {
            const pixels = (if (op == 0) codec.decodeILBMPixelChunk(&reader, &.{ .type = @intCast(try num(f, 14)), .length = @intCast(try num(f, 10)) }, a) else if (op == 1) codec.decodeChunks(&reader, a) else codec.read(&reader, a)) catch |err| {
                try out.print("{s}|", .{@errorName(err)});
                try state(out);
                try out.writeByte('~');
                continue;
            };
            break :blk Image{ .width = codec.width(), .height = codec.height(), .pixels = pixels };
        } else (if (op == 3) p.IFF.readImage(a, &reader) else p.IFF.formatInterface().readImage(a, &reader)) catch |err| {
            try out.print("{s}|", .{@errorName(err)});
            try state(out);
            try out.writeByte('~');
            continue;
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
                separate = if (op < 3 and pal.ptr == codec.palette.data.ptr) "0" else "1";
                pal[0].g ^= 85;
            }
            owned_after = try std.fmt.allocPrint(a, "{x}", .{std.mem.sliceAsBytes(pal)});
            palette_after = owned_after.?;
        }
        try out.print("ok|{d}|{d}|{d}|{d}|{x}|{x}|{s}|{s}|{s}|{s}|", .{ image.width, image.height, @intFromEnum(std.meta.activeTag(image.pixels)), image.pixels.len(), before, raw, independent, palette_before, palette_after, separate });
        try state(out);
        try out.writeByte('~');
    }
    try out.writeByte('\n');
}
fn lineCase(line: []const u8, path: []const u8, out: *W) !void {
    var parts = std.mem.splitScalar(u8, line, '|');
    var f: [18][]const u8 = undefined;
    for (&f) |*field| field.* = parts.next().?;
    const data = try a.alloc(u8, f[12].len / 2);
    defer a.free(data);
    _ = try std.fmt.hexToBytes(data, f[12]);
    try runCase(f, data, path, out);
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args);
    var bytes: [8192]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&bytes);
    const out = &writer.interface;
    if (std.mem.eql(u8, args[1], "--corpus")) {
        const text = try std.fs.cwd().readFileAlloc(a, args[2], 1073741824);
        defer a.free(text);
        const path = try std.fmt.allocPrint(a, "{s}.native.bin", .{args[2]});
        defer a.free(path);
        var lines = std.mem.splitScalar(u8, text, '\n');
        while (lines.next()) |line| {
            if (line.len > 0) try lineCase(line, path, out);
        }
    } else {
        observed_path = args[2];
        if (std.mem.eql(u8, args[1], "--loop")) observed_ready = try std.fmt.allocPrint(a, "{s}.ready", .{args[2]});
        const path = try std.fmt.allocPrint(a, "{s}.bin", .{args[2]});
        defer a.free(path);
        try lineCase(args[3], path, out);
    }
    try out.flush();
}
