const std = @import("std");
const vaxis = @import("vaxis");
const fw = vaxis.vxfw;
const a = std.heap.page_allocator;
const Writer = std.Io.Writer;

fn draw(ptr: *anyopaque, _: fw.DrawContext) std.mem.Allocator.Error!fw.Surface {
    return fw.Surface.empty(widget(@intFromPtr(ptr) - 1));
}
fn event(_: *anyopaque, _: *fw.EventContext, _: fw.Event) anyerror!void {}
fn widget(index: usize) fw.Widget {
    return .{ .userdata = @ptrFromInt(index + 1), .drawFn = draw,
        .eventHandler = if (index & 1 != 0) event else null,
        .captureHandler = if (index & 2 != 0) event else null };
}
fn id(value: fw.Widget) usize { return @intFromPtr(value.userdata) - 1; }
fn cell(index: usize) vaxis.Cell {
    const glyphs = [_][]const u8{ "r", "a", "界", "é" };
    return .{ .char = .{ .grapheme = glyphs[index % 4], .width = if (index % 4 == 2) 2 else 1 },
        .style = .{ .fg = .{ .index = @intCast(index % 256) }, .bold = index % 2 != 0 },
        .wrapped = index % 3 == 0 };
}
fn cellValue(out: *Writer, value: vaxis.Cell) !void {
    for (value.char.grapheme) |byte| try out.print("{x:0>2}", .{byte});
    const color: u32 = switch (value.style.fg) { .default => 0, .index => |n| 0x1000000 + @as(u32, n), .rgb => |rgb| 0x2000000 + (@as(u32, rgb[0]) << 16) + (@as(u32, rgb[1]) << 8) + rgb[2] };
    try out.print("/{d},{d},{d},{d},{d};", .{ value.char.width, @intFromBool(value.default), @intFromBool(value.wrapped), color, @intFromBool(value.style.bold) });
}
fn hit(out: *Writer, surface: fw.Surface, point: fw.Point) !void {
    var values: std.ArrayList(fw.HitResult) = .empty;
    defer values.deinit(a);
    try surface.hitTest(a, &values, point);
    for (values.items) |value| try out.print("{d},{d},{d};", .{ id(value.widget), value.local.col, value.local.row });
}
fn root(screen: *vaxis.Screen) vaxis.Window {
    return .{ .x_off = 0, .y_off = 0, .parent_x_off = 0, .parent_y_off = 0, .width = screen.width, .height = screen.height, .screen = screen };
}
fn num(parts: []const []const u8, i: usize) !i32 { return std.fmt.parseInt(i32, parts[i], 10); }
fn unsigned(parts: []const []const u8, i: usize) !u16 { return @intCast(try num(parts, i)); }
fn optional(parts: []const []const u8, i: usize) !?u16 { const value = try num(parts, i); return if (value < 0) null else @intCast(value); }
fn metadata(out: *Writer, win: vaxis.Window, screen: *vaxis.Screen) !void {
    try out.print("{d},{d},{d},{d},{d},{d},{d}", .{ win.width, win.height, win.x_off, win.y_off, win.parent_x_off, win.parent_y_off, @intFromBool(win.screen == screen) });
}

