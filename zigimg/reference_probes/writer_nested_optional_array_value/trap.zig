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
    const view: []allowzero align(1) ?[2]i32 = @as([*]allowzero align(1) ?[2]i32, @ptrFromInt(0x1234))[0..0];
    const bool_view: []allowzero align(1) ?[2][3]bool = @as([*]allowzero align(1) ?[2][3]bool, @ptrFromInt(std.math.maxInt(usize)))[0..3];
    const optional_items: []allowzero align(1) ?[3]?u8 = @as([*]allowzero align(1) ?[3]?u8, @ptrFromInt(0))[0..0];
    const bool_payload: [3]?bool = .{ true, null, false };
    const bool_items: [2]?[3]?bool = .{ bool_payload, null };
    const bool_values: []const ?[3]?bool = &bool_items;
    const int_payload: [3]?i32 = .{ -7, null, 8 };
    const int_items: [2]?[3]?i32 = .{ int_payload, null };
    const int_values: []const ?[3]?i32 = &int_items;
    const options: std.fmt.Options = .{ .width = std.math.maxInt(usize), .precision = std.math.maxInt(usize) };
    const result = blk: {
        (switch (try std.fmt.parseInt(usize, args[3], 10)) {
            0 => w.printAddress(view),
            1 => w.printValue("*", options, view, 0),
            2 => w.printValue("?*", options, @as(?[]allowzero align(1) ?[2]i32, view), 0),
            3 => w.printAddress(bool_view),
            4 => w.printValue("?*", .{ .width = 6, .fill = '_' }, @as(?[]?[2]i32, null), 0),
            5 => w.printValue("?*", .{ .width = std.math.maxInt(usize), .fill = '_' }, @as(?[]?[2]i32, null), 0),
            6 => w.printAddress(optional_items),
            7 => w.printValue("any", .{}, bool_values, 2),
            8 => w.printValue("any", .{ .width = 4, .fill = '_' }, int_values, 2),
            9 => w.printValue("?any", .{ .width = 6, .fill = '_' }, @as(?[]const ?[3]?bool, null), 2),
            10 => w.print("L{[value]any}R", .{ .value = bool_values }),
            else => unreachable,
        }) catch |err| break :blk @errorName(err);
        break :blk "ok";
    };
    try save();
    var out = std.fs.File.stdout().writer(&.{});
    try out.interface.print("{s}\n", .{result});
}
