const fw = @import("vaxis").vxfw;
pub fn main() void {
    const view: fw.ScrollView = .{ .children = .{ .slice = &.{} }, .scroll = .{ .vertical_offset = -65537 } };
    _ = view;
}
