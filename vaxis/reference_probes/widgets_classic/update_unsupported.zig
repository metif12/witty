const std = @import("std");
const vaxis = @import("vaxis");
pub fn main() !void {
    var buffer: vaxis.widgets.TextView.Buffer = .{};
    try buffer.update(std.heap.page_allocator, .{ .bytes = "x" });
}
