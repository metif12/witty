const std = @import("std");
const p = @import("src/formats/pcx.zig");
const Image = @import("src/ImageUnmanaged.zig");
const color = @import("src/color.zig");
const Format = @import("src/pixel_format.zig").PixelFormat;
const io = @import("src/io.zig");
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_codec: ?*const p.PCX = null;
var observed_writer: ?*io.WriteStream = null;
var observed_image: ?*const Image = null;
var observed_buffer: []const u8 = &.{};
var observed_disk: ?[]const u8 = null;

fn snapshot(out: *W) !void {
    const writer = observed_writer.?;
    try out.print("{d}:{d}|{x}|", .{ writer.getPos(), writer.writer().buffered().len, observed_buffer });
    if (observed_codec) |codec| try out.print("{x}", .{std.mem.asBytes(&codec.header)}) else try out.writeByte('-');
    const image = observed_image.?;
    try out.print("|{d}:{d}:{d}:{d}:{x}|", .{ image.width, image.height, @intFromEnum(std.meta.activeTag(image.pixels)), image.pixels.len(), image.pixels.asBytes() });
    if (image.pixels.getPalette()) |pal| try out.print("{x}", .{std.mem.sliceAsBytes(pal)}) else try out.writeByte('-');
    try out.writeByte('|');
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
fn number(comptime T: type, value: []const u8) !T {
    return std.fmt.parseInt(T, value, 10);
}
fn record(line: []const u8, path: []const u8, out: *W) !void {
    var f: [11][]const u8 = undefined;
    var it = std.mem.splitScalar(u8, line, '|');
    for (&f) |*field| field.* = it.next().?;
    const cap = try number(i32, f[0]);
    const op = try number(u8, f[1]);
    const width = try number(usize, f[2]);
    const height = try number(usize, f[3]);
    const format: Format = @enumFromInt(try number(u32, f[4]));
    var pixels = try color.PixelStorage.init(a, format, try number(usize, f[5]));
    defer pixels.deinit(a);
    const seed = try number(u8, f[6]);
    for (pixels.asBytes(), 0..) |*byte, i| {
        byte.* = @truncate(switch (seed) {
            0 => @as(usize, 1),
            1 => i * 17,
            2 => @as(usize, 192),
            3 => i / 16 + 1,
            4 => @as(usize, 0),
            else => i / 63 + 191,
        });
        if (format == .indexed1) byte.* &= 1;
        if (format == .indexed4) byte.* &= 15;
    }
    if (pixels.getPalette()) |pal| {
        const length = @min(try number(usize, f[7]), pal.len);
        pixels.resizePalette(length);
        for (pal[0..length], 0..) |*entry, i| entry.* = .{ .r = @truncate(i * 31), .g = @truncate(i * 71), .b = @truncate(i * 113), .a = @truncate(i * 47) };
    }
    const image = Image{ .width = width, .height = height, .pixels = pixels };
    observed_image = &image;
    var codec = p.PCX{ .header = .{ .id = 7, .version = 6, .compression = .none, .bpp = 99, .xmin = 10, .xmax = 10, .ymin = 20, .ymax = 20, .planes = 0, ._reserved0 = 37, .palette_information = @enumFromInt(65535) } };
    if (op == 0) {
        codec.header.xmax = @intCast(width + 9);
        codec.header.ymax = @intCast(height + 19);
        switch (try number(u8, f[10])) {
            1 => {
                codec.header.xmin = 2;
                codec.header.xmax = 1;
            },
            2 => {
                codec.header.xmin = 0;
                codec.header.xmax = 65535;
            },
            3 => {
                codec.header.ymin = 2;
                codec.header.ymax = 1;
            },
            4 => {
                codec.header.ymin = 0;
                codec.header.ymax = 65535;
            },
            else => {},
        }
    }
    observed_codec = if (op == 0) &codec else null;
    const buffer = try a.alloc(u8, if (cap < 0) @intCast(-cap - 1) else @intCast(cap));
    defer a.free(buffer);
    @memset(buffer, 165);
    observed_buffer = buffer;
    observed_disk = null;
    var file: ?std.fs.File = null;
    defer if (file) |value| value.close();
    var writer = io.WriteStream.initMemory(buffer);
    if (cap >= 0) {
        const initial = [_]u8{165} ** 1024;
        try std.fs.cwd().writeFile(.{ .sub_path = path, .data = &initial });
        file = try std.fs.cwd().openFile(path, .{ .mode = .read_write });
        try file.?.seekTo(1024);
        writer = io.WriteStream.initFile(file.?, buffer);
        observed_disk = path;
    }
    observed_writer = &writer;
    const start = try number(usize, f[8]);
    if (start > 0) try writer.seekTo(start);
    const iface = p.PCX.formatInterface();
    for (0..try number(usize, f[9])) |_| {
        var status: []const u8 = "ok";
        if (op == 0) codec.write(&writer, pixels) catch |err| {
            status = @errorName(err);
        } else if (op == 1) p.PCX.writeImage(a, &writer, image, .{ .pcx = .{} }) catch |err| {
            status = @errorName(err);
        } else iface.writeImage(a, &writer, image, .{ .qoi = .{ .colorspace = .linear } }) catch |err| {
            status = @errorName(err);
        };
        try out.print("{s}|", .{status});
        try snapshot(out);
        try out.writeByte('~');
    }
    var status: []const u8 = "ok";
    writer.writer().flush() catch |err| {
        status = @errorName(err);
    };
    try out.print("flush:{s}|", .{status});
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
