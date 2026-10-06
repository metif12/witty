const std = @import("std");
const vaxis = @import("vaxis");
const fw = vaxis.vxfw;
const Writer = std.Io.Writer;

fn specs(index: u8) []const fw.Size {
    return switch (index) {
        0 => &.{},
        1 => &.{.{ .width = 1, .height = 1 }},
        2 => &.{ .{ .width = 5, .height = 3 }, .{ .width = 3, .height = 1 }, .{ .width = 7, .height = 1 }, .{ .width = 4, .height = 2 } },
        3 => &.{ .{ .width = 0, .height = 0 }, .{ .width = 2, .height = 0 }, .{ .width = 5, .height = 0 } },
        4 => &.{ .{ .width = 1, .height = 5 }, .{ .width = 3, .height = 2 }, .{ .width = 10, .height = 7 }, .{ .width = 20, .height = 1 }, .{ .width = 4, .height = 3 } },
        5 => &.{ .{ .width = 0, .height = 255 }, .{ .width = 0, .height = 256 }, .{ .width = 0, .height = 1000 } },
        6 => &.{.{ .width = 65535, .height = 65535 }},
        7 => &.{ .{ .width = 0, .height = 65535 }, .{ .width = 0, .height = 65535 } },
        8 => &.{ .{ .width = 1, .height = 1 }, .{ .width = 1, .height = 1 }, .{ .width = 1, .height = 1 } },
        else => unreachable,
    };
}

const Child = struct {
    spy: *Spy,
    index: usize,
    size: fw.Size,
    fn widget(self: *Child) fw.Widget {
        return .{ .userdata = self, .drawFn = draw };
    }
    fn draw(ptr: *anyopaque, ctx: fw.DrawContext) std.mem.Allocator.Error!fw.Surface {
        const self: *Child = @ptrCast(@alignCast(ptr));
        const spy = self.spy;
        spy.log('D', self.index, 0, ctx);
        const first = spy.draw_calls == 0;
        spy.draw_calls += 1;
        if (first) switch (spy.draw_mode) {
            1 => return error.OutOfMemory,
            2 => {
                spy.view.scroll.pending_lines = -2;
                spy.view.scroll.left = 1;
                spy.view.scroll.vertical_offset = 2;
            },
            3 => {
                spy.view.scroll.top = 0;
                spy.view.scroll.wants_cursor = false;
            },
            4 => {
                spy.view.scroll.left = 65536;
                return error.OutOfMemory;
            },
            5 => {
                if (self.index + 1 < spy.children.len) spy.children[self.index + 1].size.height = 4;
            },
            else => {},
        };
        return .{ .size = self.size, .widget = self.widget(), .buffer = &.{}, .children = &.{} };
    }
};

const Spy = struct {
    alloc: std.mem.Allocator,
    view: *fw.ScrollView = undefined,
    children: []Child = &.{},
    widgets: []fw.Widget = &.{},
    build_mode: u8,
    draw_mode: u8,
    build_calls: usize = 0,
    draw_calls: usize = 0,
    base: usize = 0,
    trace: std.ArrayList(u8) = .empty,
    fn init(self: *Spy, dataset: u8) !void {
        const sizes = specs(dataset);
        self.children = try self.alloc.alloc(Child, sizes.len);
        self.widgets = try self.alloc.alloc(fw.Widget, sizes.len);
        for (sizes, 0..) |size, index| {
            self.children[index] = .{ .spy = self, .index = index, .size = size };
            self.widgets[index] = self.children[index].widget();
        }
    }
    fn log(self: *Spy, kind: u8, index: usize, cursor: usize, ctx: ?fw.DrawContext) void {
        if (self.build_calls + self.draw_calls > 128) return;
        const v = self.view;
        const text = std.fmt.allocPrint(self.alloc, "{c}{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d};", .{
            kind,                                index,                                    cursor,                                     v.cursor,                                    v.scroll.top,                                                  v.scroll.vertical_offset,                                       v.scroll.pending_lines, v.scroll.left,
            @intFromBool(v.scroll.wants_cursor), @intFromBool(v.scroll.has_more_vertical), if (ctx) |c| @as(i32, c.min.width) else -1, if (ctx) |c| @as(i32, c.min.height) else -1, if (ctx) |c| if (c.max.width) |n| @as(i32, n) else -1 else -1, if (ctx) |c| if (c.max.height) |n| @as(i32, n) else -1 else -1,
        }) catch @panic("fixture allocation");
        self.trace.appendSlice(self.alloc, text) catch @panic("fixture allocation");
    }
    fn build(ptr: *const anyopaque, index: usize, cursor: usize) ?fw.Widget {
        const self: *Spy = @ptrCast(@alignCast(@constCast(ptr)));
        self.log('B', index, cursor, null);
        const first = self.build_calls == 0;
        self.build_calls += 1;
        if (first) switch (self.build_mode) {
            2 => {
                self.view.scroll.pending_lines = 2;
                self.view.scroll.left = 1;
            },
            3 => {
                self.view.cursor = 0;
                self.view.scroll.wants_cursor = false;
            },
            5 => self.view.children = .{ .slice = &.{} },
            else => {},
        };
        const relative = if (self.build_mode == 6) index - self.base else index;
        if (relative >= self.widgets.len) {
            if (self.build_mode == 4) {
                self.view.scroll.pending_lines = 1;
                self.view.scroll.left = 65536;
            }
            return null;
        }
        if (self.build_mode == 1 and relative % 2 != 0) return null;
        return self.widgets[relative];
    }
};

