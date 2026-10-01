const std = @import("std");
const zigimg = @import("zigimg");

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    std.debug.assert(args.len == 2);
    var codec = zigimg.formats.iff.IFF{ .format_id = .ilbm, .header = .{ .bmhd = .{ .width = 1, .height = 1, .planes = 1 } }, .pitch = 2 };
    if (std.mem.eql(u8, args[1], "row_stride")) {
        codec.header = .{ .bmhd = .{ .width = 65535, .height = 1, .planes = 8 } };
        codec.pitch = 8192;
        var planes = [_]u8{0} ** 65536;
        var chunky: [65535]u8 = undefined;
        try codec.planarToChunky(&planes, &chunky);
    } else if (std.mem.eql(u8, args[1], "padding_bit")) {
        var planes = [_]u8{ 0x40, 0 };
        var chunky: [1]u8 = undefined;
        try codec.planarToChunky(&planes, &chunky);
    } else if (std.mem.eql(u8, args[1], "empty_palette")) {
        var stream = zigimg.io.ReadStream.initMemory("");
        try codec.decodeCMAPChunk(&stream, &.{ .type = 0, .length = 0 });
    } else if (std.mem.eql(u8, args[1], "ham_bits")) {
        codec.header = .{ .bmhd = .{ .planes = 5 } };
        codec.cmap_bits = 8;
        codec.palette.resize(256);
        codec.reduceHamPalette();
    } else @panic("unknown case");
    std.debug.print("UNEXPECTED: decoder returned\n", .{});
}
