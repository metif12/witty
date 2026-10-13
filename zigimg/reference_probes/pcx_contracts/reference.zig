const std = @import("std");
const p = @import("src/formats/pcx.zig");
const color = @import("src/color.zig");
const io = @import("src/io.zig");
const Format = @import("src/pixel_format.zig").PixelFormat;
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_codec: ?*const p.PCX = null;
var observed_reader: ?*io.ReadStream = null;
var observed_writer: ?*io.WriteStream = null;
var observed_output: []const u8 = &.{};
fn observe(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var buf: [4096]u8 = undefined;
            var w = file.writer(&buf);
            const out = &w.interface;
            if (observed_reader) |reader| out.print("{d}|", .{reader.getPos()}) catch {};
            if (observed_writer) |writer| out.print("{d}|{x}|", .{ writer.getPos(), observed_output }) catch {};
            if (observed_codec) |codec| out.print("{x}", .{std.mem.asBytes(&codec.header)}) catch {};
            out.flush() catch {};
        } else |_| {}
    }
    std.debug.defaultPanic(message, address);
}
fn pixels(format: Format, count: usize, seed: usize) !color.PixelStorage {
    var result = try color.PixelStorage.init(a, format, count);
    const raw = result.asBytes();
    for (raw, 0..) |*byte, i| byte.* = @truncate(if (seed == 0) @as(usize, 1) else if (seed == 1) i * 17 else if (seed == 2) @as(usize, 192) else i / 16 + 1);
    if (result.getPalette()) |pal| {
        const length = @min(pal.len, 4);
        result.resizePalette(length);
        for (pal[0..length], 0..) |*entry, i| entry.* = color.Rgba32.from.rgba(@truncate(i * 31), @truncate(i * 71), @truncate(i * 113), @truncate(i * 47));
        if (format == .indexed1) for (raw) |*byte| {
            byte.* &= 1;
        };
        if (format == .indexed4) for (raw) |*byte| {
            byte.* &= 15;
        };
    }
    return result;
}
fn writeCase(out: *W, format: Format, width: usize, height: usize, seed: usize, capacity: usize, direct: bool) !void {
    const data = try pixels(format, width * height, seed);
    defer data.deinit(a);
    var buf: [1024]u8 = @splat(165);
    var writer = io.WriteStream.initMemory(buf[0..capacity]);
    var status: []const u8 = "ok";
    const codec = p.PCX{ .header = .{ .id = 7, .version = 6, .compression = .none, .bpp = 99, .xmin = 10, .xmax = @intCast(width + 9), .ymin = 20, .ymax = @intCast(height + 19), .planes = 0, ._reserved0 = 37, .palette_information = @enumFromInt(65535) } };
    if (direct) codec.write(&writer, data) catch |err| {
        status = @errorName(err);
    } else p.PCX.writeImage(a, &writer, .{ .width = width, .height = height, .pixels = data }, .{ .pcx = .{} }) catch |err| {
        status = @errorName(err);
    };
    try out.print("W|{}|{d}|{d}|{d}|{d}|{d}|{s}|{d}|{x}\n", .{ direct, @intFromEnum(format), width, height, seed, capacity, status, writer.getPos(), buf[0..capacity] });
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    if (args.len > 1) {
        if (!std.mem.eql(u8, args[2], "-")) observed_path = args[2];
        if (std.mem.eql(u8, args[1], "--dimension")) {
            const codec = p.PCX{ .header = .{ .xmin = try std.fmt.parseInt(u16, args[4], 10), .xmax = try std.fmt.parseInt(u16, args[5], 10), .ymin = try std.fmt.parseInt(u16, args[4], 10), .ymax = try std.fmt.parseInt(u16, args[5], 10) } };
            observed_codec = &codec;
            _ = if (std.mem.eql(u8, args[3], "width")) codec.width() else codec.height();
        } else if (std.mem.eql(u8, args[1], "--read")) {
            const bytes = try std.fs.cwd().readFileAlloc(a, args[3], 1048576);
            var reader = io.ReadStream.initMemory(bytes);
            var codec = p.PCX{ .header = .{ .version = 4, .bpp = 4, .xmax = 7, .ymax = 8, ._reserved0 = 165, .planes = 1 } };
            observed_reader = &reader;
            observed_codec = &codec;
            const result = codec.read(a, &reader) catch |err| {
                if (observed_path != null) {
                    std.debug.print("UNEXPECTED: recoverable {s}\n", .{@errorName(err)});
                    return;
                }
                var buf: [4096]u8 = undefined;
                var w = std.fs.File.stdout().writer(&buf);
                try w.interface.print("{s}|{d}|{x}\n", .{ @errorName(err), reader.getPos(), std.mem.asBytes(&codec.header) });
                try w.interface.flush();
                return;
            };
            if (observed_path == null) {
                defer result.deinit(a);
                var buf: [4096]u8 = undefined;
                var w = std.fs.File.stdout().writer(&buf);
                const out = &w.interface;
                try out.print("ok|{d}|{x}|{x}|", .{ reader.getPos(), std.mem.asBytes(&codec.header), result.asBytes() });
                if (result.getPalette()) |pal| try out.print("{x}", .{std.mem.sliceAsBytes(pal)}) else try out.writeByte('-');
                try out.writeByte('\n');
                try out.flush();
                return;
            }
        } else {
            const capacity = try std.fmt.parseInt(usize, args[3], 10);
            var output: [1024]u8 = @splat(165);
            var writer = io.WriteStream.initMemory(output[0..capacity]);
            observed_writer = &writer;
            observed_output = output[0..capacity];
            const width = try std.fmt.parseInt(usize, args[4], 10);
            const height = try std.fmt.parseInt(usize, args[5], 10);
            const format: Format = @enumFromInt(try std.fmt.parseInt(u32, args[6], 10));
            const data = try pixels(format, 4, 1);
            var status: []const u8 = "ok";
            if (std.mem.eql(u8, args[1], "--image")) p.PCX.writeImage(a, &writer, .{ .width = width, .height = height, .pixels = data }, .{ .pcx = .{} }) catch |err| {
                status = @errorName(err);
            } else {
                const codec = p.PCX{ .header = .{ .xmin = try std.fmt.parseInt(u16, args[7], 10), .xmax = try std.fmt.parseInt(u16, args[8], 10), .ymin = try std.fmt.parseInt(u16, args[9], 10), .ymax = try std.fmt.parseInt(u16, args[10], 10) } };
                observed_codec = &codec;
                codec.write(&writer, data) catch |err| {
                    status = @errorName(err);
                };
            }
            if (observed_path == null) {
                var buf: [4096]u8 = undefined;
                var w = std.fs.File.stdout().writer(&buf);
                try w.interface.print("{s}|{d}|{x}\n", .{ status, writer.getPos(), output[0..capacity] });
                try w.interface.flush();
                return;
            }
        }
        std.debug.print("UNEXPECTED: operation returned\n", .{});
        return;
    }
    var buf: [8192]u8 = undefined;
    var w = std.fs.File.stdout().writer(&buf);
    const out = &w.interface;
    for (0..65535) |high| {
        const codec = p.PCX{ .header = .{ .xmax = @intCast(high), .ymax = @intCast(high) } };
        try out.print("D|0|{d}|{d}|{d}\n", .{ high, codec.width(), codec.height() });
    }
    for (1..65536) |low| {
        const codec = p.PCX{ .header = .{ .xmin = @intCast(low), .xmax = 65535, .ymin = @intCast(low), .ymax = 65535 } };
        try out.print("D|{d}|65535|{d}|{d}\n", .{ low, codec.width(), codec.height() });
    }
    const original = p.PCX{};
    var copied = original;
    copied.header.builtin_palette[15] = .{ .r = 1, .g = 2, .b = 3 };
    copied.header.padding[53] = 99;
    try out.print("H|{d}|{x}|{x}\n", .{ @sizeOf(p.PCXHeader), std.mem.asBytes(&original.header), std.mem.asBytes(&copied.header) });
    for ([_]bool{ false, true }) |direct| {
        for ([_]Format{ .indexed1, .indexed4, .indexed8, .rgb24, .grayscale8 }) |format| {
            for ([_]usize{ 1, 2, 3, 8, 17, 32, 65 }) |width| {
                for ([_]usize{ 1, 2 }) |height| {
                    for (0..4) |seed| {
                        for ([_]usize{ 0, 1, 127, 128, 129, 160, 256, 1024 }) |capacity| try writeCase(out, format, width, height, seed, capacity, direct);
                    }
                }
            }
        }
    }
    try out.flush();
}
