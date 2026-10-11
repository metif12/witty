const std = @import("std");
const io = @import("src/io.zig");
const F = @import("src/formats/jpeg/Frame.zig");
const Header = @import("src/formats/jpeg/FrameHeader.zig");
const Component = @typeInfo(@FieldType(Header, "components")).pointer.child;
const Q = @import("src/formats/jpeg/quantization.zig").Table;
const H = @import("src/formats/jpeg/huffman.zig").Table;
const JPEG = @import("src/formats/jpeg.zig").JPEG;
const color = @import("src/color.zig");
const W = std.Io.Writer;
const a = std.heap.page_allocator;
const Blocks = [3][64]i32;
pub const panic = std.debug.FullPanic(observe);
var observed_frame: ?*F = null;
var observed_stream: ?*io.ReadStream = null;
var observed_pixels: ?*color.PixelStorage = null;
var observed_path: ?[]const u8 = null;

fn hash(bytes: []const u8) u64 {
    var h: u64 = 14695981039346656037;
    for (bytes) |b| h = (h ^ b) *% 1099511628211;
    return h;
}
fn blocksHash(blocks: []const Blocks) u64 {
    var h: u64 = 14695981039346656037;
    for (blocks) |b| {
        for (b) |c| {
            for (c) |v| {
                const n: u32 = @bitCast(v);
                for ([_]u5{ 0, 8, 16, 24 }) |shift| h = (h ^ @as(u8, @truncate(n >> shift))) *% 1099511628211;
            }
        }
    }
    return h;
}
fn state(out: *W, f: *const F) !void {
    try out.print("{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}", .{ f.frame_header.width, f.frame_header.height, f.frame_header.components.len, @intFromEnum(f.frame_type), f.block_width, f.block_height, f.block_width_actual, f.block_height_actual, f.horizontal_sampling_factor_max, f.vertical_sampling_factor_max, f.block_storage.len });
}
fn observe(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var buf: [512]u8 = undefined;
            var writer = file.writer(&buf);
            const out = &writer.interface;
            if (observed_stream) |stream| out.print("{d}", .{stream.getPos()}) catch {};
            if (observed_frame) |f| {
                out.writeByte('|') catch {};
                state(out, f) catch {};
                out.print("|{d}", .{blocksHash(f.block_storage)}) catch {};
            }
            if (observed_pixels) |p| out.print("|{d}", .{hash(p.asBytes())}) catch {};
            out.flush() catch {};
        } else |_| {}
    }
    std.debug.defaultPanic(message, address);
}
fn number(p: []const []const u8, i: usize) !usize {
    return std.fmt.parseInt(usize, p[i], 10);
}
fn signed(p: []const []const u8, i: usize) !i32 {
    return std.fmt.parseInt(i32, p[i], 10);
}
fn initializedBlocks(alloc: std.mem.Allocator, count: usize, seed: i32, rgb: bool) ![]Blocks {
    const blocks = try alloc.alloc(Blocks, count);
    for (blocks, 0..) |*b, bi| {
        for (b, 0..) |*c, ci| {
            for (c, 0..) |*v, i| {
                const n = seed * 17 + @as(i32, @intCast(bi)) * 13 + @as(i32, @intCast(ci)) * 29 + @as(i32, @intCast(i)) * 19;
                v.* = if (rgb) @mod(n, 256) else @mod(n, 513) - 256;
            }
        }
    }
    return blocks;
}
fn record(out: *W, p: []const []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(a);
    defer arena.deinit();
    const alloc = arena.allocator();
    var q: [4]?Q = @splat(null);
    var dc: [4]?H = @splat(null);
    var ac: [4]?H = @splat(null);
    const bytes = try alloc.alloc(u8, p[1].len / 2);
    _ = try std.fmt.hexToBytes(bytes, p[1]);
    var stream = io.ReadStream.initMemory(bytes);
    if (observed_path != null) observed_stream = &stream;
    if (p[0][0] == 'J') {
        var jpeg = JPEG.init(alloc);
        var pixels: ?color.PixelStorage = null;
        var returned = try jpeg.read(&stream, &pixels);
        const copied = returned;
        returned.frame_header.width += 1;
        returned.block_width += 1;
        if (returned.block_storage.len > 0) returned.block_storage[0][0][0] = 42;
        const stored = jpeg.frame.?;
        jpeg.quantization_tables[0] = null;
        try state(out, &returned);
        try out.writeByte('|');
        try state(out, &copied);
        try out.writeByte('|');
        try state(out, &stored);
        try out.print("|{d}|{d}|{d}", .{ if (stored.block_storage.len > 0) stored.block_storage[0][0][0] else @as(i32, 0), @intFromBool(returned.quantization_tables[0] != null), stream.getPos() });
        return;
    }
    if (p[0][0] == 'F') {
        var f = F.read(alloc, @enumFromInt(try number(p, 2)), &q, &dc, &ac, stream.reader()) catch |e| {
            try out.print("E{s}|{d}", .{ @errorName(e), stream.getPos() });
            return;
        };
        try state(out, &f);
        try out.print("|{d}", .{stream.getPos()});
        f.deinit();
        return;
    }
    const components = try alloc.alloc(Component, try number(p, 2));
    for (components, 0..) |*c, i| c.* = .{ .id = @intCast(i + 1), .horizontal_sampling_factor = @intCast(@min(15, try number(p, 6))), .vertical_sampling_factor = @intCast(@min(15, try number(p, 7))), .quantization_table_id = @intCast(i) };
    var f: F = .{ .allocator = alloc, .frame_header = .{ .allocator = alloc, .sample_precision = 8, .width = @intCast(try number(p, 3)), .height = @intCast(try number(p, 4)), .components = components }, .quantization_tables = &q, .dc_huffman_tables = &dc, .ac_huffman_tables = &ac, .block_storage = try initializedBlocks(alloc, try number(p, 5), if (p[0][0] == 'D' or p[0][0] == 'I') 0 else try signed(p, 8), p[0][0] == 'R'), .frame_type = .sof0, .block_width = @intCast(try number(p, 9)), .block_height = @intCast(try number(p, 10)), .block_width_actual = @intCast(try number(p, 11)), .block_height_actual = @intCast(try number(p, 12)), .horizontal_sampling_factor_max = try number(p, 6), .vertical_sampling_factor_max = try number(p, 7) };
    if (observed_path != null) observed_frame = &f;
    var pixels: color.PixelStorage = .invalid;
    if (p[0][0] == 'R' or p[0][0] == 'A') {
        pixels = .{ .rgb24 = try alloc.alloc(color.Rgb24, try number(p, 13)) };
        @memset(pixels.rgb24, .{ .r = 17, .g = 18, .b = 19 });
    }
    if (p[0][0] == 'G') {
        pixels = .{ .grayscale8 = try alloc.alloc(color.Grayscale8, try number(p, 13)) };
        @memset(pixels.grayscale8, .{ .value = 17 });
    }
    if (observed_path != null) observed_pixels = &pixels;
    switch (p[0][0]) {
        'B' => {
            F.yCbCrToRgbBlock(&f, &f.block_storage[0], if (std.mem.eql(u8, p[15], "1")) &f.block_storage[0] else &f.block_storage[1], try number(p, 13), try number(p, 14));
        },
        'C' => try f.yCbCrToRgb(),
        'D', 'I' => {
            for (f.block_storage) |*b| {
                for (b) |*c| {
                    @memset(c, 0);
                    c[0] = try signed(p, 8);
                }
            }
            for (&q) |*slot| slot.* = .{ .q8 = @splat(@intCast(try number(p, 13))) };
            if (p[0][0] == 'D') f.dequantizeBlocks() catch |e| {
                try out.print("E{s}|{d}", .{ @errorName(e), blocksHash(f.block_storage) });
                return;
            } else f.idctBlocks();
        },
        'R' => {
            if (p.len > 14) f.block_storage[0][try number(p, 14)][try number(p, 15)] = try signed(p, 16);
            try f.renderToPixelsRgb(pixels.rgb24);
        },
        'G' => {
            if (p.len > 14) f.block_storage[0][0][try number(p, 14)] = try signed(p, 15);
            try f.renderToPixels(&pixels);
        },
        'A', 'U' => try f.renderToPixels(&pixels),
        'N' => {
            var copy = f;
            f.frame_header.width = 7;
            f.block_width = 11;
            q[0] = .{ .q8 = @splat(1) };
            f.block_storage[0][0][0] = 42;
            var jpeg = JPEG.init(alloc);
            jpeg.frame = f;
            jpeg.quantization_tables[0] = .{ .q8 = @splat(1) };
            const old = jpeg;
            jpeg.restart_interval = 9;
            jpeg.quantization_tables[0] = null;
            const returned = jpeg.frame.?;
            copy.frame_header.height = 9;
            try state(out, &f);
            try out.writeByte('|');
            try state(out, &copy);
            try out.print("|{d}|{d}|{d},{d},{d},{d}|", .{ blocksHash(copy.block_storage), @intFromBool(copy.quantization_tables[0] != null), old.restart_interval, jpeg.restart_interval, @intFromBool(old.quantization_tables[0] != null), @intFromBool(jpeg.quantization_tables[0] != null) });
            try state(out, &returned);
            return;
        },
        else => @panic("fixture operation"),
    }
    try state(out, &f);
    try out.print("|{d}|{d}", .{ blocksHash(f.block_storage), hash(pixels.asBytes()) });
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args);
    var buffer: [8192]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&buffer);
    const out = &writer.interface;
    if (args.len > 1 and std.mem.eql(u8, args[1], "--trap")) {
        observed_path = args[2];
        const parts = try split(args[3]);
        try record(out, parts);
        try out.writeByte('\n');
        try out.flush();
        return;
    }
    const input = try std.fs.cwd().readFileAlloc(a, args[1], 32 * 1024 * 1024);
    defer a.free(input);
    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        const parts = try split(line);
        defer a.free(parts);
        try record(out, parts);
        try out.writeByte('\n');
    }
    try out.flush();
}
fn split(line: []const u8) ![][]const u8 {
    var parts: std.ArrayList([]const u8) = .empty;
    var iter = std.mem.splitScalar(u8, line, '|');
    while (iter.next()) |part| try parts.append(a, part);
    return parts.toOwnedSlice(a);
}
