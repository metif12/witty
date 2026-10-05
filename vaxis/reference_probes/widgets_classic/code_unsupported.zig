const std = @import("std");
const vaxis = @import("vaxis");
pub fn main() !void {
    const buffer: vaxis.widgets.TextView.Buffer = .{};
    var screen: vaxis.Screen = .{};
    const win: vaxis.Window = .{ .x_off = 0, .y_off = 0, .parent_x_off = 0, .parent_y_off = 0, .width = 0, .height = 0, .screen = &screen };
    var code: vaxis.widgets.CodeView = .{};
    code.draw(win, buffer, .{});
}