fn state(out: *Writer, view: fw.ScrollView) !void {
    try out.print("{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d};", .{
        view.cursor,                                     view.last_height,                              view.scroll.top,                        view.scroll.vertical_offset,                  view.scroll.pending_lines,      view.scroll.left,
        @intFromBool(view.scroll.has_more_vertical),     @intFromBool(view.scroll.has_more_horizontal), @intFromBool(view.scroll.wants_cursor), if (view.item_count) |n| @as(i64, n) else -1, @intFromBool(view.draw_cursor), view.wheel_scroll,
        @intFromEnum(std.meta.activeTag(view.children)),
    });
}
fn surfaceValue(out: *Writer, surface: fw.Surface, view: *fw.ScrollView) !void {
    const index: usize = if (surface.widget.userdata == @as(*anyopaque, @ptrCast(view))) 0 else blk: {
        const child: *Child = @ptrCast(@alignCast(surface.widget.userdata));
        break :blk child.index + 1;
    };
    try out.print("[{d},{d},{d},{d},{d};", .{ surface.size.width, surface.size.height, index, surface.buffer.len, surface.children.len });
    for (surface.buffer) |cell| {
        for (cell.char.grapheme) |byte| try out.print("{x:0>2}", .{byte});
        const fg: u16 = switch (cell.style.fg) {
            .index => |n| @as(u16, n) + 1,
            else => 0,
        };
        try out.print("/{d},{d},{d},{d};", .{ cell.char.width, @intFromBool(cell.default), fg, @intFromBool(cell.style.bold) });
    }
    for (surface.children) |sub| {
        try out.print("({d},{d},{d})", .{ sub.origin.col, sub.origin.row, sub.z_index });
        try surfaceValue(out, sub.surface, view);
    }
    try out.writeByte(']');
}
fn num(p: []const []const u8, index: usize) !i64 {
    return std.fmt.parseInt(i64, p[index], 10);
}
fn keyEvent(code: u8) fw.Event {
    const cp: u21 = switch (code) {
        0, 20 => vaxis.Key.down,
        1 => vaxis.Key.up,
        2 => vaxis.Key.right,
        3 => vaxis.Key.left,
        4 => 'd',
        5 => 'u',
        6 => vaxis.Key.escape,
        7 => 'j',
        8 => 'k',
        9 => 'n',
        10 => 'p',
        11 => 'l',
        12 => 'h',
        13 => 'f',
        14 => 'b',
        else => 'q',
    };
    const key: vaxis.Key = .{ .codepoint = cp, .mods = .{ .ctrl = code == 4 or code == 5 or code == 9 or code == 10 or code == 13 or code == 14 } };
    if (code == 20) return .{ .key_release = key };
    if (code >= 21 and code <= 24) return .{ .mouse = .{ .col = 0, .row = 0, .button = switch (code) {
        21 => .wheel_up,
        22 => .wheel_down,
        23 => .wheel_left,
        else => .wheel_right,
    }, .mods = .{}, .type = .release } };
    if (code == 25) return .focus_in;
    if (code == 26) return .tick;
    if (code == 27) return .{ .paste = "j" };
    return .{ .key_press = key };
}

