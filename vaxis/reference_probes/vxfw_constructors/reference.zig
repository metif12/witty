const std = @import("std");
const vaxis = @import("vaxis");
const fw = vaxis.vxfw;
fn draw(_: *anyopaque, _: fw.DrawContext) std.mem.Allocator.Error!fw.Surface {
    return fw.Surface.empty(.{ .userdata = @ptrFromInt(1), .drawFn = draw });
}
fn click(_: ?*anyopaque, _: *fw.EventContext) anyerror!void {}
fn build(_: *const anyopaque, _: usize, _: usize) ?fw.Widget {
    return null;
}
pub fn main() !void {
    const user: fw.UserEvent = .{ .name = "event" };
    const widget: fw.Widget = .{ .userdata = @ptrFromInt(1), .drawFn = draw };
    const flex: fw.FlexItem = .{ .widget = widget };
    const context: fw.EventContext = .{ .alloc = std.heap.page_allocator, .cmds = .empty };
    const constraints: fw.DrawContext = .{ .arena = std.heap.page_allocator, .min = .{}, .max = .{}, .cell_size = .{} };
    const cursor: fw.CursorState = .{ .row = 7, .col = 9 };
    const surface: fw.Surface = .{ .size = .{}, .widget = widget, .buffer = &.{}, .children = &.{} };
    const sub: fw.SubSurface = .{ .origin = .{ .row = 0, .col = 0 }, .surface = surface };
    var buf: [256]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&buf);
    try writer.interface.print("{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}\n", .{
        @intFromBool(user.data == null),                @intFromBool(widget.captureHandler == null),                                    @intFromBool(widget.eventHandler == null),
        flex.flex,                                      @intFromEnum(context.phase),                                                    context.cmds.items.len,
        @intFromBool(context.consume_event),            @intFromBool(context.redraw),                                                   @intFromBool(context.quit),
        constraints.min.width + constraints.min.height, @intFromBool(constraints.max.width == null and constraints.max.height == null), constraints.cell_size.width + constraints.cell_size.height,
        @intFromEnum(cursor.shape),                     @intFromBool(surface.cursor == null),                                           sub.z_index,
        cursor.row + cursor.col,
    });
    const center: fw.Center = .{ .child = widget };
    const padding: fw.Padding = .{ .child = widget };
    const sized: fw.SizedBox = .{ .child = widget, .size = .{ .width = 7, .height = 9 } };
    const border: fw.Border = .{ .child = widget };
    const label: fw.Border.BorderLabel = .{ .text = "label", .alignment = .top_right };
    const column: fw.FlexColumn = .{ .children = &.{} };
    const row: fw.FlexRow = .{ .children = &.{} };
    const button: fw.Button = .{ .label = "button", .onClick = click };
    const text: fw.Text = .{ .text = "text" };
    const rich: fw.RichText = .{ .text = &.{} };
    const field: fw.TextField = .{ .buf = fw.TextField.Buffer.init(std.heap.page_allocator) };
    const list: fw.ListView = .{ .children = .{ .slice = &.{} } };
    const scrolling: fw.ScrollView = .{ .children = .{ .slice = &.{} } };
    const bars: fw.ScrollBars = .{ .scroll_view = scrolling };
    const split: fw.SplitView = .{ .lhs = widget, .rhs = widget, .width = 7 };
    const spinner: fw.Spinner = .{};
    const list_builder: fw.ListView.Builder = .{ .userdata = @ptrFromInt(1), .buildFn = build };
    const scroll_builder: fw.ScrollView.Builder = .{ .userdata = @ptrFromInt(1), .buildFn = build };
    try writer.interface.print("{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},", .{ @intFromBool(center.child.userdata == widget.userdata), padding.padding.left + padding.padding.right + padding.padding.top + padding.padding.bottom, sized.size.width + sized.size.height, border.labels.len, label.text.len, @intFromEnum(label.alignment), column.children.len, row.children.len, button.label.len, @intFromBool(button.userdata == null), @intFromBool(button.style.default.reverse), @intFromBool(button.mouse_down), @intFromBool(button.has_mouse), @intFromBool(button.focused), text.text.len, @intFromEnum(text.text_align), @intFromBool(text.softwrap), @intFromEnum(text.overflow), @intFromEnum(text.width_basis), rich.text.len, @intFromEnum(rich.text_align), @intFromBool(rich.softwrap), @intFromEnum(rich.overflow), @intFromEnum(rich.width_basis), field.buf.buffer.len, field.buf.cursor, field.buf.gap_size, field.draw_offset, field.prev_cursor_col, field.prev_cursor_idx, field.scroll_offset, field.prev_width });
    try writer.interface.print("{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}\n", .{ field.previous_val.len, @intFromBool(field.userdata == null), @intFromBool(field.onChange == null), @intFromBool(field.onSubmit == null), list.cursor, @intFromBool(list.draw_cursor), list.wheel_scroll, @intFromBool(list.item_count == null), @intFromBool(list.scroll.has_more), scrolling.cursor, scrolling.last_height, @intFromBool(scrolling.draw_cursor), scrolling.wheel_scroll, @intFromBool(scrolling.item_count == null), @intFromBool(scrolling.scroll.has_more_vertical), @intFromBool(scrolling.scroll.has_more_horizontal), @intFromBool(bars.draw_vertical_scrollbar), @intFromBool(bars.draw_horizontal_scrollbar), @intFromBool(bars.estimated_content_height == null), @intFromBool(bars.estimated_content_width == null), split.width, split.min_width, @intFromBool(split.max_width == null), @intFromEnum(split.constrain), @intFromBool(split.last_max_width == null), @intFromBool(split.pressed), @intFromBool(split.mouse_set), spinner.frame, spinner.count.load(.unordered), @intFromBool(spinner.was_spinning.load(.unordered)), @intFromBool(list_builder.userdata == scroll_builder.userdata) });
    try writer.interface.flush();
}
