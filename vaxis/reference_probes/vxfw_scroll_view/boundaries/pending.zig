const fw = @import("vaxis").vxfw;
pub fn main() void {
    const view: fw.ScrollView = .{ .children = .{ .slice = &.{} }, .scroll = .{ .pending_lines = 65536 } };
    _ = view;
}
