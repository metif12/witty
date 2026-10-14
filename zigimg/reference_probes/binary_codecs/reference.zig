const std = @import("std");
const ff = @import("src/formats/farbfeld.zig");
const q = @import("src/formats/qoi.zig");
const Image = @import("src/ImageUnmanaged.zig");
const color = @import("src/color.zig");
const io = @import("src/io.zig");
const Format = @import("src/pixel_format.zig").PixelFormat;
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_reader: ?*io.ReadStream = null;
var observed_writer: ?*io.WriteStream = null;
var observed_buffer: []const u8 = &.{};
var observed_data: []const u8 = &.{};
var observed_disk: ?[]const u8 = null;
var observed_ff: ?*const ff.Header = null;
var observed_qoi: ?*const q.Header = null;
var observed_image: ?*const Image = null;

fn pixelsText(out: *W, pixels: color.PixelStorage) !void {
    try out.print("{d}:{d}:", .{ @intFromEnum(std.meta.activeTag(pixels)), pixels.len() });
    switch (pixels) {
        .grayscale1 => |values| for (values) |value| try out.print("{x:0>2}", .{@as(u8, value.value)}),
        else => try out.print("{x}", .{pixels.asBytes()}),
    }
}
fn imageText(out: *W, image: Image) !void {
    try out.print("{d}:{d}:", .{ image.width, image.height });
    try pixelsText(out, image.pixels);
    try out.print(":{d}:{d}", .{ image.animation.loop_count, image.animation.frames.items.len });
    for (image.animation.frames.items) |frame| {
        try out.writeByte(':');
        try pixelsText(out, frame.pixels);
        try out.print(":{d}", .{@as(u32, @bitCast(frame.duration))});
    }
}
fn snapshot(out: *W) !void {
    if (observed_reader) |reader| try out.print("{d}:{d}", .{ reader.getPos(), reader.reader().bufferedLen() }) else {
        const writer = observed_writer.?;
        try out.print("{d}:{d}", .{ writer.getPos(), writer.writer().buffered().len });
    }
    try out.print("|{x}|{x}|", .{ observed_buffer, observed_data });
    if (observed_disk) |path| {
        const bytes = try std.fs.cwd().readFileAlloc(a, path, 65536);
        defer a.free(bytes);
        try out.print("{x}", .{bytes});
    } else try out.writeByte('-');
    try out.writeByte('|');
    if (observed_ff) |h| try out.print("{d}:{d}", .{ h.width, h.height }) else if (observed_qoi) |h| try out.print("{d}:{d}:{d}:{d}", .{ h.width, h.height, @intFromEnum(h.format), @intFromEnum(h.colorspace) }) else try out.writeByte('-');
    try out.writeByte('|');
    if (observed_image) |image| try imageText(out, image.*) else try out.writeByte('-');
}
fn observe(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var bytes: [8192]u8 = undefined;
            var writer = file.writer(&bytes);
            snapshot(&writer.interface) catch {};
            writer.interface.flush() catch {};
        } else |_| {}
    }
    std.debug.defaultPanic(message, address);
}
fn makePixels(allocator: std.mem.Allocator, format: Format, count: usize, pattern: u8, data: []const u8) !color.PixelStorage {
    const result = try color.PixelStorage.init(allocator, format, count);
    const raw = result.asBytes();
    for (raw, 0..) |*byte, i| byte.* = if (pattern == 1) 0 else if (pattern == 2) 255 else @truncate(i * 37 + 19);
    if (data.len > 0) {
        std.debug.assert(data.len == raw.len);
        @memcpy(raw, data);
    }
    switch (result) {
        .grayscale1 => for (raw, 0..) |*byte, i| {
            byte.* = @intCast(i & 1);
        },
        .grayscale2 => for (raw, 0..) |*byte, i| {
            byte.* = @intCast(i & 3);
        },
        .grayscale4 => for (raw, 0..) |*byte, i| {
            byte.* = @intCast(i & 15);
        },
        .indexed1, .indexed2, .indexed4 => {
            const mask: u8 = if (format == .indexed1) 1 else if (format == .indexed2) 3 else 15;
            for (raw) |*byte| byte.* &= mask;
        },
        .rgb555, .bgr555 => for (0..count) |i| {
            raw[i * 2 + 1] &= 127;
        },
        else => {},
    }
    return result;
}
fn codecRecord(comptime Codec: type, fields: [14][]const u8, path: []const u8, allocator: std.mem.Allocator, out: *W) !void {
    const capacity = try std.fmt.parseInt(i32, fields[0], 10);
    const op = try std.fmt.parseInt(u8, fields[1], 10);
    const start = try std.fmt.parseInt(usize, fields[3], 10);
    const attempts = try std.fmt.parseInt(usize, fields[4], 10);
    const data = try allocator.alloc(u8, fields[13].len / 2);
    _ = try std.fmt.hexToBytes(data, fields[13]);
    const buffer = try allocator.alloc(u8, if (capacity < 0) 0 else @intCast(capacity));
    @memset(buffer, 165);
    var codec: Codec = if (Codec == ff.Farbfeld) .{ .header = .{
        .width = @truncate(try std.fmt.parseInt(usize, fields[5], 10)),
        .height = @truncate(try std.fmt.parseInt(usize, fields[6], 10)),
    } } else .{ .header = .{
        .width = @truncate(try std.fmt.parseInt(usize, fields[5], 10)),
        .height = @truncate(try std.fmt.parseInt(usize, fields[6], 10)),
        .format = @enumFromInt(try std.fmt.parseInt(u8, fields[7], 10)),
        .colorspace = @enumFromInt(try std.fmt.parseInt(u8, fields[8], 10)),
    } };
    observed_reader = null;
    observed_writer = null;
    observed_ff = null;
    observed_qoi = null;
    if (op == 0 or op == 3) {
        if (Codec == ff.Farbfeld) observed_ff = &codec.header else observed_qoi = &codec.header;
    }
    observed_image = null;
    observed_disk = null;
    observed_data = data;
    observed_buffer = buffer;
    var file: ?std.fs.File = null;
    defer if (file) |f| f.close();
    if (op < 3 or op == 5) {
        var reader = io.ReadStream.initMemory(data);
        if (capacity >= 0) {
            try std.fs.cwd().writeFile(.{ .sub_path = path, .data = data });
            file = try std.fs.cwd().openFile(path, .{});
            try file.?.seekTo(data.len);
            reader = io.ReadStream.initFile(file.?, buffer);
            observed_disk = path;
        }
        observed_reader = &reader;
        if (start > 0) try reader.reader().discardAll(start);
        for (0..attempts) |_| {
            if (op == 2) {
                var status: []const u8 = "ok";
                const found = Codec.formatDetect(&reader) catch |err| blk: {
                    status = @errorName(err);
                    break :blk false;
                };
                try out.print("{s}:{d}|", .{ status, @intFromBool(found) });
            } else if (op == 0) {
                const result = codec.read(allocator, &reader);
                if (result) |value| {
                    try out.writeAll("ok|");
                    try pixelsText(out, value);
                    try out.writeByte('|');
                } else |err| try out.print("{s}|", .{@errorName(err)});
            } else {
                const result = if (op == 5) Codec.formatInterface().readImage(allocator, &reader) else Codec.readImage(allocator, &reader);
                if (result) |image| {
                    try out.writeAll("ok|");
                    try imageText(out, image);
                    try out.writeByte('|');
                } else |err| try out.print("{s}|", .{@errorName(err)});
            }
            try snapshot(out);
            try out.writeByte('~');
        }
        return;
    }
    var writer = io.WriteStream.initMemory(buffer);
    if (capacity >= 0) {
        const initial = [_]u8{165} ** 256;
        try std.fs.cwd().writeFile(.{ .sub_path = path, .data = &initial });
        file = try std.fs.cwd().openFile(path, .{ .mode = .read_write });
        try file.?.seekTo(256);
        writer = io.WriteStream.initFile(file.?, buffer);
        observed_disk = path;
    }
    observed_writer = &writer;
    if (start > 0) try writer.seekTo(start);
    var image = Image{
        .pixels = try makePixels(allocator, @enumFromInt(try std.fmt.parseInt(u32, fields[9], 10)), try std.fmt.parseInt(usize, fields[10], 10), try std.fmt.parseInt(u8, fields[11], 10), data),
        .width = try std.fmt.parseInt(usize, fields[5], 10),
        .height = try std.fmt.parseInt(usize, fields[6], 10),
    };
    observed_image = &image;
    const options: Image.EncoderOptions = if (std.mem.eql(u8, fields[12], "9"))
        .{ .qoi = .{ .colorspace = @enumFromInt(try std.fmt.parseInt(u8, fields[8], 10)) } }
    else
        .{ .bmp = .{} };
    for (0..attempts) |_| {
        const status: []const u8 = blk: {
            if (op == 3) codec.write(&writer, image.pixels) catch |err| break :blk @errorName(err) else if (op == 4) Codec.writeImage(allocator, &writer, image, options) catch |err| break :blk @errorName(err) else Codec.formatInterface().writeImage(allocator, &writer, image, options) catch |err| break :blk @errorName(err);
            break :blk "ok";
        };
        try out.print("{s}|", .{status});
        try snapshot(out);
        try out.writeByte('~');
    }
    try writer.flush();
    try out.writeAll("flush|");
    try snapshot(out);
}
fn record(line: []const u8, path: []const u8, allocator: std.mem.Allocator, out: *W) !void {
    var it = std.mem.splitScalar(u8, line, '|');
    var fields: [14][]const u8 = undefined;
    for (&fields) |*f| f.* = it.next().?;
    switch (try std.fmt.parseInt(u8, fields[2], 10)) {
        0 => try codecRecord(ff.Farbfeld, fields, path, allocator, out),
        else => try codecRecord(q.QOI, fields, path, allocator, out),
    }
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    var bytes: [8192]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&bytes);
    const out = &stdout.interface;
    if (args.len == 4 and std.mem.eql(u8, args[1], "--trap")) {
        observed_path = args[2];
        try record(args[3], try std.fmt.allocPrint(a, "{s}.bin", .{args[2]}), a, out);
        try out.writeByte('\n');
        try out.flush();
        return;
    }
    const input = try std.fs.cwd().readFileAlloc(a, args[1], 64 * 1024 * 1024);
    var lines = std.mem.splitScalar(u8, input, '\n');
    const path = try std.fmt.allocPrint(a, "{s}.zig.bin", .{args[1]});
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var arena = std.heap.ArenaAllocator.init(a);
        defer arena.deinit();
        try record(line, path, arena.allocator(), out);
        try out.writeByte('\n');
    }
    try out.flush();
}