fn record(out: *Writer, p: []const []const u8, a: std.mem.Allocator) !void {
    var spy: Spy = .{ .alloc = a, .build_mode = @intCast(try num(p, 16)), .draw_mode = @intCast(try num(p, 17)) };
    try spy.init(@intCast(try num(p, 3)));
    var view: fw.ScrollView = .{ .children = if (try num(p, 2) == 0) .{ .slice = spy.widgets } else .{ .builder = .{ .userdata = &spy, .buildFn = Spy.build } }, .cursor = @intCast(try num(p, 4)), .scroll = .{ .top = @intCast(try num(p, 5)), .vertical_offset = @intCast(try num(p, 6)), .pending_lines = @intCast(try num(p, 7)), .left = @intCast(try num(p, 8)), .has_more_vertical = try num(p, 9) != 0, .has_more_horizontal = try num(p, 10) != 0, .wants_cursor = try num(p, 11) != 0 }, .item_count = if (try num(p, 12) < 0) null else @intCast(try num(p, 12)), .draw_cursor = try num(p, 13) != 0, .wheel_scroll = @intCast(try num(p, 14)), .last_height = @intCast(try num(p, 15)), .cursor_indicator = .{ .char = .{ .grapheme = "*", .width = 1 }, .style = .{ .fg = .{ .index = 3 }, .bold = true } } };
    spy.view = &view;
    spy.base = view.scroll.top;
    const flags = try num(p, 18);
    var events: fw.EventContext = .{ .alloc = a, .cmds = .empty, .consume_event = flags & 1 != 0, .redraw = flags & 2 != 0, .quit = flags & 4 != 0 };
    var surface: ?fw.Surface = null;
    var status: []const u8 = "ok";
    const action = try num(p, 1);
    const ctx: fw.DrawContext = .{ .arena = a, .min = .{}, .max = .{ .width = if (try num(p, 19) < 0) null else @intCast(try num(p, 19)), .height = if (try num(p, 20) < 0) null else @intCast(try num(p, 20)) }, .cell_size = .{ .width = 10, .height = 20 } };
    if (std.mem.eql(u8, p[0], "S")) {
        const amount: u8 = @intCast(try num(p, 19));
        const result = switch (action) {
            0 => view.scroll.linesDown(amount),
            1 => view.scroll.linesUp(amount),
            2 => view.scroll.colsLeft(amount),
            3 => view.scroll.colsRight(amount),
            else => unreachable,
        };
        status = if (result) "true" else "false";
    } else if (std.mem.eql(u8, p[0], "N")) {
        switch (action) {
            0 => view.nextItem(&events),
            1 => view.prevItem(&events),
            2 => view.ensureScroll(),
            3 => {
                const builder: fw.ScrollView.Builder = .{ .userdata = &spy, .buildFn = Spy.build };
                status = if (builder.itemAtIdx(view.cursor, view.cursor) != null) "true" else "false";
            },
            else => unreachable,
        }
    } else if (std.mem.eql(u8, p[0], "E")) {
        try view.widget().handleEvent(&events, keyEvent(@intCast(action)));
    } else {
        surface = view.widget().draw(ctx) catch |err| blk: {
            status = @errorName(err);
            break :blk null;
        };
        if (std.mem.eql(u8, p[0], "T") and std.mem.eql(u8, status, "ok")) {
            switch (action) {
                0 => view.nextItem(&events),
                1 => view.prevItem(&events),
                2 => try view.widget().handleEvent(&events, keyEvent(0)),
                3 => view.ensureScroll(),
                4 => try view.widget().handleEvent(&events, keyEvent(22)),
                5 => try view.widget().handleEvent(&events, keyEvent(2)),
                6 => try view.widget().handleEvent(&events, keyEvent(4)),
                7 => try view.widget().handleEvent(&events, keyEvent(6)),
                else => unreachable,
            }
            surface = view.widget().draw(ctx) catch |err| blk: {
                status = @errorName(err);
                break :blk null;
            };
        }
    }
    try out.print("{s}|", .{status});
    try state(out, view);
    try out.print("{d},{d},{d},{d},{d},{d}|{s}|", .{ @intFromBool(events.consume_event), @intFromBool(events.redraw), @intFromBool(events.quit), events.cmds.items.len, spy.build_calls, spy.draw_calls, spy.trace.items });
    if (surface) |s| try surfaceValue(out, s, &view);
    try out.writeByte('\n');
}

pub fn main() !void {
    const a = std.heap.page_allocator;
    const args = try std.process.argsAlloc(a);
    const data = try std.fs.cwd().readFileAlloc(a, args[1], 32 * 1024 * 1024);
    var buffer: [65536]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&buffer);
    const out = &stdout.interface;
    var lines = std.mem.splitScalar(u8, data, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var arena = std.heap.ArenaAllocator.init(a);
        defer arena.deinit();
        var fields = std.mem.splitScalar(u8, line, '|');
        var values: [24][]const u8 = undefined;
        var length: usize = 0;
        while (fields.next()) |field| {
            values[length] = field;
            length += 1;
        }
        try record(out, values[0..length], arena.allocator());
    }
    try out.flush();
}
