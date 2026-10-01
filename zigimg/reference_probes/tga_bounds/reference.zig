const std = @import("std");
const zigimg = @import("zigimg");

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    std.debug.assert(args.len == 2);
    var bytes: [48]u8 = @splat(0);
    bytes[2] = 1;
    bytes[3] = 1;
    bytes[5] = 1;
    bytes[7] = 24;
    bytes[16] = 8;
    if (std.mem.eql(u8, args[1], "palette_index")) {} else if (std.mem.eql(u8, args[1], "palette_sum")) {
        bytes[3] = 255;
        bytes[4] = 255;
    } else if (std.mem.eql(u8, args[1], "pixel_byte_sum")) {
        bytes[2] = 11;
        bytes[16] = 249;
    } else if (std.mem.eql(u8, args[1], "palette_capacity")) {
        bytes[3] = 0;
        bytes[5] = 1;
        bytes[6] = 1;
    } else @panic("unknown case");
    var source = zigimg.io.ReadStream.initMemory(&bytes);
    var codec = zigimg.formats.tga.TGA{};
    if (codec.read(std.heap.page_allocator, &source)) |_| {
        std.debug.print("UNEXPECTED: decoder returned\n", .{});
    } else |err| {
        std.debug.print("UNEXPECTED: recoverable {}\n", .{err});
    }
}
