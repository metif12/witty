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
        const options: std.fmt.Options = .{ .width = std.math.maxInt(usize), .precision = std.math.maxInt(usize), .alignment = .left, .fill = '_' };
        (switch (try std.fmt.parseInt(usize, args[3], 10)) {
            0 => writer.printValue("any", options, @as(*allowzero u8, @ptrFromInt(0x12)), 0),
            1, 3 => writer.printValue("any", options, @as(?*u8, @ptrFromInt(0x12)), 0),
            2 => writer.printValue("any", options, @as(*allowzero anyopaque, @ptrFromInt(0x12)), 0),
            4 => writer.printValue("any", options, @as(?*u8, null), 0),
            5 => writer.printValue("*", options, @as(*allowzero u8, @ptrFromInt(0x12)), 0),
            else => unreachable,
        }) catch |err| break :blk @errorName(err);
        break :blk "ok";
    };
    save();
    var stdout = std.fs.File.stdout().writer(&.{});
    try stdout.interface.print("{s}\n", .{result});
}
