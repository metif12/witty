const std = @import("std");
const p = @import("src/formats/pam.zig");
const color = @import("src/color.zig");
const Image = @import("src/ImageUnmanaged.zig");
const Format = @import("src/pixel_format.zig").PixelFormat;
const io = @import("src/io.zig");
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_reader: ?*const io.ReadStream = null;
var observed_writer: ?*const io.WriteStream = null;
var observed_image: ?*const Image = null;
var observed_input: []const u8 = &.{};
var observed_output: []const u8 = &.{};
var observed_comments: []const []const u8 = &.{};
var observed_op: usize = 0;
fn imageText(out: *W, image: Image) !void {
    try out.print("{d}:{d}:{d}:{d}:{x}:{d}:{d}", .{ image.width, image.height, @intFromEnum(std.meta.activeTag(image.pixels)), image.pixels.len(), image.rawBytes(), image.animation.loop_count, image.animation.frames.items.len });
    for (image.animation.frames.items) |frame| try out.print(":{d}:{d}:{x}:{d}", .{ @intFromEnum(std.meta.activeTag(frame.pixels)), frame.pixels.len(), frame.pixels.asBytes(), @as(u32, @bitCast(frame.duration)) });
}
fn commentText(out: *W, values: []const []const u8) !void {
    try out.print("{d}", .{values.len});
    for (values) |value| try out.print(":{x}", .{value});
}
fn state(out: *W) !void {
    try out.print("{d}|{d}|{x}|{x}|", .{ observed_reader.?.getPos(), observed_writer.?.getPos(), observed_input, observed_output });
    if (observed_op >= 3) try imageText(out, observed_image.?.*) else try out.writeByte('-');
    try out.writeByte('|');
    try commentText(out, observed_comments);
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
fn case_comments(variant: usize) []const []const u8 {
    return switch (variant) {
        1 => &.{ "one", "two" },
        2 => &.{ "", "x\ny\r", "π" },
        3 => &.{"\xff\x00#%{x}"},
        else => &.{},
    };
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
fn options(tag: u8, comments: []const []const u8, duration: bool) Image.EncoderOptions {
    return switch (tag) {
        0 => .{ .bmp = .{} },
        1 => .{ .farbfeld = {} },
        2 => .{ .gif = {} },
        3 => .{ .iff = {} },
        4 => .{ .jpeg = {} },
        5 => .{ .pam = .{ .comments = comments, .add_duration_as_comment = duration } },
        6 => .{ .pbm = .{ .binary = true } },
        7 => .{ .pcx = .{} },
        8 => .{ .pgm = .{ .binary = true } },
        9 => .{ .png = .{} },
        10 => .{ .ppm = .{ .binary = true } },
        11 => .{ .qoi = .{} },
        12 => .{ .ras = {} },
        13 => .{ .sgi = {} },
        14 => .{ .tga = .{} },
        15 => .{ .tiff = {} },
        else => .{ .xbm = {} },
    };
}
fn imageRecord(out: *W, image: Image, data: []const u8) !void {
    try imageText(out, image);
    const raw = image.pixels.asBytes();
    var separate: []const u8 = "-";
    if (raw.len > 0) {
        const ptr = @intFromPtr(raw.ptr);
        separate = if (ptr < @intFromPtr(data.ptr) or ptr >= @intFromPtr(data.ptr) + data.len) "1" else "0";
        raw[0] ^= 1;
    }
    var independent: []const u8 = "1";
    for (image.animation.frames.items) |frame| {
        const bytes = frame.pixels.asBytes();
        if (bytes.len > 0) {
            if (bytes.ptr == raw.ptr) independent = "0";
            bytes[0] ^= 1;
        }
    }
    try out.print("|{s}|{s}|", .{ separate, independent });
    try imageText(out, image);
}
fn num(f: [16][]const u8, i: usize) !usize {
    return std.fmt.parseInt(usize, f[i], 10);
}
fn lineCase(line: []const u8, out: *W) !void {
    var parts = std.mem.splitScalar(u8, line, '|');
    var f: [16][]const u8 = undefined;
    for (&f) |*field| field.* = parts.next().?;
    const op = try num(f, 0);
    const data = try a.alloc(u8, f[15].len / 2);
    defer a.free(data);
    _ = try std.fmt.hexToBytes(data, f[15]);
    var reader = io.ReadStream.initMemory(data);
    const output = try a.alloc(u8, try num(f, 5));
    defer a.free(output);
    @memset(output, 165);
    var writer = io.WriteStream.initMemory(output);
    const start = try num(f, 6);
    if (start > 0) {
        if (op >= 3) try writer.seekTo(start) else _ = try reader.reader().take(start);
    }
    observed_reader = &reader;
    observed_writer = &writer;
    observed_input = data;
    observed_output = output;
    observed_comments = case_comments(try num(f, 9));
    observed_op = op;
    if (op == 2) {
        var status: []const u8 = "ok";
        const result = p.PAM.formatDetect(&reader) catch |err| blk: {
            status = @errorName(err);
            break :blk false;
        };
        try out.print("{s}|{d}|", .{ status, @intFromBool(result) });
        try state(out);
        try out.writeByte('\n');
        return;
    }
    if (op >= 3) {
        var image = Image{ .width = try num(f, 3), .height = try num(f, 4), .pixels = try pixels(@enumFromInt(try num(f, 1)), try num(f, 2)) };
        defer image.pixels.deinit(a);
        defer image.animation.frames.deinit(a);
        image.animation.loop_count = try std.fmt.parseInt(i32, f[13], 10);
        const duration: f32 = @bitCast(try std.fmt.parseInt(u32, f[14], 10));
        for (0..try num(f, 12)) |_| try image.animation.frames.append(a, .{ .pixels = try pixels(@enumFromInt(try num(f, 10)), try num(f, 11)), .duration = duration });
        defer for (image.animation.frames.items) |frame| frame.pixels.deinit(a);
        observed_image = &image;
        const selected = options(@intCast(try num(f, 7)), observed_comments, (try num(f, 8)) != 0);
        var status: []const u8 = "ok";
        if (op == 3) p.PAM.writeFrame(writer.writer(), image, selected) catch |err| {
            status = @errorName(err);
        } else if (op == 4) p.PAM.writeImage(a, &writer, image, selected) catch |err| {
            status = @errorName(err);
        } else {
            const iface = p.PAM.formatInterface();
            iface.writeImage(a, &writer, image, selected) catch |err| {
                status = @errorName(err);
            };
        }
        try out.print("{s}|", .{status});
        try state(out);
        try out.writeByte('\n');
        return;
    }
    if (op == 0) {
        var images = p.PAM.read(a, &reader) catch |err| {
            try out.print("{s}|", .{@errorName(err)});
            try state(out);
            try out.writeByte('\n');
            return;
        };
        defer images.deinit(a);
        defer for (images.items) |image| image.pixels.deinit(a);
        try out.print("ok|{d}", .{images.items.len});
        for (images.items) |image| {
            try out.writeByte('|');
            try imageRecord(out, image, data);
        }
    } else {
        var image = p.PAM.readImage(a, &reader) catch |err| {
            try out.print("{s}|", .{@errorName(err)});
            try state(out);
            try out.writeByte('\n');
            return;
        };
        defer image.pixels.deinit(a);
        defer image.animation.frames.deinit(a);
        defer for (image.animation.frames.items) |frame| frame.pixels.deinit(a);
        try out.writeAll("ok|1|");
        try imageRecord(out, image, data);
    }
    try out.writeByte('|');
    try state(out);
    try out.writeByte('\n');
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
    var backing = [_][]const u8{ "one", "two" };
    var value = p.PAM.EncoderOptions{ .comments = &backing };
    try commentText(out, value.comments);
    try out.print("|{}\n", .{value.add_duration_as_comment});
    const copy = value;
    backing[0] = "changed";
    try commentText(out, value.comments);
    try out.writeByte('|');
    try commentText(out, copy.comments);
    try out.writeByte('\n');
    value.comments = &.{"replaced"};
    value.add_duration_as_comment = true;
    try commentText(out, value.comments);
    try out.print("|{}|", .{value.add_duration_as_comment});
    try commentText(out, copy.comments);
    try out.print("|{}\n", .{copy.add_duration_as_comment});
    try out.flush();
}
