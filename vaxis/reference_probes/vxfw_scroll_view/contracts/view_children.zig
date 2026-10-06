const vaxis = @import("vaxis");
const fw = vaxis.vxfw;
fn build(_: *const anyopaque, _: usize, _: usize) ?fw.Widget {
    return null;
}
pub fn main() void {
    const value: fw.ScrollView = .{};
    _ = value;
}
