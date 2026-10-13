const std = @import("std");
const p = @import("src/io.zig");
const a = std.heap.page_allocator;
const W = std.Io.Writer;

fn run(comptime endian: std.builtin.Endian, writer: *W, kind: u8, raw: u8, count: u4, capacity: usize, repeats: usize) !void {
    if (kind == 0) {
        var data = [_]u8{ 0xab, 0xcd };
        var input = p.ReadStream.initMemory(&data);
        var bits = p.BitReader(endian){ .reader = input.reader(), .bits = raw, .count = count };
        const copied = bits;
        bits.alignToByte();
        try writer.print("{d}:{d}:{d}|{d}:{d}:{d}:{d}|", .{ raw, count, input.getPos(), bits.bits, bits.count, copied.bits, copied.count });
        try input.seekTo(1);
        bits.alignToByte();
        try writer.print("{d}:{d}:{d}:{d}\n", .{ input.getPos(), bits.bits, bits.count, @intFromBool(bits.reader == copied.reader) });
        return;
    }
    const data = try a.alloc(u8, capacity);
    defer a.free(data);
    @memset(data, 0xa5);
    var output = p.WriteStream.initMemory(data);
    var bits = p.BitWriter(endian){ .writer = output.writer(), .bits = raw, .count = count };
    const copied = bits;
    try writer.print("{d}:{d}|", .{ copied.bits, copied.count });
    for (0..repeats) |_| {
        var status: []const u8 = "ok";
        bits.flushBits() catch |err| {
            status = @errorName(err);
        };
        try writer.print("{s}:{d}:{d}:{d}:{x}|", .{ status, output.getPos(), bits.bits, bits.count, data });
    }
    try writer.print("{d}:{d}:{d}\n", .{ copied.bits, copied.count, @intFromBool(bits.writer == copied.writer) });
}

pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args);
    const text = try std.fs.cwd().readFileAlloc(a, args[1], 16 * 1024 * 1024);
    defer a.free(text);
    var buffer: [8192]u8 = undefined;
    var output = std.fs.File.stdout().writer(&buffer);
    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    while (lines.next()) |line| {
        var parts = std.mem.splitScalar(u8, line, '|');
        var values: [6]usize = undefined;
        for (&values) |*value| value.* = try std.fmt.parseInt(usize, parts.next().?, 10);
        if (values[1] % 2 == 0) {
            try run(.little, &output.interface, @intCast(values[0]), @intCast(values[2]), @intCast(values[3]), values[4], values[5]);
        } else {
            try run(.big, &output.interface, @intCast(values[0]), @intCast(values[2]), @intCast(values[3]), values[4], values[5]);
        }
    }
    try output.interface.flush();
}
