const std = @import("std");
const Image = @import("src/Image.zig");
const ImageUnmanaged = @import("src/ImageUnmanaged.zig");

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    std.debug.assert(args.len == 2);
    const bytes = "#define w 8\n";
    if (std.mem.eql(u8, args[1], "managed")) {
        _ = try Image.detectFormatFromMemory(bytes);
    } else if (std.mem.eql(u8, args[1], "unmanaged")) {
        _ = try ImageUnmanaged.detectFormatFromMemory(bytes);
    } else @panic("unknown case");
    @panic("UNEXPECTED: image detection returned");
}
