const std = @import("std");
const fixed = @import("src/utils.zig").FixedStorage;
const color = @import("src/color.zig");
const allocator = std.heap.page_allocator;
fn mix(hash: *u64, value: u64) void {
    hash.* = (hash.* ^ value) *% 1099511628211;
}
fn run(comptime T: type, comptime capacity: usize, trap: bool, output: *std.Io.Writer) !void {
    var buffer = fixed(T, capacity){};
    if (trap) {
        buffer.resize(capacity + 1);
        std.debug.print("UNEXPECTED\n", .{});
        return;
    }
    const bytes = std.mem.sliceAsBytes(&buffer.storage);
    for (bytes, 0..) |*byte, i| byte.* = @truncate(i * 37 + 11);
    for (0..capacity + 1) |size| {
        buffer.resize(size);
        const borrowed = size == 0 or buffer.data.ptr == &buffer.storage;
        const old = buffer.data;
        buffer.resize(0);
        if (size > 0) {
            const old_bytes = std.mem.sliceAsBytes(old);
            old_bytes[old_bytes.len - 1] ^= 0x5a;
        }
        buffer.resize(size);
        var active: u64 = 14695981039346656037;
        for (std.mem.sliceAsBytes(buffer.data)) |byte| mix(&active, byte);
        var hash: u64 = 14695981039346656037;
        for (bytes) |byte| mix(&hash, byte);
        try output.print("{d}:{d}:{d}|{}:{d}:{d}:{x:0>16}:{x:0>16}\n", .{ @sizeOf(T), capacity, size, borrowed, old.len, buffer.data.len, active, hash });
    }
}
pub fn main() !void {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    var output = std.fs.File.stdout().writer(&.{});
    if (args.len > 1 and std.mem.eql(u8, args[1], "special8")) {
        try run(u16, 8, true, &output.interface);
        return;
    }
    if (args.len > 1 and std.mem.eql(u8, args[1], "special256")) {
        try run(u16, 256, true, &output.interface);
        return;
    }
    const selected: ?usize = if (args.len > 1) std.fmt.parseInt(usize, args[1], 10) catch 0 else null;
    try run(u8, 0, selected == 0, &output.interface);
    try run(u8, 1, selected == 1, &output.interface);
    try run(u8, 7, selected == 2, &output.interface);
    try run(u8, 8, selected == 3, &output.interface);
    try run(u8, 256, selected == 4, &output.interface);
    try run(u8, 513, selected == 5, &output.interface);
    try run(u16, 0, selected == 6, &output.interface);
    try run(u16, 1, selected == 7, &output.interface);
    try run(u16, 7, selected == 8, &output.interface);
    try run(u16, 8, selected == 9, &output.interface);
    try run(u16, 256, selected == 10, &output.interface);
    try run(u16, 513, selected == 11, &output.interface);
    try run(color.Rgba32, 0, selected == 12, &output.interface);
    try run(color.Rgba32, 1, selected == 13, &output.interface);
    try run(color.Rgba32, 7, selected == 14, &output.interface);
    try run(color.Rgba32, 8, selected == 15, &output.interface);
    try run(color.Rgba32, 256, selected == 16, &output.interface);
    try run(color.Rgba32, 513, selected == 17, &output.interface);
}
