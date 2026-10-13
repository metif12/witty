const std = @import("std");
const p = @import("src/formats/tga.zig");
const io = @import("src/io.zig");
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var observed_codec: ?*p.TGA = null;
var observed_stream: ?*io.ReadStream = null;
var observed_path: ?[]const u8 = null;

fn recordBytes(out: *W, value: anytype) !void {
    try out.print("{x}", .{std.mem.asBytes(&value)});
}
fn snapshot(out: *W, codec: *const p.TGA, stream: *const io.ReadStream) !void {
    try out.print("{d}|", .{stream.getPos()});
    try recordBytes(out, codec.header);
    try out.print("|{x}|", .{codec.id.data});
    if (codec.extension) |extension| try recordBytes(out, extension) else try out.writeByte('-');
}
fn observe(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var buffer: [8192]u8 = undefined;
            var writer = file.writer(&buffer);
            if (observed_codec) |codec| snapshot(&writer.interface, codec, observed_stream.?) catch {};
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
    var codec: p.TGA = .{ .header = .{ .image_spec = .{ .width = 99 } }, .extension = .{ .extension_size = 123, .attributes = .useful_alpha_channel } };
    codec.id.resize(3);
    @memcpy(codec.id.data, "OLD");
    if (observed_path != null) {
        observed_codec = &codec;
        observed_stream = &stream;
    }
    for (0..reads) |_| {
        var pixels = codec.read(allocator, &stream) catch |err| {
            try out.print("E{s}|", .{@errorName(err)});
            try snapshot(out, &codec, &stream);
            try out.writeByte('~');
            continue;
        };
        const bytes = try allocator.dupe(u8, pixels.asBytes());
        if (pixels == .rgb555) for (bytes, 0..) |*byte, i| {
            if (i % 2 == 1) byte.* &= 127;
        };
        try out.print("ok:{d}:{x}|", .{ @intFromEnum(std.meta.activeTag(pixels)), bytes });
        try snapshot(out, &codec, &stream);
        try out.writeByte('~');
        pixels.deinit(allocator);
    }
}
fn vectors(out: *W, path: []const u8) !void {
    try std.fs.cwd().writeFile(.{ .sub_path = path, .data = "0123456789abcdefghijklmnopqrstuvwxyz" });
    for ([_]usize{ 1, 8, 31, 64 }) |capacity| {
        for ([_]usize{ 1, 3, 8, 9, 32, 40 }) |length| {
            const file = try std.fs.cwd().openFile(path, .{});
            defer file.close();
            const buffer = try a.alloc(u8, capacity);
            @memset(buffer, 165);
            var stream = io.ReadStream.initFile(file, buffer);
            for (0..2) |attempt| {
                const destination = try a.alloc(u8, length);
                @memset(destination, 165);
                const count = try stream.reader().readSliceShort(destination);
                try out.print("{d}|{d}|{d}|{d}|{x}|{d}|{d}\n", .{ capacity, length, attempt, count, destination, stream.getPos(), stream.reader().bufferedLen() });
            }
        }
    }
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    var buffer: [8192]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&buffer);
    const out = &stdout.interface;
    if (args.len == 3 and std.mem.eql(u8, args[1], "--vectors")) {
        try vectors(out, args[2]);
        try out.flush();
        return;
    }
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