fn trap(mode: []const u8) !void {
    var screen: vaxis.Screen = .{};
    var win = root(&screen);
    var one = [_]vaxis.Cell{.{}};
    var surface: fw.Surface = .{ .size = .{ .width = 1, .height = 1 }, .widget = widget(0), .buffer = &one, .children = &.{} };
    if (std.mem.eql(u8, mode, "trap_create")) {
        _ = try fw.Surface.createBuffer(a, .{ .width = 256, .height = 256 });
    } else if (std.mem.eql(u8, mode, "trap_write_mul")) {
        surface.size = .{ .width = 2, .height = 32769 }; surface.writeCell(0, 32768, .{});
    } else if (std.mem.eql(u8, mode, "trap_write_add")) {
        surface.size = .{ .width = 255, .height = 258 }; surface.writeCell(1, 257, .{});
    } else if (std.mem.eql(u8, mode, "trap_write_short")) {
        surface.size.width = 2; surface.writeCell(1, 0, .{});
    } else if (std.mem.eql(u8, mode, "trap_read_col")) {
        _ = surface.readCell(1, 0);
    } else if (std.mem.eql(u8, mode, "trap_read_row")) {
        _ = surface.readCell(0, 1);
    } else if (std.mem.eql(u8, mode, "trap_read_short")) {
        surface.buffer = &.{}; _ = surface.readCell(0, 0);
    } else if (std.mem.eql(u8, mode, "trap_trim_height")) {
        _ = surface.trimHeight(2);
    } else if (std.mem.eql(u8, mode, "trap_trim_mul")) {
        surface.size = .{ .width = 256, .height = 256 }; _ = surface.trimHeight(256);
    } else if (std.mem.eql(u8, mode, "trap_trim_short")) {
        surface.size.width = 2; _ = surface.trimHeight(1);
    } else if (std.mem.eql(u8, mode, "trap_hit")) {
        var list: std.ArrayList(fw.HitResult) = .empty; try surface.hitTest(a, &list, .{ .col = 1, .row = 0 });
    } else if (std.mem.eql(u8, mode, "trap_render_mul")) {
        surface.size = .{ .width = 256, .height = 256 }; surface.render(win, widget(0));
    } else if (std.mem.eql(u8, mode, "trap_render_short")) {
        surface.size.width = 2; surface.render(win, widget(0));
    } else if (std.mem.eql(u8, mode, "trap_contains_col") or std.mem.eql(u8, mode, "trap_contains_row")) {
        const col = std.mem.endsWith(u8, mode, "col");
        const sub: fw.SubSurface = .{ .origin = .{ .col = if (col) 65535 else 0, .row = if (col) 0 else 65535 }, .surface = surface };
        _ = sub.containsPoint(.{ .col = if (col) 65535 else 0, .row = if (col) 0 else 65535 });
    } else if (std.mem.startsWith(u8, mode, "trap_child_")) {
        var x: i17 = 0; var y: i17 = 0;
        win.width = 1; win.height = 1;
        if (std.mem.endsWith(u8, mode, "max_x")) x = -65536 else if (std.mem.endsWith(u8, mode, "max_y")) y = -65536
        else if (std.mem.endsWith(u8, mode, "abs_x")) { win.x_off = 65535; x = 1; }
        else if (std.mem.endsWith(u8, mode, "abs_y")) { win.y_off = 65535; y = 1; }
        else if (std.mem.endsWith(u8, mode, "parent_x")) { win.parent_x_off = 65535; x = 1; }
        else if (std.mem.endsWith(u8, mode, "parent_y")) { win.parent_y_off = 65535; y = 1; }
        else if (std.mem.endsWith(u8, mode, "negative_parent")) { win.parent_x_off = -65536; x = -1; }
        else return error.InvalidTrap;
        _ = win.child(.{ .x_off = x, .y_off = y, .width = 0, .height = 0 });
    } else if (std.mem.eql(u8, mode, "trap_cursor_x") or std.mem.eql(u8, mode, "trap_cursor_y")) {
        if (std.mem.endsWith(u8, mode, "x")) win.x_off = 65535 else win.y_off = 65535;
        win.showCursor(1, 1);
    } else if (std.mem.startsWith(u8, mode, "trap_window_")) {
        win.width = 2; win.height = 2;
        if (std.mem.endsWith(u8, mode, "parent")) win.parent_x_off = 65535 else win.x_off = 65535;
        if (std.mem.indexOf(u8, mode, "write") != null) win.writeCell(1, 0, .{}) else _ = win.readCell(1, 0);
    } else return error.InvalidTrap;
    var bytes: [64]u8 = undefined; var stdout = std.fs.File.stdout().writer(&bytes);
    try stdout.interface.writeAll("UNEXPECTED\n"); try stdout.interface.flush();
}

pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    if (std.mem.startsWith(u8, args[1], "trap_")) return trap(args[1]);
    const data = try std.fs.cwd().readFileAlloc(a, args[1], 16 * 1024 * 1024);
    var out_buffer: [65536]u8 = undefined; var stdout = std.fs.File.stdout().writer(&out_buffer); const out = &stdout.interface;
    var lines = std.mem.splitScalar(u8, data, '\n'); var number: usize = 0;
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var fields = std.mem.splitScalar(u8, line, '|'); var parts: [16][]const u8 = undefined; var length: usize = 0;
        while (fields.next()) |field| { parts[length] = field; length += 1; }
        const p = parts[0..length]; try out.print("{d}|", .{number}); number += 1;
        if (std.mem.eql(u8, p[0], "S")) {
            const sub: fw.SubSurface = .{ .origin = .{ .col = @intCast(try num(p, 1)), .row = @intCast(try num(p, 2)) }, .surface = .{ .size = .{ .width = try unsigned(p, 3), .height = try unsigned(p, 4) }, .widget = widget(0), .buffer = &.{}, .children = &.{} } };
            try out.print("{d}", .{@intFromBool(sub.containsPoint(.{ .col = try unsigned(p, 5), .row = try unsigned(p, 6) }))});
        } else if (std.mem.eql(u8, p[0], "W")) {
            var screen: vaxis.Screen = .{};
            const win: vaxis.Window = .{ .width = try unsigned(p, 1), .height = try unsigned(p, 2), .x_off = @intCast(try num(p, 3)), .y_off = @intCast(try num(p, 4)), .parent_x_off = @intCast(try num(p, 5)), .parent_y_off = @intCast(try num(p, 6)), .screen = &screen };
            try metadata(out, win.child(.{ .x_off = @intCast(try num(p, 7)), .y_off = @intCast(try num(p, 8)), .width = try optional(p, 9), .height = try optional(p, 10) }), &screen);
        } else if (std.mem.eql(u8, p[0], "N")) {
            const size: fw.Size = .{ .width = try unsigned(p, 1), .height = try unsigned(p, 2) };
            const buffer = try fw.Surface.createBuffer(a, size); defer a.free(buffer);
            const surface = try fw.Surface.init(a, widget(1), size); defer a.free(surface.buffer);
            var children = [_]fw.SubSurface{.{ .origin = .{ .col = 0, .row = 0 }, .surface = fw.Surface.empty(widget(2)) }};
            const with = try fw.Surface.initWithChildren(a, widget(1), size, &children); defer a.free(with.buffer);
            const empty = fw.Surface.empty(widget(3));
            var defaults: usize = 0; for (buffer) |value| { if (value.default) defaults += 1; }
            try out.print("{d},{d},{d},{d},{d},{d},{d},{d}|", .{ buffer.len, surface.buffer.len, with.buffer.len, defaults, empty.size.width, empty.size.height, empty.buffer.len, @intFromBool(with.children.ptr == &children) });
            if (buffer.len > 0) { try cellValue(out, buffer[0]); try cellValue(out, buffer[buffer.len - 1]); }
        } else if (std.mem.eql(u8, p[0], "O")) {
            var children = [_]fw.SubSurface{.{ .origin = .{ .col = 0, .row = 0 }, .surface = fw.Surface.empty(widget(2)) }};
            var surface = try fw.Surface.initWithChildren(a, widget(1), .{ .width = try unsigned(p, 1), .height = try unsigned(p, 2) }, &children); defer a.free(surface.buffer);
            surface.cursor = .{ .row = 0, .col = 1, .shape = .beam };
            surface.writeCell(try unsigned(p, 3), try unsigned(p, 4), cell(2));
            try cellValue(out, surface.readCell(try unsigned(p, 5), try unsigned(p, 6)));
            const trimmed = surface.trimHeight(try unsigned(p, 7));
            try out.print("|{d},{d},{d},{d},{d},{d}|", .{ trimmed.size.height, trimmed.buffer.len, @intFromBool(trimmed.cursor == null), @intFromBool(trimmed.buffer.ptr == surface.buffer.ptr), @intFromBool(trimmed.children.ptr == surface.children.ptr), @intFromBool(trimmed.widget.eql(surface.widget)) });
            if (trimmed.buffer.len > 0) trimmed.writeCell(0, 0, cell(3));
            for (surface.buffer) |value| try cellValue(out, value);
            try out.print("|{d},{d}", .{ @intFromBool(surface.satisfiesConstraints(.{}, .{ .width = surface.size.width + 1, .height = surface.size.height + 1 })), @intFromBool(surface.satisfiesConstraints(surface.size, surface.size)) });
        } else if (std.mem.eql(u8, p[0], "T")) {
            const size: fw.Size = .{ .width = try unsigned(p, 1), .height = try unsigned(p, 2) };
            var c1 = try fw.Surface.init(a, widget(1), .{ .width = 2, .height = 2 }); defer a.free(c1.buffer); @memset(c1.buffer, cell(1)); c1.cursor = .{ .col = 1, .row = 1, .shape = .beam };
            var c2 = try fw.Surface.init(a, widget(2), .{ .width = 2, .height = 2 }); defer a.free(c2.buffer); @memset(c2.buffer, cell(2)); c2.cursor = .{ .col = 0, .row = 0, .shape = .underline };
            const c3 = try fw.Surface.init(a, widget(3), .{ .width = 1, .height = 1 }); defer a.free(c3.buffer); @memset(c3.buffer, cell(3));
            var children = [_]fw.SubSurface{
                .{ .origin = .{ .col = @intCast(try num(p, 3)), .row = @intCast(try num(p, 4)) }, .surface = c1, .z_index = @intCast(try num(p, 5)) },
                .{ .origin = .{ .col = @intCast(try num(p, 6)), .row = @intCast(try num(p, 7)) }, .surface = c2, .z_index = @intCast(try num(p, 8)) },
                .{ .origin = .{ .col = 0, .row = 0 }, .surface = c3, .z_index = @intCast(try num(p, 8)) },
            };
            var surface = try fw.Surface.initWithChildren(a, widget(0), size, &children); defer a.free(surface.buffer); @memset(surface.buffer, cell(0)); surface.cursor = .{ .col = 0, .row = 0, .shape = .block };
            var screen = try vaxis.Screen.init(a, .{ .cols = size.width, .rows = size.height, .x_pixel = 0, .y_pixel = 0 }); defer screen.deinit(a);
            const point: fw.Point = .{ .col = try unsigned(p, 10), .row = try unsigned(p, 11) };
            try hit(out, surface, point); try out.writeByte('|'); surface.render(root(&screen), widget(@intCast(try num(p, 9))));
            for (screen.buf) |value| try cellValue(out, value);
            try out.print("|{d},{d},{d},{d}|", .{ @intFromBool(screen.cursor_vis), screen.cursor_col, screen.cursor_row, @intFromEnum(screen.cursor_shape) });
            for (children) |child| try out.print("{d};", .{id(child.surface.widget)});
            try out.writeByte('|'); try hit(out, surface, point);
        } else if (std.mem.eql(u8, p[0], "C")) {
            var screen = try vaxis.Screen.init(a, .{ .cols = 4, .rows = 3, .x_pixel = 0, .y_pixel = 0 }); defer screen.deinit(a);
            const win: vaxis.Window = .{ .width = try unsigned(p, 1), .height = try unsigned(p, 2), .x_off = @intCast(try num(p, 3)), .y_off = @intCast(try num(p, 4)), .parent_x_off = @intCast(try num(p, 5)), .parent_y_off = @intCast(try num(p, 6)), .screen = &screen };
            const col = try unsigned(p, 7); const row = try unsigned(p, 8);
            win.writeCell(col, row, cell(2)); if (win.readCell(col, row)) |value| try cellValue(out, value) else try out.writeAll("none;");
            win.showCursor(col, row); win.setCursorShape(.beam);
            try out.print("|{d},{d},{d},{d}|", .{ @intFromBool(screen.cursor_vis), screen.cursor_col, screen.cursor_row, @intFromEnum(screen.cursor_shape) });
            for (screen.buf) |value| try cellValue(out, value);
        } else return error.InvalidMode;
        try out.writeByte('\n');
    }
    try out.flush();
}
