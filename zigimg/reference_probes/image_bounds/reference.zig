const std = @import("std");
const Image = @import("src/Image.zig");
const ImageUnmanaged = @import("src/ImageUnmanaged.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    std.debug.assert(args.len == 2);
    const name = args[1];
    var image = Image.init(allocator);
    var unmanaged = ImageUnmanaged{};
    if (std.mem.eql(u8, name, "managed_create")) {
        image = try Image.create(allocator, std.math.maxInt(usize), 2, .invalid);
    } else if (std.mem.eql(u8, name, "unmanaged_create")) {
        unmanaged = try ImageUnmanaged.create(allocator, std.math.maxInt(usize), 2, .invalid);
    } else if (std.mem.eql(u8, name, "managed_row")) {
        _ = image.rowByteSize();
    } else if (std.mem.eql(u8, name, "unmanaged_row")) {
        _ = unmanaged.rowByteSize();
    } else if (std.mem.eql(u8, name, "managed_flip")) {
        try image.flipVertically();
    } else if (std.mem.eql(u8, name, "unmanaged_flip")) {
        try unmanaged.flipVertically(allocator);
    } else if (std.mem.eql(u8, name, "managed_crop")) {
        image.width = std.math.maxInt(usize);
        image.height = 2;
        _ = try image.crop(allocator, .{ .width = std.math.maxInt(usize), .height = 2 });
    } else if (std.mem.eql(u8, name, "unmanaged_crop")) {
        unmanaged.width = std.math.maxInt(usize);
        unmanaged.height = 2;
        _ = try unmanaged.crop(allocator, .{ .width = std.math.maxInt(usize), .height = 2 });
    } else @panic("unknown case");
    std.debug.print("UNEXPECTED: image operation returned\n", .{});
}
