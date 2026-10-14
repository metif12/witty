const std = @import("std");
const Image = @import("src/Image.zig");
const ImageUnmanaged = @import("src/ImageUnmanaged.zig");
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_disk: []const u8 = "";
var observed_file: std.fs.File = undefined;
var observed_buffer: []const u8 = &.{};
var observed_data: []const u8 = &.{};
fn snapshot(out: *W) !void {
    const data = try std.fs.cwd().readFileAlloc(a, observed_disk, 65536);
    defer a.free(data);
    try out.print("{d}|{x}|{x}|{x}", .{ try observed_file.getPos(), observed_buffer, observed_data, data });
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
fn imageState(out: *W, image: ImageUnmanaged, defined: bool) !void {
    try out.print("{d}:{d}:{d}:{d}:", .{ image.width, image.height, @intFromEnum(image.pixelFormat()), image.pixels.len() });
    if (defined) try out.print("{x}", .{image.rawBytes()}) else try out.writeByte('-');
    try out.print(":{d}:{d}", .{ image.animation.loop_count, image.animation.frames.items.len });
    for (image.animation.frames.items) |frame| {
        try out.print(";{d}:{d}:{d}:", .{ @intFromEnum(std.meta.activeTag(frame.pixels)), frame.pixels.len(), @as(u32, @bitCast(frame.duration)) });
        if (defined) try out.print("{x}", .{frame.pixels.asBytes()}) else try out.writeByte('-');
    }
}
fn detect(route: u8, file: std.fs.File, path: []const u8, data: []const u8, buffer: []u8) !Image.Format {
    return switch (route) {
        0 => ImageUnmanaged.detectFormatFromFile(file, buffer),
        1 => Image.detectFormatFromFile(file, buffer),
        2 => ImageUnmanaged.detectFormatFromFilePath(path, buffer),
        3 => Image.detectFormatFromFilePath(path, buffer),
        4 => ImageUnmanaged.detectFormatFromMemory(data),
        else => Image.detectFormatFromMemory(data),
    };
}
fn decode(route: u8, file: std.fs.File, path: []const u8, data: []const u8, buffer: []u8) !ImageUnmanaged {
    return switch (route) {
        0 => ImageUnmanaged.fromFile(a, file, buffer),
        1 => (try Image.fromFile(a, file, buffer)).toUnmanaged(),
        2 => ImageUnmanaged.fromFilePath(a, path, buffer),
        3 => (try Image.fromFilePath(a, path, buffer)).toUnmanaged(),
        4 => ImageUnmanaged.fromMemory(a, data),
        else => (try Image.fromMemory(a, data)).toUnmanaged(),
    };
}
fn number(comptime T: type, v: []const u8) !T {
    return std.fmt.parseInt(T, v, 10);
}
fn record(line: []const u8, path: []const u8, out: *W, ready: bool) !void {
    var f: [6][]const u8 = undefined;
    var it = std.mem.splitScalar(u8, line, '|');
    for (&f) |*field| field.* = it.next().?;
    const cap = try number(usize, f[0]);
    const op = try number(u8, f[1]);
    const route = try number(u8, f[2]);
    const data = try a.alloc(u8, f[5].len / 2);
    defer a.free(data);
    _ = try std.fmt.hexToBytes(data, f[5]);
    const buffer = try a.alloc(u8, cap);
    defer a.free(buffer);
    @memset(buffer, 165);
    try std.fs.cwd().writeFile(.{ .sub_path = path, .data = data });
    const file = try std.fs.cwd().openFile(path, .{ .mode = .read_write });
    defer file.close();
    try file.seekTo(data.len);
    observed_file = file;
    observed_disk = path;
    observed_buffer = buffer;
    observed_data = data;
    if (ready) {
        var output = std.fs.File.stdout().writer(&.{});
        try output.interface.writeAll("ready|");
        try snapshot(&output.interface);
        try output.interface.writeByte('\n');
        try output.interface.flush();
    }
    try snapshot(out);
    try out.writeByte('~');
    for (0..try number(usize, f[3])) |_| {
        var status: []const u8 = "ok";
        var result = W.Allocating.init(a);
        defer result.deinit();
        if (op == 0) {
            if (detect(route, file, path, data, buffer)) |value| {
                try result.writer.print("{s}", .{@tagName(value)});
            } else |err| {
                status = @errorName(err);
            }
        } else {
            if (decode(route, file, path, data, buffer)) |decoded| {
                var image = decoded;
                defer image.deinit(a);
                try imageState(&result.writer, image, std.mem.eql(u8, f[4], "1"));
            } else |err| {
                status = @errorName(err);
            }
        }
        try out.print("{s}:{s}|", .{ status, if (std.mem.eql(u8, status, "ok")) result.written() else "-" });
        try snapshot(out);
        try out.writeByte('~');
    }
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args);
    var row = W.Allocating.init(a);
    defer row.deinit();
    var output = std.fs.File.stdout().writer(&.{});
    if (std.mem.eql(u8, args[1], "--trap")) {
        observed_path = args[2];
        const path = try std.fmt.allocPrint(a, "{s}.bin", .{args[2]});
        defer a.free(path);
        try record(args[3], path, &row.writer, false);
        try output.interface.print("{s}\n", .{row.written()});
        return;
    }
    if (std.mem.eql(u8, args[1], "--loop")) {
        try record(args[2], args[3], &row.writer, true);
        try output.interface.print("{s}\n", .{row.written()});
        return;
    }
    const data = try std.fs.cwd().readFileAlloc(a, args[1], 32 * 1024 * 1024);
    defer a.free(data);
    const path = try std.fmt.allocPrint(a, "{s}.zig.bin", .{args[1]});
    defer a.free(path);
    var lines = std.mem.splitScalar(u8, data, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        row.clearRetainingCapacity();
        try record(line, path, &row.writer, false);
        try output.interface.print("{s}\n", .{row.written()});
    }
}
