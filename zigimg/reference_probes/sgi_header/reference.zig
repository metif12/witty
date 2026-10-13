const std = @import("std");
const p = @import("src/formats/sgi.zig");
const io = @import("src/io.zig");
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var observed_codec: ?*p.SGI = null;
var observed_stream: ?*io.ReadStream = null;
var observed_path: ?[]const u8 = null;
var observed_buffer: []const u8 = &.{};

fn recordBytes(out: *W, value: anytype) !void {
    try out.print("{x}", .{std.mem.asBytes(&value)});
}
fn snapshot(out: *W, codec: *const p.SGI, stream: *io.ReadStream, buffer: []const u8) !void {
    try out.print("{d}|", .{stream.getPos()});
    try recordBytes(out, codec.header);
    try out.print("|{x}|{d}|{d}|{x}", .{ std.mem.sliceAsBytes(&codec.palette.storage), codec.palette.data.len, stream.reader().bufferedLen(), buffer });
}
fn observe(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var buffer: [8192]u8 = undefined;
            var writer = file.writer(&buffer);
            if (observed_codec) |codec| snapshot(&writer.interface, codec, observed_stream.?, observed_buffer) catch {};
            writer.interface.flush() catch {};
        } else |_| {}
    }
    std.debug.defaultPanic(message, address);
}
fn record(out: *W, line: []const u8, path: []const u8, allocator: std.mem.Allocator) !void {
    var it = std.mem.splitScalar(u8, line, '|');
    const capacity = try std.fmt.parseInt(usize, it.next().?, 10);
    const reads = try std.fmt.parseInt(usize, it.next().?, 10);
    const encoded = it.next().?;
    const data = try allocator.alloc(u8, encoded.len / 2);
    _ = try std.fmt.hexToBytes(data, encoded);
    const buffer = try allocator.alloc(u8, capacity);
    @memset(buffer, 165);
    var stream = io.ReadStream.initMemory(data);
    var file: ?std.fs.File = null;
    if (capacity > 0) {
        try std.fs.cwd().writeFile(.{ .sub_path = path, .data = data });
        file = try std.fs.cwd().openFile(path, .{});
        stream = io.ReadStream.initFile(file.?, buffer);
    }
    defer if (file) |f| f.close();
    var codec: p.SGI = .{ .header = .{ .compression = .rle, .bytes_per_channel = 1, .dimension = .single_channel, .x_size = 7, .y_size = 9, .z_size = 3, .pix_min = 123, .pix_max = 456, .dummy1 = 789, .image_name = @splat(165), .pixel_format = .normal, .dummy2 = @splat(165) } };
    codec.palette.resize(256);
    for (codec.palette.data, 0..) |*entry, i| entry.* = .{ .r = @truncate(i * 31), .g = @truncate(i * 71), .b = @truncate(i * 47), .a = 99 };
    codec.palette.resize(4);
    if (observed_path != null) {
        observed_codec = &codec;
        observed_stream = &stream;
        observed_buffer = buffer;
    }
    for (0..reads) |_| {
        var pixels = codec.read(allocator, &stream) catch |err| {
            try out.print("E{s}|", .{@errorName(err)});
            try snapshot(out, &codec, &stream, buffer);
            try out.writeByte('~');
            continue;
        };
        const bytes = pixels.asBytes();
        try out.print("ok:{d}:{x}:", .{ @intFromEnum(std.meta.activeTag(pixels)), bytes });
        switch (pixels) {
            inline .indexed1, .indexed4, .indexed8 => |indexed| for (indexed.palette) |c| {
                try out.print("{x}", .{&[_]u8{ c.r, c.g, c.b, c.a }});
            },
            else => {},
        }
        try out.writeByte('|');
        try snapshot(out, &codec, &stream, buffer);
        try out.writeByte('~');
        pixels.deinit(allocator);
    }
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    var buffer: [8192]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&buffer);
    const out = &stdout.interface;
    if (args.len == 4 and std.mem.eql(u8, args[1], "--trap")) {
        observed_path = args[2];
        try record(out, args[3], try std.fmt.allocPrint(a, "{s}.bin", .{args[2]}), a);
        try out.writeByte('\n');
        try out.flush();
        return;
    }
    const input = try std.fs.cwd().readFileAlloc(a, args[1], 64 * 1024 * 1024);
    var lines = std.mem.splitScalar(u8, input, '\n');
    const path = try std.fmt.allocPrint(a, "{s}.zig.bin", .{args[1]});
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var arena = std.heap.ArenaAllocator.init(a);
        defer arena.deinit();
        try record(out, line, path, arena.allocator());
        try out.writeByte('\n');
    }
    try out.flush();
}
