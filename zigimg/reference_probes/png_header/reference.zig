const std = @import("std");
const png = @import("src/formats/png/types.zig");
const reader = @import("src/formats/png/reader.zig");
const io = @import("src/io.zig");
const PF = @import("src/pixel_format.zig").PixelFormat;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observePanic);
var observed: ?*const png.HeaderData = null;
var observed_path: ?[]const u8 = null;
fn fields(out: *W, h: png.HeaderData) !void {
    try out.print("{d},{d},{d},{d},{d},{d},{d}", .{ h.width, h.height, h.bit_depth, @intFromEnum(h.color_type), @intFromEnum(h.compression_method), @intFromEnum(h.filter_method), @intFromEnum(h.interlace_method) });
}
fn observePanic(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| if (observed) |h| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var buf: [256]u8 = undefined;
            var writer = file.writer(&buf);
            fields(&writer.interface, h.*) catch {};
            writer.interface.flush() catch {};
        } else |_| {}
    };
    std.debug.defaultPanic(message, address);
}
fn n(p: []const []const u8, i: usize) !u32 {
    return std.fmt.parseInt(u32, p[i], 10);
}
fn hex(out: *W, bytes: []const u8) !void {
    for (bytes) |b| try out.print("{x:0>2}", .{b});
}
fn record(out: *W, p: []const []const u8, id: usize, file_path: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try out.print("{d}|", .{id});
    if (p[0][0] == 'H') {
        const h: png.HeaderData = .{ .width = try n(p, 1), .height = try n(p, 2), .bit_depth = @intCast(try n(p, 3)), .color_type = @enumFromInt(try n(p, 4)), .compression_method = @enumFromInt(try n(p, 5)), .filter_method = @enumFromInt(try n(p, 6)), .interlace_method = @enumFromInt(try n(p, 7)) };
        try fields(out, h);
        try out.print("|{d},{d},{d},{d},{d},{d}|", .{ @intFromBool(h.isValid()), @intFromBool(h.allowsPalette()), h.maxPaletteSize(), h.channelCount(), h.pixelBits(), h.lineBytes() });
        const valid_depth = switch (h.color_type) {
            .grayscale => h.bit_depth == 1 or h.bit_depth == 2 or h.bit_depth == 4 or h.bit_depth == 8 or h.bit_depth == 16,
            .indexed => h.bit_depth == 1 or h.bit_depth == 2 or h.bit_depth == 4 or h.bit_depth == 8,
            else => h.bit_depth == 8 or h.bit_depth == 16,
        };
        if (valid_depth) try out.print("{d}", .{@intFromEnum(h.getPixelFormat())}) else try out.writeAll("-");
    } else if (p[0][0] == 'F') {
        if (png.ColorType.fromPixelFormat(@as(PF, @enumFromInt(try n(p, 1))))) |c| try out.print("{d}|{d}", .{ @intFromEnum(c), c.channelCount() }) else |err| try out.print("E{s}", .{@errorName(err)});
    } else if (p[0][0] == 'C') {
        var name: [4:0]u8 = @splat(0);
        _ = try std.fmt.hexToBytes(name[0..4], p[1]);
        const c = png.Chunk.init(&name);
        const copy = c;
        name[try n(p, 2)] = @intCast(try n(p, 3));
        try out.print("{d}|", .{c.id});
        try hex(out, c.name);
        try out.print("|{d}|", .{copy.id});
        try hex(out, copy.name);
        var header: png.ChunkHeader = .{ .length = try n(p, 4), .type = c.id };
        const copied = header;
        const borrowed = header.name();
        header.type ^= 0xffffffff;
        try out.print("|{d}|", .{header.length});
        try hex(out, borrowed);
        try out.print("|{d}|{d},{d}", .{ copied.type, @intFromBool(reader.isChunkCritical(c.id)), @intFromBool(reader.isChunkCritical(header.type)) });
    } else {
        const bytes = try a.alloc(u8, p[2].len / 2);
        _ = try std.fmt.hexToBytes(bytes, p[2]);
        const size = try n(p, 1);
        const buf = try a.alloc(u8, size);
        @memset(buf, 0xa5);
        var stream = io.ReadStream.initMemory(bytes);
        var file: ?std.fs.File = null;
        defer if (file) |f| f.close();
        if (size > 0) {
            try std.fs.cwd().writeFile(.{ .sub_path = file_path, .data = bytes });
            file = try std.fs.cwd().openFile(file_path, .{});
            stream = io.ReadStream.initFile(file.?, buf);
        }
        if (reader.loadHeader(&stream)) |h| {
            try out.writeAll("OK|");
            try fields(out, h);
        } else |err| try out.print("E{s}", .{@errorName(err)});
        try out.print("|{d}", .{stream.getPos()});
    }
    try out.writeAll("\n");
}
fn trap(name: []const u8, path: []const u8) void {
    var h: png.HeaderData = .{ .width = 1, .height = 1, .bit_depth = 8, .color_type = .grayscale, .compression_method = .deflate, .filter_method = .adaptive, .interlace_method = .none };
    observed = &h;
    observed_path = path;
    if (std.mem.eql(u8, name, "pixel_rgb")) {
        h.color_type = .rgb_color;
        h.bit_depth = 86;
        std.mem.doNotOptimizeAway(h.pixelBits());
    } else if (std.mem.eql(u8, name, "pixel_rgba")) {
        h.color_type = .rgba_color;
        h.bit_depth = 64;
        std.mem.doNotOptimizeAway(h.pixelBits());
    } else if (std.mem.eql(u8, name, "pixel_alpha")) {
        h.color_type = .grayscale_alpha;
        h.bit_depth = 128;
        std.mem.doNotOptimizeAway(h.pixelBits());
    } else if (std.mem.eql(u8, name, "line_pixel_first")) {
        h.width = 0;
        h.color_type = .rgba_color;
        h.bit_depth = 255;
        std.mem.doNotOptimizeAway(h.lineBytes());
    } else if (std.mem.eql(u8, name, "line_mul")) {
        h.width = 134217728;
        h.color_type = .rgba_color;
        std.mem.doNotOptimizeAway(h.lineBytes());
    } else if (std.mem.eql(u8, name, "line_add")) {
        h.width = 0xfffffff9;
        h.bit_depth = 1;
        std.mem.doNotOptimizeAway(h.lineBytes());
    } else {
        h.width = 0;
        h.height = 0;
        h.bit_depth = 0;
        if (std.mem.eql(u8, name, "format_rgb")) h.color_type = .rgb_color else if (std.mem.eql(u8, name, "format_index")) {
            h.color_type = .indexed;
            h.bit_depth = 16;
        } else if (std.mem.eql(u8, name, "format_alpha")) h.color_type = .grayscale_alpha else if (std.mem.eql(u8, name, "format_rgba")) h.color_type = .rgba_color;
        std.mem.doNotOptimizeAway(h.getPixelFormat());
    }
    @panic("UNEXPECTED returning trap");
}
pub fn main() !void {
    const a = std.heap.page_allocator;
    const args = try std.process.argsAlloc(a);
    if (args.len > 2 and std.mem.eql(u8, args[1], "--trap")) {
        trap(args[2], args[3]);
        return;
    }
    const input = try std.fs.cwd().readFileAlloc(a, args[1], 128 * 1024 * 1024);
    const file_path = try std.fmt.allocPrint(a, "{s}.png", .{args[1]});
    var buf: [65536]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&buf);
    var rows = std.mem.splitScalar(u8, input, '\n');
    var id: usize = 0;
    while (rows.next()) |line| {
        if (line.len == 0) continue;
        var split = std.mem.splitScalar(u8, line, '|');
        var parts: [10][]const u8 = undefined;
        var len: usize = 0;
        while (split.next()) |p| {
            parts[len] = p;
            len += 1;
        }
        try record(&writer.interface, parts[0..len], id, file_path);
        id += 1;
    }
    try writer.interface.flush();
}
