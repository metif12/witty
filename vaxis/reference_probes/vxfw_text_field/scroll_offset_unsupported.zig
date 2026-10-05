const std = @import("std");
const vaxis = @import("vaxis");
pub fn main() void {
    const value: vaxis.vxfw.TextField = .{ .buf = .init(std.heap.page_allocator), .scroll_offset = 16 };
    _ = value;
}
