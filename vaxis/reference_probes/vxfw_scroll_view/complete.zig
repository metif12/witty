const vaxis = @import("vaxis");
const fw = vaxis.vxfw;
fn build(_: *const anyopaque, _: usize, _: usize) ?fw.Widget {
    return null;
}
pub fn main() void {
    _ = fw.ScrollView{ .children = .{ .slice = &.{} } };
    _ = fw.ScrollView.Builder{ .userdata = @ptrFromInt(1), .buildFn = build };
}
