const std = @import("std");
const io = @import("src/io.zig");
const JPEG = @import("src/formats/jpeg.zig").JPEG;
const Frame = @import("src/formats/jpeg/Frame.zig");
const Header = @import("src/formats/jpeg/FrameHeader.zig");
const Component = @typeInfo(@FieldType(Header, "components")).pointer.child;
const H = @import("src/formats/jpeg/huffman.zig").Table;
const color = @import("src/color.zig");
const W = std.Io.Writer;
const allocator = std.heap.page_allocator;
pub const panic = std.debug.FullPanic(observe);
var observed_jpeg: ?*JPEG = null;
var observed_pixels: ?*?color.PixelStorage = null;
var observed_stream: ?*io.ReadStream = null;
var observed_known: bool = false;
var observed_path: ?[]const u8 = null;

fn hash(bytes: []const u8) u64 {
    var h: u64 = 14695981039346656037;
    for (bytes) |b| h = (h ^ b) *% 1099511628211;
    return h;
}
fn appendInt(bytes: *std.ArrayList(u8), a: std.mem.Allocator, value: u32) !void {
    for ([_]u5{ 0, 8, 16, 24 }) |shift| try bytes.append(a, @truncate(value >> shift));
}
fn blockHash(f: Frame, a: std.mem.Allocator) !u64 {
    var bytes: std.ArrayList(u8) = .empty;
    for (f.block_storage) |b| {
        for (b) |c| {
            for (c) |v| try appendInt(&bytes, a, @bitCast(v));
        }
    }
    return hash(bytes.items);
}
fn tableHash(t: H, a: std.mem.Allocator) !u64 {
    var bytes: std.ArrayList(u8) = .empty;
    try bytes.append(a, t.table_class);
    try bytes.appendSlice(a, &t.code_counts);
    try bytes.appendSlice(a, &t.fast_table);
    for (t.fast_size) |v| try bytes.append(a, v);
    const keys = try a.alloc(u32, t.code_map.count());
    for (t.code_map.keys(), 0..) |k, i| keys[i] = (@as(u32, k.length_minus_one) << 16) | k.code;
    std.mem.sort(u32, keys, {}, std.sort.asc(u32));
    for (keys) |k| {
        try appendInt(&bytes, a, k);
        try bytes.append(a, t.code_map.get(.{ .length_minus_one = @intCast(k >> 16), .code = @truncate(k) }).?);
    }
    return hash(bytes.items);
}
fn snapshot(out: *W, jpeg: *const JPEG, pixels: ?color.PixelStorage, known: bool, a: std.mem.Allocator) !void {
    try out.print("{d}|", .{jpeg.restart_interval});
    if (jpeg.frame) |f| {
        try out.print("{d},{d},{d},{d},{d},{d},{d},{d},", .{ f.frame_header.width, f.frame_header.height, f.frame_header.components.len, f.block_width, f.block_height, f.block_width_actual, f.block_height_actual, f.block_storage.len });
        if (known) try out.print("{d}", .{try blockHash(f, a)}) else try out.writeByte('?');
    } else try out.writeByte('-');
    try out.writeByte('|');
    for (jpeg.quantization_tables) |entry| {
        if (entry) |t| switch (t) {
            .q8 => |values| try out.print("0:{d};", .{hash(&values)}),
            .q16 => |values| {
                var bytes: std.ArrayList(u8) = .empty;
                for (values) |v| {
                    try bytes.append(a, @truncate(v));
                    try bytes.append(a, @truncate(v >> 8));
                }
                try out.print("1:{d};", .{hash(bytes.items)});
            },
        } else try out.writeAll("-;");
    }
    try out.writeByte('|');
    for (jpeg.dc_huffman_tables) |entry| {
        if (entry) |t| try out.print("{d};", .{try tableHash(t, a)}) else try out.writeAll("-;");
    }
    try out.writeByte('|');
    for (jpeg.ac_huffman_tables) |entry| {
        if (entry) |t| try out.print("{d};", .{try tableHash(t, a)}) else try out.writeAll("-;");
    }
    try out.writeByte('|');
    if (pixels) |pix| {
        try out.print("{s},{d},", .{ @tagName(pix), pix.len() });
        if (known or jpeg.frame == null) try out.print("{d}", .{hash(pix.asBytes())}) else try out.writeByte('?');
    } else try out.writeByte('-');
}
fn observe(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var arena = std.heap.ArenaAllocator.init(allocator);
            defer arena.deinit();
            var buffer: [8192]u8 = undefined;
            var writer = file.writer(&buffer);
            const out = &writer.interface;
            if (observed_stream) |s| out.print("{d}|", .{s.getPos()}) catch {};
            if (observed_jpeg) |j| if (observed_pixels) |p| {
                snapshot(out, j, p.*, observed_known, arena.allocator()) catch {};
            };
            out.flush() catch {};
        } else |_| {}
    }
    std.debug.defaultPanic(message, address);
}
fn number(p: []const []const u8, i: usize) !usize {
    return std.fmt.parseInt(usize, p[i], 10);
}
fn initialPixels(kind: usize, count: usize, a: std.mem.Allocator) !?color.PixelStorage {
    return switch (kind) {
        0 => null,
        1 => .invalid,
        2 => blk: {
            const pixels = try a.alloc(color.Grayscale8, count);
            @memset(pixels, .{ .value = 17 });
            break :blk .{ .grayscale8 = pixels };
        },
        3 => blk: {
            const pixels = try a.alloc(color.Rgb24, count);
            @memset(pixels, .{ .r = 17, .g = 18, .b = 19 });
            break :blk .{ .rgb24 = pixels };
        },
        else => @panic("pixel fixture"),
    };
}
fn record(out: *W, p: []const []const u8, file_path: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var jpeg = JPEG.init(a);
    jpeg.restart_interval = @intCast(try number(p, 10));
    var pixels = try initialPixels(try number(p, 8), try number(p, 9), a);
    for (0..4) |i| {
        switch (try number(p, 6)) {
            1 => jpeg.quantization_tables[i] = .{ .q8 = @splat(@intCast(try number(p, 7))) },
            2 => jpeg.quantization_tables[i] = .{ .q16 = @splat(@intCast(try number(p, 7))) },
            else => {},
        }
        for (0..2) |cls| {
            if ((try number(p, 11)) & (@as(usize, 1) << @intCast(i + cls * 4)) == 0) continue;
            const bytes = [_]u8{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 42 };
            var reader = std.Io.Reader.fixed(&bytes);
            const t = try H.read(a, @intCast(cls), &reader);
            if (cls == 0) jpeg.dc_huffman_tables[i] = t else jpeg.ac_huffman_tables[i] = t;
        }
    }
    const known = std.mem.eql(u8, p[1], "1");
    if (known) {
        const components = try a.alloc(Component, try number(p, 2));
        for (components, 0..) |*c, i| c.* = .{ .id = @intCast(i + 1), .horizontal_sampling_factor = 1, .vertical_sampling_factor = 1, .quantization_table_id = @intCast(i) };
        const bw = ((try number(p, 3)) + 7) / 8;
        const bh = ((try number(p, 4)) + 7) / 8;
        const storage = try a.alloc([3][64]i32, bw * bh);
        for (storage) |*b| {
            for (b) |*c| {
                @memset(c, 0);
                c[0] = try std.fmt.parseInt(i32, p[5], 10);
            }
        }
        jpeg.frame = .{ .allocator = a, .frame_header = .{ .allocator = a, .sample_precision = 8, .width = @intCast(try number(p, 3)), .height = @intCast(try number(p, 4)), .components = components }, .quantization_tables = &jpeg.quantization_tables, .dc_huffman_tables = &jpeg.dc_huffman_tables, .ac_huffman_tables = &jpeg.ac_huffman_tables, .block_storage = storage, .frame_type = .sof0, .block_width = @intCast(bw), .block_height = @intCast(bh), .block_width_actual = @intCast(bw), .block_height_actual = @intCast(bh), .horizontal_sampling_factor_max = 1, .vertical_sampling_factor_max = 1 };
    }
    if (observed_path != null) {
        observed_jpeg = &jpeg;
        observed_pixels = &pixels;
        observed_known = known;
    }
    var stages = std.mem.splitScalar(u8, p[0], ',');
    var index: usize = 0;
    while (stages.next()) |encoded| : (index += 1) {
        if (index > 0 and std.mem.eql(u8, p[12], "1")) pixels = try initialPixels(try number(p, 8), try number(p, 9), a);
        const bytes = try a.alloc(u8, encoded.len / 2);
        _ = try std.fmt.hexToBytes(bytes, encoded);
        const buffer = try a.alloc(u8, try number(p, 13));
        var stream = io.ReadStream.initMemory(bytes);
        var file: ?std.fs.File = null;
        if (buffer.len > 0) {
            try std.fs.cwd().writeFile(.{ .sub_path = file_path, .data = bytes });
            file = try std.fs.cwd().openFile(file_path, .{});
            stream = io.ReadStream.initFile(file.?, buffer);
        }
        if (observed_path != null) observed_stream = &stream;
        if (jpeg.read(&stream, &pixels)) |_| try out.writeAll("ok") else |err| try out.print("E{s}", .{@errorName(err)});
        try out.print("|{d}|", .{stream.getPos()});
        try snapshot(out, &jpeg, pixels, known, a);
        try out.writeByte('~');
        if (file) |f| f.close();
    }
}
fn split(line: []const u8) ![][]const u8 {
    var values: std.ArrayList([]const u8) = .empty;
    var it = std.mem.splitScalar(u8, line, '|');
    while (it.next()) |v| try values.append(allocator, v);
    return values.toOwnedSlice(allocator);
}
pub fn main() !void {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    var buffer: [8192]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&buffer);
    const out = &writer.interface;
    if (args.len > 1 and std.mem.eql(u8, args[1], "--trap")) {
        observed_path = args[2];
        const parts = try split(args[3]);
        try record(out, parts, try std.fmt.allocPrint(allocator, "{s}.bin", .{args[2]}));
        try out.writeByte('\n');
        try out.flush();
        return;
    }
    const input = try std.fs.cwd().readFileAlloc(allocator, args[1], 32 * 1024 * 1024);
    defer allocator.free(input);
    const file_path = try std.fmt.allocPrint(allocator, "{s}.bin", .{args[1]});
    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        const parts = try split(line);
        defer allocator.free(parts);
        try record(out, parts, file_path);
        try out.writeByte('\n');
    }
    try out.flush();
}
