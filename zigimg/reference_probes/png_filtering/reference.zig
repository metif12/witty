const std = @import("std");
const filtering = @import("src/formats/png/filtering.zig");
const png = @import("src/formats/png/types.zig");
const color = @import("src/color.zig");
const PixelFormat = @import("src/pixel_format.zig").PixelFormat;
const a = std.heap.page_allocator;
const formats = [_]PixelFormat{ .indexed1, .indexed2, .indexed4, .indexed8, .grayscale1, .grayscale2, .grayscale4, .grayscale8, .grayscale16, .grayscale8Alpha, .grayscale16Alpha, .rgb24, .rgb48, .rgba32, .rgba64, .indexed16, .invalid, .rgb332, .rgb565 };

fn pixelsFor(format: PixelFormat, count: usize, seed: usize) !color.PixelStorage {
    if (format == .invalid) return .invalid;
    const pixels = try color.PixelStorage.init(a, format, count);
    const bytes = pixels.asBytes();
    const depth = format.bitsPerChannel();
    for (bytes, 0..) |*byte, i| {
        byte.* = @truncate(i * 37 + seed * 19 + i / 7);
        if (depth < 8) byte.* &= (@as(u8, 1) << @intCast(depth)) - 1;
    }
    return pixels;
}

fn trapped(name: []const u8) void {
    var header = png.HeaderData{ .width = 1, .height = 1, .bit_depth = 8, .color_type = .grayscale, .compression_method = .deflate, .filter_method = .adaptive, .interlace_method = .none };
    var format: PixelFormat = .grayscale8;
    var count: usize = 1;
    var choice: filtering.FilterChoice = .{ .specified = .none };
    if (std.mem.eql(u8, name, "short_pixels")) header.width = 2 else if (std.mem.eql(u8, name, "channels8")) header.color_type = .rgba_color else if (std.mem.eql(u8, name, "channels16")) {
        format = .grayscale16;
        header.bit_depth = 16;
        header.color_type = .rgba_color;
    } else if (std.mem.eql(u8, name, "odd16")) format = .grayscale16 else if (std.mem.eql(u8, name, "try_all")) choice = .try_all else if (std.mem.eql(u8, name, "rgb332")) format = .rgb332 else if (std.mem.eql(u8, name, "rgb565")) format = .rgb565 else if (std.mem.eql(u8, name, "pixel_bits")) {
        header.bit_depth = 255;
        header.color_type = .rgba_color;
        header.height = 0;
        count = 0;
    } else if (std.mem.eql(u8, name, "line_product")) {
        header.width = 0x20000000;
        header.bit_depth = 16;
        header.height = 0;
        count = 0;
    } else if (std.mem.eql(u8, name, "line_round")) {
        header.width = 0x1fffffff;
        header.bit_depth = 8;
        // Product 0xfffffff8 is still below max-7, so use one-bit pixels
        // with a width that makes the rounding addition overflow.
        header.bit_depth = 1;
        header.width = 0xfffffffc;
        header.height = 0;
        count = 0;
    } else @panic("fixture trap");
    var pixels = color.PixelStorage.init(a, format, count) catch |err| {
        std.debug.print("UNEXPECTED allocation {s}\n", .{@errorName(err)});
        return;
    };
    defer pixels.deinit(a);
    @memset(pixels.asBytes(), 0);
    var bytes: [32]u8 = @splat(0xa5);
    var writer = std.Io.Writer.fixed(&bytes);
    filtering.filter(a, &writer, pixels, choice, header) catch |err| {
        std.debug.print("UNEXPECTED returned {s}\n", .{@errorName(err)});
        return;
    };
    std.debug.print("UNEXPECTED returned normally\n", .{});
}

pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    if (std.mem.startsWith(u8, args[1], "trap:")) {
        trapped(args[1][5..]);
        return;
    }
    const contents = try std.fs.cwd().readFileAlloc(a, args[1], 64 * 1024 * 1024);
    defer a.free(contents);
    var buffer: [4096]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&buffer);
    var lines = std.mem.tokenizeScalar(u8, contents, '\n');
    while (lines.next()) |line| {
        var split = std.mem.splitScalar(u8, line, '|');
        var p: [9]usize = undefined;
        for (&p) |*n| n.* = try std.fmt.parseInt(usize, split.next().?, 10);
        const format = formats[p[0]];
        var pixels = try pixelsFor(format, p[3], p[6]);
        defer pixels.deinit(a);
        const header = png.HeaderData{ .width = @intCast(p[1]), .height = @intCast(p[2]), .bit_depth = @intCast(p[4]), .color_type = @enumFromInt(p[5]), .compression_method = .deflate, .filter_method = .adaptive, .interlace_method = .none };
        const choice: filtering.FilterChoice = if (p[7] == 6) .try_all else if (p[7] == 5) .heuristic else .{ .specified = @enumFromInt(p[7]) };
        const bytes = try a.alloc(u8, p[8]);
        defer a.free(bytes);
        @memset(bytes, 0xa5);
        var writer = std.Io.Writer.fixed(bytes);
        var failed = false;
        filtering.filter(a, &writer, pixels, choice, header) catch |err| {
            if (err != error.InvalidData) return err;
            failed = true;
        };
        try stdout.interface.print("{d}|{d}|", .{ @intFromBool(failed), writer.end });
        for (bytes) |byte| try stdout.interface.print("{x:0>2}", .{byte});
        try stdout.interface.writeByte('\n');
    }
    try stdout.interface.flush();
}
