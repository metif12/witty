const std = @import("std");
const vaxis = @import("vaxis");
const ScrollView = vaxis.widgets.ScrollView;
const Writer = std.Io.Writer;
const glyphs = [_][]const u8{ "▐", "░", "X", "界", "" };
const codes = [_]u21{ vaxis.Key.right, vaxis.Key.left, vaxis.Key.up, vaxis.Key.down, vaxis.Key.page_up, vaxis.Key.page_down, vaxis.Key.end, vaxis.Key.home, 'a' };
fn uint(parts: []const []const u8, index: usize) !usize {
    return std.fmt.parseInt(usize, parts[index], 10);
}
fn style(index: usize) vaxis.Style {
    return switch (index) {
        1 => .{ .fg = .{ .index = 3 }, .bg = .{ .index = 4 }, .ul = .{ .index = 5 }, .ul_style = .curly, .bold = true, .dim = true, .italic = true, .blink = true, .reverse = true, .invisible = true, .strikethrough = true },
        2 => .{ .fg = .{ .rgb = .{ 1, 2, 3 } }, .bg = .{ .rgb = .{ 5, 8, 13 } }, .ul = .{ .rgb = .{ 21, 34, 55 } }, .ul_style = .dashed, .italic = true },
        3 => .{ .ul_style = .double, .bold = true },
        else => .{},
    };
}
fn color(value: vaxis.Color) u32 {
    return switch (value) {
        .default => 0,
        .index => |index| 0x1000000 | @as(u32, index),
        .rgb => |rgb| 0x2000000 | (@as(u32, rgb[0]) << 16) | (@as(u32, rgb[1]) << 8) | @as(u32, rgb[2]),
    };
}
fn cell(writer: *Writer, value: vaxis.Cell) !void {
    const flags = @as(u8, @intFromBool(value.style.bold)) | (@as(u8, @intFromBool(value.style.dim)) << 1) | (@as(u8, @intFromBool(value.style.italic)) << 2) | (@as(u8, @intFromBool(value.style.blink)) << 3) | (@as(u8, @intFromBool(value.style.reverse)) << 4) | (@as(u8, @intFromBool(value.style.invisible)) << 5) | (@as(u8, @intFromBool(value.style.strikethrough)) << 6);
    try writer.print("{s}/{d}/{d}/{d}/{d}/{d}/{d}/{d}/{d}/{s}/{s};", .{ value.char.grapheme, value.char.width, color(value.style.fg), color(value.style.bg), color(value.style.ul), @intFromEnum(value.style.ul_style), flags, @intFromBool(value.default), @intFromBool(value.wrapped), value.link.uri, value.link.params });
}
fn window(writer: *Writer, value: vaxis.Window) !void {
    try writer.print("{d},{d},{d},{d},{d},{d};", .{ value.x_off, value.y_off, value.parent_x_off, value.parent_y_off, value.width, value.height });
}
fn key(parts: []const []const u8, code_index: usize, mods_index: usize) !vaxis.Key {
    return .{ .codepoint = codes[try uint(parts, code_index)], .mods = @bitCast(@as(u8, @intCast(try uint(parts, mods_index)))) };
}
fn trap(mode: []const u8) !void {
    var screen = try vaxis.Screen.init(std.heap.page_allocator, .{ .cols = 1, .rows = 2, .x_pixel = 0, .y_pixel = 0 });
    defer screen.deinit(std.heap.page_allocator);
    const win: vaxis.Window = .{ .x_off = 0, .y_off = 0, .parent_x_off = 0, .parent_y_off = 0, .width = 1, .height = 2, .screen = &screen };
    const maximum = std.math.maxInt(usize);
    const bar: vaxis.widgets.Scrollbar = if (std.mem.eql(u8, mode, "overflow_view")) .{ .total = maximum, .view_size = maximum - 1 } else if (std.mem.eql(u8, mode, "overflow_top")) .{ .total = maximum, .view_size = 1, .top = maximum } else .{ .total = 2, .view_size = 1, .top = 65536 };
    bar.draw(win);
}
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    if (std.mem.startsWith(u8, args[1], "overflow_") or std.mem.eql(u8, args[1], "row_cast")) return trap(args[1]);
    const contents = try std.fs.cwd().readFileAlloc(allocator, args[1], 32 * 1024 * 1024);
    var lines = std.mem.tokenizeScalar(u8, contents, '\n');
    var buffer: [64 * 1024]u8 = undefined;
    var output = std.fs.File.stdout().writer(&buffer);
    const writer = &output.interface;
    while (lines.next()) |line| {
        var split = std.mem.splitScalar(u8, line, '|');
        var parts_buf: [24][]const u8 = undefined;
        var count: usize = 0;
        while (split.next()) |part| {
            parts_buf[count] = part;
            count += 1;
        }
        const parts = parts_buf[0..count];
        switch (parts[0][0]) {
            'A' => {
                var screen: vaxis.Screen = .{};
                const parent: vaxis.Window = .{ .width = @intCast(try uint(parts, 1)), .height = @intCast(try uint(parts, 2)), .x_off = try std.fmt.parseInt(i17, parts[3], 10), .y_off = try std.fmt.parseInt(i17, parts[4], 10), .parent_x_off = try std.fmt.parseInt(i17, parts[5], 10), .parent_y_off = try std.fmt.parseInt(i17, parts[6], 10), .screen = &screen };
                const cols: u16 = @intCast(try uint(parts, 7));
                const rows: u16 = @intCast(try uint(parts, 8));
                const alignment = vaxis.widgets.alignment;
                try window(writer, alignment.center(parent, cols, rows));
                try window(writer, alignment.topLeft(parent, cols, rows));
                try window(writer, alignment.topRight(parent, cols, rows));
                try window(writer, alignment.bottomLeft(parent, cols, rows));
                try window(writer, alignment.bottomRight(parent, cols, rows));
            },
            'I' => {
                var view: ScrollView = .{ .scroll = .{ .x = try uint(parts, 1), .y = try uint(parts, 2) } };
                view.input(try key(parts, 3, 4));
                try writer.print("{d},{d};", .{ view.scroll.x, view.scroll.y });
            },
            'R' => {
                var scroll: ScrollView.Scroll = .{ .x = try uint(parts, 1), .y = try uint(parts, 2) };
                scroll.restrictTo(try uint(parts, 3), try uint(parts, 4));
                try writer.print("{d},{d};", .{ scroll.x, scroll.y });
            },
            'G' => {
                var screen: vaxis.Screen = .{};
                const parent: vaxis.Window = .{ .width = @intCast(try uint(parts, 1)), .height = @intCast(try uint(parts, 2)), .x_off = 0, .y_off = 0, .parent_x_off = 0, .parent_y_off = 0, .screen = &screen };
                var view: ScrollView = .{ .scroll = .{ .x = try uint(parts, 4), .y = try uint(parts, 5) }, .vertical_scrollbar = if (try uint(parts, 3) == 0) null else .{} };
                const bounds = view.bounds(parent);
                const col = try uint(parts, 6);
                const row = try uint(parts, 7);
                try writer.print("{d},{d},{d},{d};{d},{d},{d},{d},{d};", .{ bounds.x1, bounds.y1, bounds.x2, bounds.y2, @intFromBool(bounds.below(row)), @intFromBool(bounds.above(row)), @intFromBool(bounds.rowInside(row)), @intFromBool(bounds.colInside(col)), @intFromBool(bounds.inside(col, row)) });
            },
            'B', 'C' => {
                var screen = try vaxis.Screen.init(allocator, .{ .cols = @intCast(try uint(parts, 1)), .rows = @intCast(try uint(parts, 2)), .x_pixel = 0, .y_pixel = 0 });
                defer screen.deinit(allocator);
                const root: vaxis.Window = .{ .x_off = 0, .y_off = 0, .parent_x_off = 0, .parent_y_off = 0, .width = screen.width, .height = screen.height, .screen = &screen };
                const win = root.child(.{ .x_off = try std.fmt.parseInt(i17, parts[3], 10), .y_off = try std.fmt.parseInt(i17, parts[4], 10), .width = @intCast(try uint(parts, 5)), .height = @intCast(try uint(parts, 6)) });
                if (parts[0][0] == 'B') {
                    const bar: vaxis.widgets.Scrollbar = .{ .character = .{ .grapheme = glyphs[try uint(parts, 7)], .width = @intCast(try uint(parts, 8)) }, .style = style(try uint(parts, 9)), .top = try uint(parts, 10), .total = try uint(parts, 11), .view_size = try uint(parts, 12) };
                    bar.draw(win);
                } else {
                    var view: ScrollView = .{ .scroll = .{ .x = try uint(parts, 7), .y = try uint(parts, 8) }, .vertical_scrollbar = if (try uint(parts, 11) == 0) null else .{ .character = .{ .grapheme = glyphs[try uint(parts, 12)], .width = @intCast(try uint(parts, 13)) }, .fg = style(2), .bg = style(1) } };
                    view.input(try key(parts, 14, 15));
                    try writer.print("{d},{d};", .{ view.scroll.x, view.scroll.y });
                    view.draw(win, .{ .cols = try uint(parts, 9), .rows = try uint(parts, 10) });
                    const bounds = view.bounds(win);
                    const col = try uint(parts, 16);
                    const row = try uint(parts, 17);
                    try writer.print("{d},{d},{d},{d},{d},{d};{d},{d},{d},{d},{d};", .{ view.scroll.x, view.scroll.y, bounds.x1, bounds.y1, bounds.x2, bounds.y2, @intFromBool(bounds.below(row)), @intFromBool(bounds.above(row)), @intFromBool(bounds.rowInside(row)), @intFromBool(bounds.colInside(col)), @intFromBool(bounds.inside(col, row)) });
                    view.writeCell(win, col, row, .{ .char = .{ .grapheme = "#", .width = 2 }, .style = style(2), .link = .{ .uri = "https://example.test/", .params = "id=content" }, .wrapped = true });
                    if (bounds.inside(col, row)) {
                        if (win.readCell(@intCast(col -| view.scroll.x), @intCast(row -| view.scroll.y))) |value| try cell(writer, value) else try writer.writeAll("none;");
                    } else try writer.writeAll("none;");
                }
                for (screen.buf) |value| try cell(writer, value);
            },
            else => return error.InvalidMode,
        }
        try writer.writeByte('\n');
    }
    try writer.flush();
}
