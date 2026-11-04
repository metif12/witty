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
    const options: std.fmt.Options = .{ .width = std.math.maxInt(usize), .precision = std.math.maxInt(usize) };
    const result = blk: {
        (switch (try std.fmt.parseInt(usize, args[3], 10)) {
            0 => w.printValue("*", options, @as(*allowzero align(1) [3]u8, @ptrFromInt(0x1234)), 0),
            1 => w.printValue("*", options, @as(*allowzero align(1) [2][3]i32, @ptrFromInt(0)), std.math.maxInt(usize)),
            2 => w.printValue("*", options, @as(*allowzero align(1) [1]f64, @ptrFromInt(std.math.maxInt(usize))), 0),
            else => unreachable,
        }) catch |err| break :blk @errorName(err);
        break :blk "ok";
    };
    try save();
    var out = std.fs.File.stdout().writer(&.{});
    try out.interface.print("{s}\n", .{result});
}
