const std = @import("std");
const F = @import("src/FormatInterface.zig");
const I = @import("src/ImageUnmanaged.zig");
const io = @import("src/io.zig");
const codecs = @import("src/formats.zig");
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var path: ?[]const u8 = null;
var input: []const u8 = &.{};
var output: []const u8 = &.{};
var reader: ?*const io.ReadStream = null;
var writer: ?*const io.WriteStream = null;
var image: ?*const I = null;
var trace: u64 = 0;
fn hex(out: *W, bytes: []const u8) !void {
    for (bytes) |byte| try out.print("{x:0>2}", .{byte});
}
fn state(out: *W) !void {
    try out.print("{d}:{d}:{d}|{d}:{d}:{s}|", .{ trace, if (reader) |r| r.getPos() else 0, writer.?.getPos(), image.?.width, image.?.height, @tagName(image.?.pixelFormat()) });
    try hex(out, image.?.rawBytes());
    try out.writeByte('|');
    try hex(out, input);
    try out.writeByte('|');
    try hex(out, output);
}
fn observe(message: []const u8, address: ?usize) noreturn {
    if (path) |name| {
        if (std.fs.cwd().createFile(name, .{})) |file| {
            defer file.close();
            var buffer: [4096]u8 = undefined;
            var out = file.writer(&buffer);
            state(&out.interface) catch {};
            out.interface.flush() catch {};
        } else |_| {}
    }
    std.debug.defaultPanic(message, address);
}
fn d0(r: *io.ReadStream) I.ReadError!bool {
    trace = trace * 10 + 1;
    _ = try r.reader().takeByte();
    return false;
}
fn d1(r: *io.ReadStream) I.ReadError!bool {
    trace = trace * 10 + 2;
    _ = try r.reader().take(2);
    return true;
}
fn d2(r: *io.ReadStream) I.ReadError!bool {
    trace = trace * 10 + 3;
    _ = try r.reader().takeByte();
    return error.InvalidData;
}
fn r0(allocator: std.mem.Allocator, r: *io.ReadStream) I.ReadError!I {
    _ = allocator;
    trace = trace * 10 + 1;
    return .{ .width = 1, .height = try r.reader().takeByte() };
}
fn r1(allocator: std.mem.Allocator, r: *io.ReadStream) I.ReadError!I {
    _ = allocator;
    trace = trace * 10 + 2;
    const bytes = try r.reader().take(2);
    return .{ .width = 2, .height = bytes[1] };
}
fn r2(allocator: std.mem.Allocator, r: *io.ReadStream) I.ReadError!I {
    _ = allocator;
    trace = trace * 10 + 3;
    _ = try r.reader().takeByte();
    return error.InvalidData;
}
fn w0(allocator: std.mem.Allocator, w: *io.WriteStream, img: I, opt: I.EncoderOptions) I.WriteError!void {
    _ = allocator;
    _ = img;
    trace = trace * 10 + 1;
    try w.writer().writeByte(@intFromEnum(opt));
}
fn w1(allocator: std.mem.Allocator, w: *io.WriteStream, img: I, opt: I.EncoderOptions) I.WriteError!void {
    _ = allocator;
    trace = trace * 10 + 2;
    try w.writer().writeAll(&.{ @intCast(img.width), @intCast(img.height), @intFromEnum(opt) });
}
fn w2(allocator: std.mem.Allocator, w: *io.WriteStream, img: I, opt: I.EncoderOptions) I.WriteError!void {
    _ = allocator;
    _ = img;
    _ = opt;
    trace = trace * 10 + 3;
    try w.writer().writeByte(238);
    return error.InvalidData;
}
const detects = [_]*const F.FormatDetectFn{ d0, d1, d2 };
const reads = [_]*const F.ReadImageFn{ r0, r1, r2 };
const writes = [_]*const F.WriteImageFn{ w0, w1, w2 };
fn options(index: usize) I.EncoderOptions {
    const tag: I.Format = @enumFromInt(index);
    return switch (tag) {
        .bmp => .{ .bmp = .{} },
        .farbfeld => .{ .farbfeld = {} },
        .gif => .{ .gif = {} },
        .iff => .{ .iff = {} },
        .jpeg => .{ .jpeg = {} },
        .pam => .{ .pam = .{} },
        .pbm => .{ .pbm = .{} },
        .pcx => .{ .pcx = .{} },
        .pgm => .{ .pgm = .{} },
        .png => .{ .png = .{} },
        .ppm => .{ .ppm = .{} },
        .qoi => .{ .qoi = .{} },
        .ras => .{ .ras = {} },
        .sgi => .{ .sgi = {} },
        .tga => .{ .tga = .{} },
        .tiff => .{ .tiff = {} },
        .xbm => .{ .xbm = {} },
    };
}
fn number(s: []const u8) !usize {
    return std.fmt.parseInt(usize, s, 10);
}
fn lineCase(line: []const u8, out: *W) !void {
    var parts = std.mem.splitScalar(u8, line, '|');
    var f: [9]usize = undefined;
    for (&f) |*field| field.* = try number(parts.next().?);
    var original = F{ .formatDetect = detects[f[1]], .readImage = reads[f[2]], .writeImage = writes[f[3]] };
    var copied = original;
    const changed = if (f[0] < 2) &original else &copied;
    if (f[4] & 1 != 0) changed.formatDetect = detects[(f[1] + 1) % 3];
    if (f[4] & 2 != 0) changed.readImage = reads[(f[2] + 1) % 3];
    if (f[4] & 4 != 0) changed.writeImage = writes[(f[3] + 1) % 3];
    const selected = if (f[0] == 0 or f[0] == 2) original else copied;
    const bytes = try a.alloc(u8, f[5]);
    defer a.free(bytes);
    for (bytes, 0..) |*byte, i| byte.* = @intCast(i * 37 + 11);
    const dest = try a.alloc(u8, f[6]);
    defer a.free(dest);
    @memset(dest, 165);
    var rd = io.ReadStream.initMemory(bytes);
    var wr = io.WriteStream.initMemory(dest);
    if (f[7] == 1) {
        if (bytes.len > 0) try rd.seekTo(bytes.len - 1);
        if (dest.len > 0) try wr.seekTo(dest.len - 1);
    }
    var img = I{ .width = 2, .height = 3 };
    trace = 0;
    input = bytes;
    output = dest;
    reader = &rd;
    writer = &wr;
    image = &img;
    if (selected.formatDetect(&rd)) |found| {
        try out.print("d:{d}", .{@intFromBool(found)});
    } else |err| {
        try out.print("d:{s}", .{@errorName(err)});
    }
    if (selected.readImage(a, &rd)) |loaded| {
        try out.print("|r:{d}:{d}:{s}", .{ loaded.width, loaded.height, @tagName(loaded.pixelFormat()) });
    } else |err| {
        try out.print("|r:{s}", .{@errorName(err)});
    }
    if (selected.writeImage(a, &wr, img, options(f[8]))) |_| {
        try out.writeAll("|w:ok");
    } else |err| {
        try out.print("|w:{s}", .{@errorName(err)});
    }
    try out.writeByte('|');
    try state(out);
    try out.writeByte('\n');
}
fn trapCase(line: []const u8) !void {
    var parts = std.mem.splitScalar(u8, line, '|');
    const codec = parts.next().?;
    var f: [4]usize = undefined;
    for (&f) |*field| field.* = try number(parts.next().?);
    const pixel_formats = [_]@import("src/pixel_format.zig").PixelFormat{ .invalid, .rgb24, .grayscale8, .rgb24 };
    var img = try I.create(a, if (f[1] == 0) 4 else 1, if (f[1] == 0) 2 else if (f[1] == 3) 0 else 1, pixel_formats[f[1]]);
    defer img.deinit(a);
    for (img.pixels.asBytes(), 0..) |*byte, index| byte.* = @intCast(index * 37 + 19);
    const dest = try a.alloc(u8, f[2]);
    defer a.free(dest);
    @memset(dest, 165);
    var wr = io.WriteStream.initMemory(dest);
    if (f[3] == 1 and dest.len > 0) try wr.seekTo(dest.len - 1);
    trace = 0;
    input = &.{};
    output = dest;
    reader = null;
    writer = &wr;
    image = &img;
    const interface = if (std.mem.eql(u8, codec, "png")) codecs.png.PNG.formatInterface() else codecs.tga.TGA.formatInterface();
    interface.writeImage(a, &wr, img, options(f[0])) catch |err| {
        std.debug.print("UNEXPECTED {s}\n", .{@errorName(err)});
        return;
    };
    std.debug.print("UNEXPECTED return\n", .{});
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args);
    if (std.mem.eql(u8, args[1], "--trap")) {
        path = args[2];
        try trapCase(args[3]);
        return;
    }
    const text = try std.fs.cwd().readFileAlloc(a, args[2], 1073741824);
    defer a.free(text);
    var buffer: [8192]u8 = undefined;
    var out = std.fs.File.stdout().writer(&buffer);
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        if (line.len > 0) try lineCase(line, &out.interface);
    }
    try out.interface.flush();
}
