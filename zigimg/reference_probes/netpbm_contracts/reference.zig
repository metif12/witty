const std = @import("std");
const p = @import("src/formats/netpbm.zig");
const color = @import("src/color.zig");
const Image = @import("src/ImageUnmanaged.zig");
const Format = @import("src/pixel_format.zig").PixelFormat;
const io = @import("src/io.zig");
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_header: ?*const p.Header = null;
var observed_reader: ?*const io.ReadStream = null;
var observed_writer: ?*const io.WriteStream = null;
var observed_input: []const u8 = &.{};
var observed_output: []const u8 = &.{};
var observed_pixels: []const u8 = &.{};
var observed_op: u8 = 0;
fn headerText(out: *W, h: p.Header) !void {
    try out.print("{d}:{d}:{d}:{d}:{d}", .{ @intFromEnum(h.format), @intFromBool(h.binary), h.width, h.height, h.max_value });
}
fn state(out: *W) !void {
    try out.print("{d}|{d}|", .{ observed_reader.?.getPos(), observed_writer.?.getPos() });
    if (observed_op == 0 or observed_op == 3) try headerText(out, observed_header.?.*) else try out.writeByte('-');
    try out.print("|{x}|{x}|{x}", .{ observed_input, observed_output, observed_pixels });
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
fn pixels(format: Format, count: usize) !color.PixelStorage {
    const result = try color.PixelStorage.init(a, format, count);
    const raw = result.asBytes();
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
    return result;
}
fn options(tag: u8, binary: bool) Image.EncoderOptions {
    return switch (tag) {
        0 => .{ .bmp = .{} },
        1 => .{ .farbfeld = {} },
        2 => .{ .gif = {} },
        3 => .{ .iff = {} },
        4 => .{ .jpeg = {} },
        5 => .{ .pam = .{} },
        6 => .{ .pbm = .{ .binary = binary } },
        7 => .{ .pcx = .{} },
        8 => .{ .pgm = .{ .binary = binary } },
        9 => .{ .png = .{} },
        10 => .{ .ppm = .{ .binary = binary } },
        11 => .{ .qoi = .{} },
        12 => .{ .ras = {} },
        13 => .{ .sgi = {} },
        14 => .{ .tga = .{} },
        15 => .{ .tiff = {} },
        else => .{ .xbm = {} },
    };
}
fn num(fields: [13][]const u8, i: usize) !usize {
    return std.fmt.parseInt(usize, fields[i], 10);
}
fn runCase(comptime Codec: type, fields: [13][]const u8, data: []const u8, out: *W) !void {
    const op = try num(fields, 1);
    const binary = (try num(fields, 3)) != 0;
    var codec = Codec{ .header = .{ .format = @enumFromInt(try num(fields, 2)), .binary = binary, .width = try num(fields, 4), .height = try num(fields, 5), .max_value = try num(fields, 6) } };
    var reader = io.ReadStream.initMemory(data);
    const output = try a.alloc(u8, try num(fields, 9));
    defer a.free(output);
    @memset(output, 165);
    var writer = io.WriteStream.initMemory(output);
    const start = try num(fields, 10);
    if (start > 0) {
        if (op == 3 or op == 4 or op == 5) try writer.seekTo(start) else _ = try reader.reader().take(start);
    }
    observed_header = &codec.header;
    observed_reader = &reader;
    observed_writer = &writer;
    observed_input = data;
    observed_output = output;
    observed_pixels = &.{};
    observed_op = @intCast(op);
    if (op == 6) {
        const format = try codec.pixelFormat();
        var copy = codec.header;
        copy.width ^= 0x12345678;
        copy.binary = !copy.binary;
        try out.writeAll("ok|");
        try headerText(out, codec.header);
        try out.print("|{d}|", .{@intFromEnum(format)});
        try headerText(out, copy);
        try out.writeByte('\n');
        return;
    }
    if (op == 2) {
        var status: []const u8 = "ok";
        const result = Codec.formatDetect(&reader) catch |err| blk: {
            status = @errorName(err);
            break :blk false;
        };
        try out.print("{s}|{d}|", .{ status, @intFromBool(result) });
        try state(out);
        try out.writeByte('\n');
        return;
    }
    if (op == 3 or op == 4 or op == 5) {
        const value = try pixels(@enumFromInt(try num(fields, 7)), try num(fields, 8));
        defer value.deinit(a);
        observed_pixels = value.asBytes();
        var status: []const u8 = "ok";
        if (op == 3) codec.write(&writer, value) catch |err| {
            status = @errorName(err);
        } else {
            const image = Image{ .width = codec.header.width, .height = codec.header.height, .pixels = value };
            const encoded_options = options(@intCast(try num(fields, 11)), binary);
            if (op == 5) {
                const iface = Codec.formatInterface();
                iface.writeImage(a, &writer, image, encoded_options) catch |err| {
                    status = @errorName(err);
                };
            } else Codec.writeImage(a, &writer, image, encoded_options) catch |err| {
                status = @errorName(err);
            };
        }
        try out.print("{s}|", .{status});
        try state(out);
        try out.writeByte('\n');
        return;
    }
    const image = if (op == 0) blk: {
        const value = codec.read(a, &reader) catch |err| {
            try out.print("{s}|", .{@errorName(err)});
            try state(out);
            try out.writeByte('\n');
            return;
        };
        break :blk Image{ .width = codec.header.width, .height = codec.header.height, .pixels = value };
    } else Codec.readImage(a, &reader) catch |err| {
        try out.print("{s}|", .{@errorName(err)});
        try state(out);
        try out.writeByte('\n');
        return;
    };
    defer image.pixels.deinit(a);
    const raw = image.pixels.asBytes();
    const before = try a.dupe(u8, raw);
    defer a.free(before);
    var separate: []const u8 = "-";
    if (raw.len > 0) {
        const ptr = @intFromPtr(raw.ptr);
        separate = if (ptr < @intFromPtr(data.ptr) or ptr >= @intFromPtr(data.ptr) + data.len) "1" else "0";
        raw[0] ^= 1;
    }
    try out.writeAll("ok|");
    try state(out);
    try out.print("|{d}|{d}|{d}|{d}|{x}|{s}|{x}\n", .{ image.width, image.height, @intFromEnum(std.meta.activeTag(image.pixels)), image.pixels.len(), before, separate, raw });
}
fn lineCase(line: []const u8, out: *W) !void {
    var parts = std.mem.splitScalar(u8, line, '|');
    var fields: [13][]const u8 = undefined;
    for (&fields) |*field| field.* = parts.next().?;
    const data = try a.alloc(u8, fields[12].len / 2);
    defer a.free(data);
    _ = try std.fmt.hexToBytes(data, fields[12]);
    switch (try num(fields, 0)) {
        0 => try runCase(p.PBM, fields, data, out),
        1 => try runCase(p.PGM, fields, data, out),
        else => try runCase(p.PPM, fields, data, out),
    }
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
        observed_path = args[2];
        try lineCase(args[3], out);
        try out.flush();
        return;
    }
    var shared = p.PBM.EncoderOptions{};
    var pbm = p.PBM.EncoderOptions{};
    var pgm = p.PGM.EncoderOptions{};
    var ppm = p.PPM.EncoderOptions{};
    try out.print("{}|{}|{}|{}\n", .{ shared.binary, pbm.binary, pgm.binary, ppm.binary });
    shared.binary = false;
    pbm.binary = false;
    pgm.binary = false;
    ppm.binary = false;
    try out.print("{}|{}|{}|{}\n", .{ shared.binary, pbm.binary, pgm.binary, ppm.binary });
    try out.flush();
}
