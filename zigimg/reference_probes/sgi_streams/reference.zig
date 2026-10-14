const std = @import("std");
const p = @import("src/formats/sgi.zig");
const io = @import("src/io.zig");
const Image = @import("src/ImageUnmanaged.zig");
const color = @import("src/color.zig");
const Header = @TypeOf((p.SGI{}).header);
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_codec: ?*p.SGI = null;
var observed_reader: ?*io.ReadStream = null;
var observed_writer: ?*io.WriteStream = null;
var observed_buffer: []const u8 = &.{};
var observed_output: []const u8 = &.{};
var observed_data: []const u8 = &.{};
var observed_disk: ?[]const u8 = null;

fn snapshot(out: *W) !void {
    if (observed_reader) |reader| try out.print("{d}:{d}", .{ reader.getPos(), reader.reader().bufferedLen() }) else {
        const writer = observed_writer.?;
        try out.print("{d}:{d}", .{ writer.getPos(), writer.writer().buffered().len });
    }
    const codec = observed_codec.?;
    try out.print("|{x}|{x}|{x}:{d}:{x}|{x}|", .{ observed_buffer, observed_output, std.mem.asBytes(&codec.header), codec.palette.data.len, std.mem.sliceAsBytes(&codec.palette.storage), observed_data });
    if (observed_disk) |path| {
        const data = try std.fs.cwd().readFileAlloc(a, path, 1048576);
        defer a.free(data);
        try out.print("{x}", .{data});
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
fn record(line: []const u8, path: []const u8, out: *W) !void {
    var f: [10][]const u8 = undefined;
    var it = std.mem.splitScalar(u8, line, '|');
    for (&f) |*field| field.* = it.next().?;
    const cap = try std.fmt.parseInt(i32, f[0], 10);
    const op = try std.fmt.parseInt(u8, f[1], 10);
    const start = try std.fmt.parseInt(usize, f[2], 10);
    const attempts = try std.fmt.parseInt(usize, f[3], 10);
    const data = try a.alloc(u8, f[9].len / 2);
    defer a.free(data);
    _ = try std.fmt.hexToBytes(data, f[9]);
    var codec = p.SGI{ .header = Header{
        .compression = if (op == 1) .uncompressed else .rle,
        .bytes_per_channel = try std.fmt.parseInt(u8, f[4], 10),
        .dimension = .single_channel,
        .x_size = try std.fmt.parseInt(u16, f[5], 10),
        .y_size = try std.fmt.parseInt(u16, f[6], 10),
        .z_size = try std.fmt.parseInt(u16, f[7], 10),
        .pix_min = 123,
        .pix_max = 456,
        .dummy1 = 789,
        .image_name = @splat(165),
        .pixel_format = .normal,
        .dummy2 = @splat(165),
    } };
    codec.palette.resize(256);
    for (codec.palette.data, 0..) |*entry, i| entry.* = .{ .r = @truncate(i * 31), .g = @truncate(i * 71), .b = @truncate(i * 47), .a = 99 };
    codec.palette.resize(4);
    const buffer = try a.alloc(u8, if (cap < 0) (if (op >= 5) @as(usize, 32) else 0) else @intCast(cap));
    defer a.free(buffer);
    @memset(buffer, 165);
    const output = try a.alloc(u8, try std.fmt.parseInt(usize, f[8], 10));
    defer a.free(output);
    @memset(output, 165);
    var file: ?std.fs.File = null;
    defer if (file) |value| value.close();
    observed_codec = &codec;
    observed_buffer = buffer;
    observed_output = output;
    observed_data = data;
    observed_disk = null;
    observed_reader = null;
    observed_writer = null;
    const iface = p.SGI.formatInterface();
    if (op >= 5) {
        var writer = io.WriteStream.initMemory(buffer);
        if (cap >= 0) {
            try std.fs.cwd().writeFile(.{ .sub_path = path, .data = data });
            file = try std.fs.cwd().openFile(path, .{ .mode = .read_write });
            try file.?.seekTo(data.len);
            writer = io.WriteStream.initFile(file.?, buffer);
            observed_disk = path;
        }
        observed_writer = &writer;
        try writer.seekTo(start);
        try writer.writer().writeAll(&.{ 17, 18, 19 });
        var image = Image{ .width = 7, .height = 9, .pixels = try color.PixelStorage.init(a, .rgb24, 2) };
        defer image.deinit(a);
        for (image.pixels.asBytes(), 0..) |*byte, i| byte.* = @truncate(i * 37 + 19);
        try out.writeAll("before|");
        try snapshot(out);
        try out.print("|{x}~", .{image.rawBytes()});
        for (0..attempts) |_| {
            if (op == 5) try p.SGI.writeImage(a, &writer, image, .{ .sgi = {} }) else try iface.writeImage(a, &writer, image, .{ .sgi = {} });
            try out.writeAll("ok|");
            try snapshot(out);
            try out.print("|{x}~", .{image.rawBytes()});
        }
        try writer.flush();
        try out.writeAll("flush|");
        try snapshot(out);
        try out.writeByte('~');
        return;
    }
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
        if (op == 2 or op == 3) {
            var status: []const u8 = "ok";
            const found = (if (op == 2) p.SGI.formatDetect(&reader) else iface.formatDetect(&reader)) catch |err| blk: {
                status = @errorName(err);
                break :blk false;
            };
            try out.print("{s}:{d}|", .{ status, @intFromBool(found) });
            try snapshot(out);
            try out.writeByte('~');
        } else if (op == 4) {
            const pixels = codec.read(a, &reader) catch |err| {
                try out.print("{s}|", .{@errorName(err)});
                try snapshot(out);
                try out.writeByte('~');
                continue;
            };
            defer pixels.deinit(a);
            const raw = pixels.asBytes();
            const before = try a.dupe(u8, raw);
            defer a.free(before);
            if (raw.len > 0) raw[0] ^= 1;
            try out.print("ok:{d}:{x}:{x}|", .{ @intFromEnum(std.meta.activeTag(pixels)), before, raw });
            try snapshot(out);
            try out.writeByte('~');
        } else {
            codec.uncompressBitmap(a, &reader, output) catch |err| {
                try out.print("{s}|", .{@errorName(err)});
                try snapshot(out);
                try out.writeByte('~');
                continue;
            };
            try out.writeAll("ok|");
            try snapshot(out);
            try out.writeByte('~');
        }
    }
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args);
    var buffer: [8192]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&buffer);
    const out = &writer.interface;
    if (std.mem.eql(u8, args[1], "--corpus")) {
        const data = try std.fs.cwd().readFileAlloc(a, args[2], 1073741824);
        defer a.free(data);
        const path = try std.fmt.allocPrint(a, "{s}.native.bin", .{args[2]});
        defer a.free(path);
        var lines = std.mem.splitScalar(u8, data, '\n');
        while (lines.next()) |line| {
            if (line.len == 0) continue;
            try record(line, path, out);
            try out.writeByte('\n');
        }
    } else {
        observed_path = args[2];
        const path = try std.fmt.allocPrint(a, "{s}.bin", .{args[2]});
        defer a.free(path);
        try record(args[3], path, out);
        try out.writeByte('\n');
    }
    try out.flush();
}
