const std = @import("std");
const p = @import("src/formats/bmp.zig");
const Image = @import("src/ImageUnmanaged.zig");
const color = @import("src/color.zig");
const Format = @import("src/pixel_format.zig").PixelFormat;
const io = @import("src/io.zig");
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_codec: ?*const p.BMP = null;
var observed_reader: ?*io.ReadStream = null;
var observed_writer: ?*io.WriteStream = null;
var observed_buffer: []const u8 = &.{};
var observed_data: []const u8 = &.{};
var observed_disk: ?[]const u8 = null;
var observed_image: ?*const Image = null;

fn info(out: *W, value: p.BitmapInfoHeader) !void {
    switch (value) {
        inline else => |h| try out.print("{d}:{x}", .{ @sizeOf(@TypeOf(h)), std.mem.asBytes(&h) }),
    }
}
fn snapshot(out: *W) !void {
    if (observed_reader) |reader| try out.print("{d}:{d}", .{ reader.getPos(), reader.reader().bufferedLen() }) else {
        const writer = observed_writer.?;
        try out.print("{d}:{d}", .{ writer.getPos(), writer.writer().buffered().len });
    }
    try out.print("|{x}|{x}|", .{ observed_buffer, observed_data });
    if (observed_codec) |codec| {
        try out.print("{x}:", .{std.mem.asBytes(&codec.file_header)});
        try info(out, codec.info_header);
    } else try out.writeByte('-');
    try out.writeByte('|');
    if (observed_image) |image| try out.print("{d}:{d}:{d}:{d}:{x}", .{ image.width, image.height, @intFromEnum(std.meta.activeTag(image.pixels)), image.pixels.len(), image.pixels.asBytes() }) else try out.writeByte('-');
    try out.writeByte('|');
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
            var buffer: [8192]u8 = undefined;
            var writer = file.writer(&buffer);
            snapshot(&writer.interface) catch {};
            writer.interface.flush() catch {};
        } else |_| {}
    }
    std.debug.defaultPanic(message, address);
}
fn makeCodec(kind: usize, width: i32, height: i32) p.BMP {
    return .{ .file_header = .{ .magic_header = .{ 'X', 'Y' }, .size = 1, .reserved = 0x12345678, .pixel_offset = 9000 }, .info_header = switch (kind) {
        40 => .{ .windows31 = .{ .header_size = 40, .width = width, .height = height, .bit_count = 99, .compression_method = .png, .horizontal_resolution = 17 } },
        108 => .{ .v4 = .{ .header_size = 108, .width = width, .height = height, .bit_count = 99, .compression_method = .png, .horizontal_resolution = 17 } },
        else => .{ .v5 = .{ .header_size = 124, .width = width, .height = height, .bit_count = 99, .compression_method = .png, .horizontal_resolution = 17 } },
    } };
}
fn record(line: []const u8, path: []const u8, out: *W) !void {
    var f: [11][]const u8 = undefined;
    var it = std.mem.splitScalar(u8, line, '|');
    for (&f) |*field| field.* = it.next().?;
    const cap = try std.fmt.parseInt(i32, f[0], 10);
    const op = try std.fmt.parseInt(u8, f[1], 10);
    const kind = try std.fmt.parseInt(usize, f[2], 10);
    const start = try std.fmt.parseInt(usize, f[8], 10);
    const attempts = try std.fmt.parseInt(usize, f[9], 10);
    const data = try a.alloc(u8, f[10].len / 2);
    defer a.free(data);
    _ = try std.fmt.hexToBytes(data, f[10]);
    const buffer = try a.alloc(u8, if (cap < 0) 1024 else @intCast(cap));
    defer a.free(buffer);
    @memset(buffer, 165);
    var codec = makeCodec(if (op < 5) 124 else kind, if (op < 5 or op > 5) 7 else try std.fmt.parseInt(i32, f[3], 10), if (op < 5 or op > 5) 9 else try std.fmt.parseInt(i32, f[4], 10));
    observed_codec = if (op == 0 or op == 5) &codec else null;
    observed_reader = null;
    observed_writer = null;
    observed_image = null;
    observed_disk = null;
    observed_buffer = if (cap < 0 and op < 5) &.{} else buffer;
    observed_data = data;
    var file: ?std.fs.File = null;
    defer if (file) |value| value.close();
    const iface = p.BMP.formatInterface();
    if (op < 5) {
        var reader = io.ReadStream.initMemory(data);
        if (cap >= 0) {
            try std.fs.cwd().writeFile(.{ .sub_path = path, .data = data });
            file = try std.fs.cwd().openFile(path, .{});
            try file.?.seekTo(data.len);
            reader = io.ReadStream.initFile(file.?, buffer);
            observed_disk = path;
        }
        observed_reader = &reader;
        if (start > 0) try reader.reader().discardAll(start);
        for (0..attempts) |_| {
            if (op == 3 or op == 4) {
                var status: []const u8 = "ok";
                const found = (if (op == 4) iface.formatDetect(&reader) else p.BMP.formatDetect(&reader)) catch |err| blk: {
                    status = @errorName(err);
                    break :blk false;
                };
                try out.print("{s}:{d}|", .{ status, @intFromBool(found) });
            } else {
                const image = if (op == 0) blk: {
                    const pixels = codec.read(a, &reader) catch |err| {
                        try out.print("{s}|", .{@errorName(err)});
                        try snapshot(out);
                        try out.writeByte('~');
                        continue;
                    };
                    break :blk Image{ .width = if (codec.width() < 0) 0 else @intCast(codec.width()), .height = if (codec.height() < 0) 0 else @intCast(codec.height()), .pixels = pixels };
                } else (if (op == 2) iface.readImage(a, &reader) else p.BMP.readImage(a, &reader)) catch |err| {
                    try out.print("{s}|", .{@errorName(err)});
                    try snapshot(out);
                    try out.writeByte('~');
                    continue;
                };
                defer image.pixels.deinit(a);
                try out.print("ok|{d}:{d}:{d}:{d}:", .{ image.width, image.height, @intFromEnum(std.meta.activeTag(image.pixels)), image.pixels.len() });
                if (op == 0 and (codec.width() < 0 or codec.height() < 0)) try out.writeByte('-') else {
                    const raw = image.pixels.asBytes();
                    try out.print("{x}:", .{raw});
                    if (raw.len > 0) raw[0] ^= 85;
                    try out.print("{x}", .{raw});
                }
                try out.writeByte('|');
            }
            try snapshot(out);
            try out.writeByte('~');
        }
        return;
    }
    var writer = io.WriteStream.initMemory(buffer);
    if (cap >= 0) {
        const initial = [_]u8{165} ** 256;
        try std.fs.cwd().writeFile(.{ .sub_path = path, .data = &initial });
        file = try std.fs.cwd().openFile(path, .{ .mode = .read_write });
        try file.?.seekTo(256);
        writer = io.WriteStream.initFile(file.?, buffer);
        observed_disk = path;
    }
    observed_writer = &writer;
    if (start > 0) try writer.seekTo(start);
    const pixels = try color.PixelStorage.init(a, @as(Format, @enumFromInt(try std.fmt.parseInt(u32, f[5], 10))), try std.fmt.parseInt(usize, f[6], 10));
    defer pixels.deinit(a);
    const pattern = try std.fmt.parseInt(u8, f[7], 10);
    for (pixels.asBytes(), 0..) |*byte, i| byte.* = if (pattern == 1) 0 else if (pattern == 2) 255 else @truncate(i * 37 + 19);
    const image = Image{ .width = if (op == 5) 17 else try std.fmt.parseInt(usize, f[3], 10), .height = if (op == 5) 19 else try std.fmt.parseInt(usize, f[4], 10), .pixels = pixels };
    observed_image = &image;
    for (0..attempts) |_| {
        var status: []const u8 = "ok";
        if (op == 5) codec.write(&writer, pixels) catch |err| {
            status = @errorName(err);
        } else if (op == 6) p.BMP.writeImage(a, &writer, image, .{ .bmp = .{} }) catch |err| {
            status = @errorName(err);
        } else iface.writeImage(a, &writer, image, .{ .qoi = .{ .colorspace = .linear } }) catch |err| {
            status = @errorName(err);
        };
        try out.print("{s}|", .{status});
        try snapshot(out);
        try out.writeByte('~');
    }
    try writer.writer().flush();
    try out.writeAll("flush|");
    try snapshot(out);
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
