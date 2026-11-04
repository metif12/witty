const std = @import("std");
const W = std.Io.Writer;
const a = std.heap.page_allocator;
var path: []const u8 = "";
var w: *W = undefined;
fn save() !void {
    var out: W.Allocating = .init(a);
    try out.writer.print("{d}|{x}|{x}|{x}", .{ w.end, w.buffer, w.buffered(), w.unusedCapacitySlice() });
    try std.fs.cwd().writeFile(.{ .sub_path = path, .data = out.written() });
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    path = args[1];
    const buffer = try a.alloc(u8, try std.fmt.parseInt(usize, args[2], 10));
    @memset(buffer, 0xa5);
    var writer: W = .fixed(buffer);
    w = &writer;
    const view: []allowzero const u8 = @as([*]allowzero const u8, @ptrFromInt(0x1234))[0..3];
    const maximal: []allowzero const u8 = @as([*]allowzero const u8, @ptrFromInt(std.math.maxInt(usize)))[0..0];
    const options: std.fmt.Options = .{ .width = std.math.maxInt(usize), .precision = std.math.maxInt(usize) };
    const result = blk: {
        (switch (try std.fmt.parseInt(usize, args[3], 10)) {
            0, 1 => w.printAddress(view),
            2 => w.printValue("*", options, view, 0),
            3 => w.printValue("?*", options, @as(?[]allowzero const u8, maximal), 0),
            4 => w.printValue("?*", .{ .width = 6, .fill = '_' }, @as(?[]const u8, null), 0),
            5 => w.printValue("?*", .{ .width = std.math.maxInt(usize), .fill = '_' }, @as(?[]const u8, null), 0),
            else => unreachable,
        }) catch |err| break :blk @errorName(err);
        break :blk "ok";
    };
    try save();
    var out = std.fs.File.stdout().writer(&.{});
    try out.interface.print("{s}\n", .{result});
}
