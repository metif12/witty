const std = @import("std");
const p = @import("src/color.zig");
const a = std.heap.page_allocator;
const ByteAlias = u8;
const WordAlias = u16;
const SignedAlias = i16;
const Types = .{ bool, u8, u16, i8, i16, ByteAlias, WordAlias, SignedAlias };
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_len: ?*const usize = null;
var observed_bytes: []const u8 = &.{};
fn observe(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var buffer: [1024]u8 = undefined;
            var writer = file.writer(&buffer);
            const out = &writer.interface;
            if (observed_len) |len| out.print("{d}|", .{len.*}) catch {} else out.writeAll("-|") catch {};
            out.print("{x}", .{observed_bytes}) catch {};
            out.flush() catch {};
        } else |_| {}
    }
    std.debug.defaultPanic(message, address);
}
fn scalar(comptime T: type, raw: u32) T {
    if (T == bool) return raw & 1 != 0;
    const U = std.meta.Int(.unsigned, @bitSizeOf(T));
    const bits: U = @truncate(raw);
    return @bitCast(bits);
}
fn emit(out: *W, value: anytype) !void {
    try out.print("{d},{d},{d}|", .{ value.palette.len, value.indices.len, std.hash.Fnv1a_64.hash(std.mem.sliceAsBytes(value.palette)) });
    for (value.indices) |index| try out.print("{any};", .{index});
    try out.writeByte('|');
}
fn changed(value: anytype, size: usize) @TypeOf(value) {
    var result = value;
    result.resizePalette(size);
    return result;
}
fn run(comptime T: type, out: *W, count: usize, size: usize, new_size: usize, seed: u32) !void {
    const S = p.IndexedStorage(T);
    const cap = S.PaletteSize;
    var x = if (size == cap) try S.init(a, count) else try S.initPaletteSize(a, count, size);
    defer x.deinit(a);
    for (x.indices, 0..) |*index, i| index.* = scalar(T, @as(u32, @intCast(i)) + seed);
    try out.print("{d}|", .{cap});
    try emit(out, x);
    x.resizePalette(cap);
    for (x.palette, 0..) |*color, i| color.* = p.Rgba32.from.rgba(@truncate(i + seed), @truncate(i >> 8), @truncate(i * 7 + seed), @truncate(i + 3));
    x.resizePalette(size);
    var copy = x;
    var returned = changed(x, new_size);
    if (copy.palette.len != 0) copy.palette[0] = p.Rgba32.from.rgba(9, 8, 7, 6);
    if (returned.palette.len != 0) returned.palette[0].a = 5;
    if (count != 0) copy.indices[0] = scalar(T, seed + 99);
    x.resizePalette((size + new_size) % (cap + 1));
    try emit(out, x);
    try emit(out, copy);
    try emit(out, returned);
    returned = copy;
    try emit(out, returned);
    x.resizePalette(cap);
    try emit(out, x);
}
fn trap(comptime T: type, mode: u8, size: usize) !void {
    const S = p.IndexedStorage(T);
    if (mode == 0) {
        _ = try S.initPaletteSize(a, 3, size);
    } else {
        var x = try S.initPaletteSize(a, 3, 1);
        observed_len = &x.palette.len;
        observed_bytes = std.mem.sliceAsBytes(x.palette);
        x.resizePalette(size);
    }
}
pub fn main() !void {
    const argv = try std.process.argsAlloc(a);
    var buffer: [64 * 1024]u8 = undefined;
    var output = std.fs.File.stdout().writer(&buffer);
    const out = &output.interface;
    if (std.mem.eql(u8, argv[1], "named")) {
        inline for (.{ p.IndexedStorage1, p.IndexedStorage2, p.IndexedStorage4, p.IndexedStorage8, p.IndexedStorage16 }) |S| {
            const x = try S.initPaletteSize(a, 0, 1);
            try out.print("{d}|", .{S.PaletteSize});
            try emit(out, x);
            try out.writeByte('\n');
            x.deinit(a);
        }
    } else if (std.mem.eql(u8, argv[1], "capacity")) {
        inline for (.{ u32, i32, f32 }) |T| try out.print("{d}\n", .{p.IndexedStorage(T).PaletteSize});
    } else if (std.mem.eql(u8, argv[1], "trap")) {
        observed_path = argv[2];
        const kind = try std.fmt.parseInt(usize, argv[3], 10);
        const mode = try std.fmt.parseInt(u8, argv[4], 10);
        const size = try std.fmt.parseInt(usize, argv[5], 10);
        inline for (Types, 0..) |T, i| if (kind == i) try trap(T, mode, size);
        return error.UnexpectedSuccess;
    } else {
        const contents = try std.fs.cwd().readFileAlloc(a, argv[1], 16 * 1024 * 1024);
        var lines = std.mem.tokenizeScalar(u8, contents, '\n');
        while (lines.next()) |line| {
            var parts = std.mem.splitScalar(u8, line, '|');
            const kind = try std.fmt.parseInt(usize, parts.next().?, 10);
            const count = try std.fmt.parseInt(usize, parts.next().?, 10);
            const size = try std.fmt.parseInt(usize, parts.next().?, 10);
            const new_size = try std.fmt.parseInt(usize, parts.next().?, 10);
            const seed = try std.fmt.parseInt(u32, parts.next().?, 10);
            inline for (Types, 0..) |T, i| if (kind == i) try run(T, out, count, size, new_size, seed);
            try out.writeByte('\n');
        }
    }
    try out.flush();
}
