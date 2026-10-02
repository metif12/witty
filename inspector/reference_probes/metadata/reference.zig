const std = @import("std");
const osc = @import("terminal/osc.zig");
pub fn main() void {
    std.debug.print("requests={s}\nlist={s}\n", .{@typeName(@FieldType(@FieldType(osc.Command, "color_operation"), "requests")), @typeName(@FieldType(@FieldType(osc.Command, "kitty_color_protocol"), "list"))});
}
