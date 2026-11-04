const std = @import("std");
const W = std.Io.Writer;
const a = std.heap.page_allocator;
pub const panic = std.debug.FullPanic(observe);
var observed_path: []const u8 = "";
var observed_writer: *W = undefined;
fn save() void {
    var out: W.Allocating = .init(a);
    const writer = observed_writer;
    out.writer.print("{d}|{x}|{x}|{x}", .{ writer.end, writer.buffer, writer.buffered(), writer.unusedCapacitySlice() }) catch @trap();
    std.fs.cwd().writeFile(.{ .sub_path = observed_path, .data = out.written() }) catch @trap();
}
fn observe(message: []const u8, trace: ?usize) noreturn {
    save();
    std.debug.defaultPanic(message, trace);
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    observed_path = args[1];
    const buffer = try a.alloc(u8, try std.fmt.parseInt(usize, args[2], 10));
    @memset(buffer, 0xa5);
    var writer: W = .fixed(buffer);
    observed_writer = &writer;
    const result = blk: {
        const value: *allowzero align(1) []u8 = @ptrFromInt(0x1234);
        (switch (try std.fmt.parseInt(usize, args[3], 10)) {
            0 => writer.printValue("any", .{}, value, 0),
            1 => writer.printAddress(value),
            2 => writer.printValue("*", .{ .width = std.math.maxInt(usize) }, @as(*allowzero []u8, @ptrFromInt(0)), 0),
            3 => writer.printValue("?*", .{}, @as(?*[]u8, @ptrFromInt(0x1000)), 0),
            4 => writer.printValue("?*", .{ .width = 6, .fill = 95 }, @as(?*[]u8, null), 0),
            5 => writer.printAddress(@as(?*[]u8, null)),
            6 => writer.printAddress(@as(*allowzero align(1) [2]*[]u8, @ptrFromInt(0x1234))),
            else => unreachable,
        }) catch |err| break :blk @errorName(err);
        break :blk "ok";
    };
    save();
    var stdout = std.fs.File.stdout().writer(&.{});
    try stdout.interface.print("{s}\n", .{result});
}
