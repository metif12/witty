const std = @import("std");
const vaxis = @import("vaxis");
pub fn main() !void {
    var buffer: vaxis.widgets.TextView.Buffer = .{};
    const writer: vaxis.widgets.TextView.BufferWriter = .{ .allocator = std.heap.page_allocator, .buffer = &buffer };
    _ = try writer.write("x");
}
