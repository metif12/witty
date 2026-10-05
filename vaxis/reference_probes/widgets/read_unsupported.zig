const vaxis = @import("vaxis");
pub fn main() void {
    var screen: vaxis.Screen = .{};
    const win: vaxis.Window = .{ .x_off = 0, .y_off = 0, .parent_x_off = 0, .parent_y_off = 0, .width = 0, .height = 0, .screen = &screen };
    var view: vaxis.widgets.ScrollView = .{};
    _ = view.readCell(win, 0, 0);
}
