const std = @import("std");
const vaxis = @import("vaxis");
const fw = vaxis.vxfw;
const List = fw.ListView;
const W = std.Io.Writer;
const A = std.heap.c_allocator;
const Item = struct { owner: *Fixture, index: usize, height: u16 };
const Fixture = struct {
    items: []Item, view: *List = undefined, holes: u64 = 0, width: ?u16 = null,
    fail: i64 = -1, mutation: u8 = 0, silent: bool = false,
    trace: std.ArrayList([]const u8) = .empty,
    fn log(self: *Fixture, comptime fmt: []const u8, args: anytype) void {
        if (self.silent) return;
        self.trace.append(A, std.fmt.allocPrint(A, fmt, args) catch @panic("trace allocation")) catch @panic("trace allocation");
    }
};
fn build(ptr: *const anyopaque, index: usize, cursor: usize) ?fw.Widget {
    const f: *Fixture = @ptrCast(@alignCast(@constCast(ptr)));
    f.log("b{d},{d};", .{ index, cursor });
    if (index >= f.items.len or index < 64 and f.holes & (@as(u64, 1) << @intCast(index)) != 0) return null;
    return itemWidget(&f.items[index]);
}
fn itemWidget(item: *Item) fw.Widget { return .{ .userdata = item, .drawFn = drawItem }; }
fn drawItem(ptr: *anyopaque, ctx: fw.DrawContext) std.mem.Allocator.Error!fw.Surface {
    const item: *Item = @ptrCast(@alignCast(ptr)); const f = item.owner;
    f.log("d{d},{d},{d},{d};", .{ item.index, ctx.min.width, ctx.max.width orelse 65535, ctx.max.height orelse 65535 });
    if (item.index == 0) switch (f.mutation) {
        1 => f.view.scroll.pending_lines = 7,
        2 => { f.view.cursor = 0; f.view.scroll.wants_cursor = true; },
        3 => f.view.scroll.top = std.math.maxInt(u32),
        else => {},
    };
    if (f.fail == item.index) return error.OutOfMemory;
    return .{ .size = .{ .width = f.width orelse ctx.min.width, .height = item.height }, .widget = itemWidget(item), .buffer = &.{}, .children = &.{},
        .cursor = if (item.index % 2 == 0) .{ .col = 0, .row = 0, .shape = .beam } else null };
}
fn uint(parts: []const []const u8, index: usize) !u64 { return std.fmt.parseInt(u64, parts[index], 10); }
fn sint(parts: []const []const u8, index: usize) !i64 { return std.fmt.parseInt(i64, parts[index], 10); }
fn state(out: *W, value: List, ctx: fw.EventContext, fixture: Fixture) !void {
    try out.print("{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}|", .{ value.cursor, value.item_count orelse std.math.maxInt(u32), value.scroll.top, value.scroll.offset, value.scroll.pending_lines, @intFromBool(value.scroll.has_more), @intFromBool(value.scroll.wants_cursor), @intFromBool(ctx.consume_event), @intFromBool(ctx.redraw), ctx.cmds.items.len });
    for (fixture.trace.items) |text| try out.writeAll(text);
}
fn surface(out: *W, value: fw.Surface, list: *List) !void {
    const id: usize = if (@intFromPtr(value.widget.userdata) == @intFromPtr(list)) 999 else @as(*Item, @ptrCast(@alignCast(value.widget.userdata))).index;
    var defaults: usize = 0; var indicators: usize = 0;
    for (value.buffer) |cell| { if (cell.default) defaults += 1; if (std.mem.eql(u8, cell.char.grapheme, "▐")) indicators += 1; }
    try out.print("[{d},{d},{d},{d},{d},{d},", .{ value.size.width, value.size.height, id, value.buffer.len, defaults, indicators });
    if (value.cursor) |cursor| try out.print("{d},{d},{d}", .{ cursor.col, cursor.row, @intFromEnum(cursor.shape) }) else try out.writeAll("none");
    try out.writeByte('|');
    for (value.children) |child| { try out.print("{d},{d},{d}", .{ child.origin.col, child.origin.row, child.z_index }); try surface(out, child.surface, list); }
    try out.writeByte(']');
}
fn event(action: u64) fw.Event {
    return switch (action) {
        3, 4 => .{ .mouse = .{ .col = 0, .row = 0, .button = if (action == 3) .wheel_up else .wheel_down, .mods = .{}, .type = .press } },
        5 => .{ .key_press = .{ .codepoint = 'j' } }, 6 => .{ .key_press = .{ .codepoint = 'k' } },
        7 => .{ .key_press = .{ .codepoint = vaxis.Key.escape } },
        8 => .{ .key_press = .{ .codepoint = 'n', .mods = .{ .ctrl = true } } },
        9 => .{ .key_press = .{ .codepoint = 'p', .mods = .{ .ctrl = true } } },
        10 => .{ .key_press = .{ .codepoint = vaxis.Key.down } }, 11 => .{ .key_press = .{ .codepoint = vaxis.Key.up } },
        12 => .{ .key_press = .{ .codepoint = 'j', .mods = .{ .shift = true } } },
        else => .init,
    };
}
fn record(out: *W, line: []const u8, number: usize) !void {
    var split = std.mem.splitScalar(u8, line, '|'); var parts: [24][]const u8 = undefined; var n: usize = 0;
    while (split.next()) |field| { parts[n] = field; n += 1; } const p = parts[0..n];
    var heights = std.mem.splitScalar(u8, p[2], ','); var items: std.ArrayList(Item) = .empty;
    while (heights.next()) |text| { if (text.len == 0) continue; try items.append(A, .{ .owner = undefined, .index = items.items.len, .height = try std.fmt.parseInt(u16, text, 10) }); }
    var fixture: Fixture = .{ .items = items.items, .holes = try uint(p, 4), .width = if (try sint(p, 3) < 0) null else @intCast(try uint(p, 3)), .fail = try sint(p, 17), .mutation = @intCast(try uint(p, 18)) };
    for (fixture.items) |*item| item.owner = &fixture;
    const builder: List.Builder = .{ .userdata = &fixture, .buildFn = build };
    const widgets = try A.alloc(fw.Widget, fixture.items.len); for (fixture.items, 0..) |*item, i| widgets[i] = itemWidget(item);
    var list: List = .{ .children = if (try uint(p, 1) == 0) .{ .slice = widgets } else .{ .builder = builder },
        .cursor = @intCast(try uint(p, 5)), .item_count = if (try sint(p, 6) < 0) null else @intCast(try uint(p, 6)),
        .scroll = .{ .top = @intCast(try uint(p, 7)), .offset = @intCast(try sint(p, 8)), .pending_lines = @intCast(try sint(p, 9)), .has_more = try uint(p, 10) != 0, .wants_cursor = try uint(p, 11) != 0 },
        .draw_cursor = try uint(p, 12) != 0, .wheel_scroll = @intCast(try uint(p, 13)) };
    fixture.view = &list;
    var ctx: fw.EventContext = .{ .alloc = A, .cmds = .empty, .redraw = false };
    const action = try uint(p, 14); try out.print("{d}|", .{number});
    if (std.mem.eql(u8, p[0], "E")) {
        switch (action) { 0 => list.nextItem(&ctx), 1 => list.prevItem(&ctx), 2 => list.ensureScroll(), else => if (action % 2 == 0) try list.widget().handleEvent(&ctx, event(action)) else try list.handleEvent(&ctx, event(action)) }
    } else {
        const draw_ctx: fw.DrawContext = .{ .arena = A, .min = .{}, .max = .{ .width = if (try sint(p, 15) < 0) null else @intCast(try uint(p, 15)), .height = if (try sint(p, 16) < 0) null else @intCast(try uint(p, 16)) }, .cell_size = .{} };
        const result = if (action == 0) list.draw(draw_ctx) else list.widget().draw(draw_ctx);
        if (result) |value| { try surface(out, value, &list); try out.writeByte('|'); } else |err| try out.print("error:{s}|", .{@errorName(err)});
    }
    try state(out, list, ctx, fixture); try out.writeByte('\n');
}
pub fn main() !void {
    const args = try std.process.argsAlloc(A); var buffer: [65536]u8 = undefined; var stdout = std.fs.File.stdout().writer(&buffer); const out = &stdout.interface;
    if (std.mem.startsWith(u8, args[1], "hang_")) {
        var f: Fixture = .{ .items = &.{}, .silent = true };
        var list: List = .{ .children = .{ .builder = .{ .userdata = &f, .buildFn = build } }, .cursor = if (std.mem.eql(u8, args[1], "hang_prev")) 1 else 0 }; f.view = &list;
        var ctx: fw.EventContext = .{ .alloc = A, .cmds = .empty }; if (list.cursor == 1) list.prevItem(&ctx) else list.nextItem(&ctx); try out.writeAll("UNEXPECTED\n");
    } else {
        const data = try std.fs.cwd().readFileAlloc(A, args[1], 16 * 1024 * 1024); var lines = std.mem.splitScalar(u8, data, '\n'); var number: usize = 0;
        while (lines.next()) |line| { if (line.len == 0) continue; try record(out, line, number); try out.flush(); number += 1; }
    }
    try out.flush();
}
