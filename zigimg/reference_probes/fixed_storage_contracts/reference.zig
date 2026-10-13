const std = @import("std");
const color = @import("src/color.zig");
const fixed = @import("src/utils.zig").FixedStorage;
const W = std.Io.Writer;
const a = std.heap.page_allocator;
pub const panic = std.debug.FullPanic(observe);
var path: ?[]const u8 = null;
var root_x: *anyopaque = undefined;
var root_y: *anyopaque = undefined;
var old_bytes: []u8 = &.{};
var old_len: usize = 0;
var external_bytes: []u8 = &.{};
var callback: *const fn (*W) anyerror!void = empty;
fn empty(_: *W) anyerror!void {}
fn observe(message: []const u8, address: ?usize) noreturn {
    if (path) |name| {
        if (std.fs.cwd().createFile(name, .{})) |file| {
            defer file.close();
            var buffer: [8192]u8 = undefined;
            var writer = file.writer(&buffer);
            callback(&writer.interface) catch {};
            writer.interface.flush() catch {};
        } else |_| {}
    }
    std.debug.defaultPanic(message, address);
}
fn view(out: *W, bytes: []const u8, len: usize, bases: [3][]const u8, stride: usize) !void {
    var origin: usize = 0;
    var offset: usize = 0;
    if (bytes.len > 0) {
        const ptr = @intFromPtr(bytes.ptr);
        for (bases, 0..) |base, index| {
            const start = @intFromPtr(base.ptr);
            if (ptr >= start and bytes.len <= base.len and ptr - start <= base.len - bytes.len) {
                origin = index + 1;
                offset = (ptr - start) / stride;
                break;
            }
        }
        if (origin == 0) @panic("OBSERVER ERROR: unknown view");
    }
    try out.print("{d}:{d}:{d}:{x}", .{ len, origin, offset, bytes });
}
fn state(comptime T: type, comptime capacity: usize, out: *W) !void {
    const x: *fixed(T, capacity) = @ptrCast(@alignCast(root_x));
    const y: *fixed(T, capacity) = @ptrCast(@alignCast(root_y));
    const xb = std.mem.sliceAsBytes(&x.storage);
    const yb = std.mem.sliceAsBytes(&y.storage);
    const bases = [_][]const u8{ xb, yb, external_bytes };
    try view(out, std.mem.sliceAsBytes(x.data), x.data.len, bases, @sizeOf(T));
    try out.writeByte('|');
    try view(out, std.mem.sliceAsBytes(y.data), y.data.len, bases, @sizeOf(T));
    try out.writeByte('|');
    try view(out, old_bytes, old_len, bases, @sizeOf(T));
    try out.print("|{x}|{x}|{x}", .{ xb, yb, external_bytes });
}
fn run(comptime T: type, comptime capacity: usize, f: []const usize, out: *W) !void {
    var x = fixed(T, capacity){};
    for (std.mem.sliceAsBytes(&x.storage), 0..) |*byte, i| byte.* = @truncate(i * 37 + f[4]);
    var external: [4]T = undefined;
    for (std.mem.sliceAsBytes(&external), 0..) |*byte, i| byte.* = @truncate(i * 19 + f[4] + 7);
    switch (f[1]) {
        0 => {},
        1 => x.resize(f[2]),
        2 => x.data = external[0..f[2]],
        3 => x.data = external[1 .. 1 + f[2]],
        else => unreachable,
    }
    const old = x.data;
    var y = x;
    root_x = &x;
    root_y = &y;
    old_bytes = std.mem.sliceAsBytes(old);
    old_len = old.len;
    external_bytes = std.mem.sliceAsBytes(&external);
    const adapter = struct {
        fn output(writer: *W) anyerror!void {
            try state(T, capacity, writer);
        }
    };
    callback = adapter.output;
    switch (f[0]) {
        0 => x.resize(f[3]),
        1 => {
            y.resize(f[3]);
            const bytes = std.mem.sliceAsBytes(y.data);
            if (bytes.len > 0) bytes[bytes.len - 1] ^= 85;
        },
        2 => {
            x.resize(f[3]);
            if (old_bytes.len > 0) old_bytes[old_bytes.len - 1] ^= 85;
        },
        3 => {
            const bytes = std.mem.sliceAsBytes(&y.storage);
            if (bytes.len > 0) bytes[0] ^= 85;
        },
        4 => {
            y.data = external[1..3];
            std.mem.sliceAsBytes(y.data)[0] ^= 85;
        },
        5 => {
            y.data = old[0..@min(old.len, 1)];
            x.resize(f[3]);
        },
        6 => {
            const bytes = std.mem.sliceAsBytes(&x.storage);
            if (bytes.len > 0) bytes[0] ^= 85;
            y.resize(f[3]);
        },
        else => unreachable,
    }
    if (path != null) {
        std.debug.print("UNEXPECTED return\n", .{});
        return;
    }
    try callback(out);
    try out.writeByte('\n');
}
fn lineCase(line: []const u8, out: *W) !void {
    var parts = std.mem.splitScalar(u8, line, '|');
    var f: [7]usize = undefined;
    for (&f) |*field| field.* = try std.fmt.parseInt(usize, parts.next().?, 10);
    switch (f[0]) {
        0 => switch (f[1]) {
            0 => try run(u8, 0, f[2..], out),
            1 => try run(u8, 1, f[2..], out),
            2 => try run(u8, 7, f[2..], out),
            3 => try run(u8, 8, f[2..], out),
            4 => try run(u8, 256, f[2..], out),
            5 => try run(u8, 513, f[2..], out),
            6 => try run(u8, 8, f[2..], out),
            7 => try run(u8, 256, f[2..], out),
            else => unreachable,
        },
        1 => switch (f[1]) {
            0 => try run(u16, 0, f[2..], out),
            1 => try run(u16, 1, f[2..], out),
            2 => try run(u16, 7, f[2..], out),
            3 => try run(u16, 8, f[2..], out),
            4 => try run(u16, 256, f[2..], out),
            5 => try run(u16, 513, f[2..], out),
            6 => try run(u16, 8, f[2..], out),
            7 => try run(u16, 256, f[2..], out),
            else => unreachable,
        },
        2 => switch (f[1]) {
            0 => try run(color.Rgba32, 0, f[2..], out),
            1 => try run(color.Rgba32, 1, f[2..], out),
            2 => try run(color.Rgba32, 7, f[2..], out),
            3 => try run(color.Rgba32, 8, f[2..], out),
            4 => try run(color.Rgba32, 256, f[2..], out),
            5 => try run(color.Rgba32, 513, f[2..], out),
            6 => try run(color.Rgba32, 8, f[2..], out),
            7 => try run(color.Rgba32, 256, f[2..], out),
            else => unreachable,
        },
        else => unreachable,
    }
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args);
    var buffer: [8192]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&buffer);
    const out = &writer.interface;
    if (std.mem.eql(u8, args[1], "--trap")) {
        path = args[2];
        try lineCase(args[3], out);
        return;
    }
    const text = try std.fs.cwd().readFileAlloc(a, args[2], 1073741824);
    defer a.free(text);
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        if (line.len > 0) try lineCase(line, out);
    }
    try out.flush();
}
