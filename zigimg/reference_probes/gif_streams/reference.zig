const std = @import("std");
const p = @import("src/formats/gif.zig");
const Image = @import("src/ImageUnmanaged.zig");
const io = @import("src/io.zig");
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_codec: ?*p.GIF = null;
var observed_reader: ?*io.ReadStream = null;
var observed_buffer: []const u8 = &.{};
var observed_data: []const u8 = &.{};
var observed_disk: ?[]const u8 = null;
var observed_private = false;
var observed_comments = false;
var observed_ready: ?[]const u8 = null;
fn packedBytes(out: *W, value: anytype) !void {
    try out.print("{x}", .{std.mem.asBytes(&value)});
}
fn snapshot(out: *W) !void {
    const reader = observed_reader.?;
    // A failed toss increments seek before asserting. bufferedLen and file
    // logicalPos then underflow; do not call them from the panic observer.
    if (reader.reader().seek > reader.reader().end) {
        switch (reader.*) {
            .memory => |memory| try out.print("{d}:-", .{memory.seek}),
            .file => try out.writeAll("-:-"),
        }
    } else try out.print("{d}:{d}", .{ reader.getPos(), reader.reader().bufferedLen() });
    try out.print("|{x}|", .{observed_buffer});
    if (observed_private) try out.writeByte('-') else {
        const codec = observed_codec.?;
        try packedBytes(out, codec.header);
        try out.print(":{x}:{d}:", .{ std.mem.sliceAsBytes(codec.global_color_table.data), codec.frames.items.len });
        for (codec.frames.items) |frame| {
            if (frame.graphics_control) |control| try packedBytes(out, control) else try out.writeByte('-');
            try out.writeByte(':');
            for (frame.sub_images.items) |image| {
                try packedBytes(out, image.image_descriptor);
                try out.print(":{d}:{d},", .{ image.local_color_table.data.len, image.pixels.len });
            }
            try out.writeByte(';');
        }
        try out.print(":{d}:", .{codec.comments.items.len});
        if (observed_comments) for (codec.comments.items) |comment| {
            try out.print("{x};", .{comment.comment});
        };
        try out.writeByte(':');
        for (codec.application_infos.items) |info| try out.print("{x}{x}:{x};", .{ info.application_identifier, info.authentification_code, info.data });
    }
    try out.print("|{x}|", .{observed_data});
    if (observed_disk) |path| {
        const data = try std.fs.cwd().readFileAlloc(a, path, 65536);
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
fn emitFrame(out: *W, value: Image.AnimationFrame) !void {
    const raw = value.pixels.asBytes();
    const before = try a.dupe(u8, raw);
    defer a.free(before);
    if (raw.len > 0) raw[0] ^= 1;
    try out.print("{d}:", .{@intFromEnum(std.meta.activeTag(value.pixels))});
    try packedBytes(out, value.duration);
    try out.print(":{x}:{x}:", .{ before, raw });
    if (value.pixels.getPalette()) |pal| {
        try out.print("{x}:", .{std.mem.sliceAsBytes(pal)});
        if (pal.len > 0) pal[0].g ^= 85;
        try out.print("{x};", .{std.mem.sliceAsBytes(pal)});
    } else try out.writeAll("-:-;");
}
fn record(line: []const u8, path: []const u8, out: *W) !void {
    var f: [6][]const u8 = undefined;
    var it = std.mem.splitScalar(u8, line, '|');
    for (&f) |*field| field.* = it.next().?;
    const cap = try std.fmt.parseInt(i32, f[0], 10);
    const op = try std.fmt.parseInt(u8, f[1], 10);
    const data = try a.alloc(u8, f[5].len / 2);
    defer a.free(data);
    _ = try std.fmt.hexToBytes(data, f[5]);
    var codec = p.GIF.init(a);
    defer codec.deinit();
    codec.header = .{ .magic = "OLD".*, .version = "TST".*, .width = 7, .height = 9, .flags = @bitCast(@as(u8, 1)), .background_color_index = 2, .pixel_aspect_ratio = 3 };
    codec.global_color_table.resize(256);
    for (codec.global_color_table.data, 0..) |*color, i| color.* = .{ .r = @truncate(i * 31), .g = @truncate(i * 71), .b = @truncate(i * 47) };
    codec.global_color_table.resize(4);
    const buffer = try a.alloc(u8, if (cap < 0) 0 else @intCast(cap));
    defer a.free(buffer);
    @memset(buffer, 165);
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
    observed_codec = &codec;
    observed_reader = &reader;
    observed_buffer = buffer;
    observed_data = data;
    observed_private = op == 1 or op == 2;
    observed_comments = false;
    const start = try std.fmt.parseInt(usize, f[2], 10);
    if (start > 0) try reader.reader().discardAll(start);
    if (observed_ready) |ready| {
        const ready_file = try std.fs.cwd().createFile(ready, .{});
        defer ready_file.close();
        var ready_buffer: [8192]u8 = undefined;
        var ready_writer = ready_file.writer(&ready_buffer);
        try snapshot(&ready_writer.interface);
        try ready_writer.interface.flush();
    }
    const iface = p.GIF.formatInterface();
    var poisoned_comments = false;
    for (0..try std.fmt.parseInt(usize, f[3], 10)) |_| {
        observed_comments = false;
        if (op == 3 or op == 4) {
            var status: []const u8 = "ok";
            const found = (if (op == 3) p.GIF.formatDetect(&reader) else iface.formatDetect(&reader)) catch |err| blk: {
                status = @errorName(err);
                break :blk false;
            };
            try out.print("{s}:{d}|", .{ status, @intFromBool(found) });
            try snapshot(out);
            try out.writeByte('~');
            continue;
        }
        if (op == 0) {
            var frames = codec.read(&reader) catch |err| {
                poisoned_comments = poisoned_comments or codec.comments.items.len > 0;
                try out.print("{s}|", .{@errorName(err)});
                try snapshot(out);
                try out.writeByte('~');
                continue;
            };
            defer {
                for (frames.items) |value| value.deinit(a);
                frames.deinit(a);
            }
            observed_comments = !poisoned_comments;
            try out.writeAll("ok:");
            if (std.mem.eql(u8, f[4], "1")) try out.print("{d}", .{codec.loopCount()}) else try out.writeByte('-');
            try out.print(":{d}|", .{frames.items.len});
            for (frames.items) |value| try emitFrame(out, value);
        } else {
            var image = (if (op == 1) p.GIF.readImage(a, &reader) else iface.readImage(a, &reader)) catch |err| {
                try out.print("{s}|", .{@errorName(err)});
                try snapshot(out);
                try out.writeByte('~');
                continue;
            };
            defer image.deinit(a);
            try out.print("ok:{d}:{d}:{d}:{d}|", .{ image.animation.loop_count, image.animation.frames.items.len, image.width, image.height });
            for (image.animation.frames.items) |value| try emitFrame(out, value);
            try out.print("main:{x}|", .{image.rawBytes()});
        }
        try snapshot(out);
        try out.writeByte('~');
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
        if (std.mem.eql(u8, args[1], "--loop")) observed_ready = try std.fmt.allocPrint(a, "{s}.ready", .{args[2]});
        const path = try std.fmt.allocPrint(a, "{s}.bin", .{args[2]});
        defer a.free(path);
        try record(args[3], path, out);
        try out.writeByte('\n');
    }
    try out.flush();
}
