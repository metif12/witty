const std = @import("std");
const vaxis = @import("vaxis");
const ScrollView = vaxis.widgets.ScrollView;
const Writer = std.Io.Writer;
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
    for (value.char.grapheme) |byte| try writer.print("{x:0>2}", .{byte});
    try writer.print("/{d}/{d}/{d}/{d}/{d}/{d}/{d}/{d}/{s}/{s};", .{ value.char.width, color(value.style.fg), color(value.style.bg), color(value.style.ul), @intFromEnum(value.style.ul_style), flags, @intFromBool(value.default), @intFromBool(value.wrapped), value.link.uri, value.link.params });
    try writer.print("{d},{d},{d},{d},", .{ value.scale.scale, value.scale.numerator, value.scale.denominator, @intFromEnum(value.scale.vertical_alignment) });
    if (value.image) |img| try writer.print("{d};", .{img.img_id}) else try writer.writeAll("none;");
}
fn key(parts: []const []const u8, code_index: usize, mods_index: usize) !vaxis.Key {
    return .{ .codepoint = codes[try uint(parts, code_index)], .mods = @bitCast(@as(u8, @intCast(try uint(parts, mods_index)))) };
}
const clusters = [_][]const u8{ "a", " ", "é", "界", "👩‍💻", "\n", "\r\n", "\t", "\x00", "é", "🏳️‍🌈", "" };
fn root(screen: *vaxis.Screen) vaxis.Window {
    return .{ .x_off = 0, .y_off = 0, .parent_x_off = 0, .parent_y_off = 0, .width = screen.width, .height = screen.height, .screen = screen };
}
fn screenValues(writer: *Writer, screen: vaxis.Screen) !void {
    for (screen.buf) |value| try cell(writer, value);
}
fn trap(mode: []const u8) !void {
    const src = std.mem.eql(u8, mode, "trap_src");
    var view = try vaxis.widgets.View.init(std.heap.page_allocator, .{ .width = if (src) 1024 else 4, .height = if (src) 65 else 2 });
    defer view.deinit();
    var screen = try vaxis.Screen.init(std.heap.page_allocator, .{ .cols = if (src) 1024 else 4, .rows = if (src) 65 else 2, .x_pixel = 0, .y_pixel = 0 });
    defer screen.deinit(std.heap.page_allocator);
    var win = root(&screen);
    if (std.mem.eql(u8, mode, "trap_glyph") or std.mem.eql(u8, mode, "trap_grapheme") or std.mem.eql(u8, mode, "trap_style_index")) {
        var buffer: vaxis.widgets.TextView.Buffer = .{};
        defer buffer.deinit(std.heap.page_allocator);
        const repeated = [_]u8{'a'} ** 256;
        try buffer.content.appendSlice(std.heap.page_allocator, if (std.mem.eql(u8, mode, "trap_glyph")) &repeated else "a");
        try buffer.grapheme.append(std.heap.page_allocator, .{ .offset = if (std.mem.eql(u8, mode, "trap_grapheme")) 8 else 0, .len = if (std.mem.eql(u8, mode, "trap_glyph")) 256 else 1 });
        buffer.cols = 256;
        buffer.rows = 1;
        if (std.mem.eql(u8, mode, "trap_style_index")) try buffer.style_map.put(std.heap.page_allocator, 0, std.math.maxInt(usize));
        var text: vaxis.widgets.TextView = .{ .scroll_view = .{ .vertical_scrollbar = null } };
        text.draw(win, buffer);
    } else if (std.mem.eql(u8, mode, "trap_dst")) {
        screen.width = 65535;
        win.width = 1;
        win.x_off = 1;
        view.draw(win, .{});
    } else if (src) {
        view.draw(win, .{});
    } else if (std.mem.eql(u8, mode, "trap_negx")) {
        win.x_off = -1;
        view.draw(win, .{});
    } else if (std.mem.eql(u8, mode, "trap_negy")) {
        win.y_off = -1;
        view.draw(win, .{});
    } else if (std.mem.eql(u8, mode, "trap_bounds")) {
        win.x_off = 3;
        view.draw(win, .{});
    } else if (std.mem.eql(u8, mode, "trap_zero")) {
        view.screen.width = 0;
        _ = try view.toWin(win, .{});
    } else if (std.mem.eql(u8, mode, "trap_slice")) {
        var borrowed = screen;
        borrowed.buf = view.screen.buf[1..];
        var child = win;
        child.screen = &borrowed;
        child.width = 2;
        child.height = 1;
        view.draw(child, .{});
    } else if (std.mem.eql(u8, mode, "trap_overlap") or std.mem.eql(u8, mode, "trap_same")) {
        var own = view.window();
        own.x_off = if (std.mem.eql(u8, mode, "trap_overlap")) 1 else 0;
        own.width = 2;
        view.draw(own, .{});
    } else if (std.mem.eql(u8, mode, "trap_lines")) {
        const n: vaxis.widgets.LineNumbers = .{ .num_lines = 0 };
        n.draw(win, 0);
    } else if (std.mem.eql(u8, mode, "trap_highlight")) {
        const n: vaxis.widgets.LineNumbers = .{ .num_lines = 2, .highlighted_line = 1 };
        win.width = 0;
        n.draw(win, 0);
    } else if (std.mem.eql(u8, mode, "trap_scroll")) {
        const n: vaxis.widgets.LineNumbers = .{};
        n.draw(win, std.math.maxInt(usize));
    } else if (std.mem.eql(u8, mode, "trap_digit")) {
        std.debug.print("{d}", .{vaxis.widgets.LineNumbers.extractDigit(0, 20)});
    } else if (std.mem.eql(u8, mode, "trap_style")) {
        var b: vaxis.widgets.TextView.Buffer = .{};
        try b.updateStyle(std.heap.page_allocator, .{ .begin = 1, .end = 0, .style = .{} });
    } else return error.UnknownTrap;
}
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    if (std.mem.startsWith(u8, args[1], "trap_")) return trap(args[1]);
    const contents = try std.fs.cwd().readFileAlloc(allocator, args[1], 32 * 1024 * 1024);
    var lines = std.mem.tokenizeScalar(u8, contents, '\n');
    var bytes: [64 * 1024]u8 = undefined;
    var out = std.fs.File.stdout().writer(&bytes);
    const writer = &out.interface;
    while (lines.next()) |line| {
        var split = std.mem.splitScalar(u8, line, '|');
        var raw: [24][]const u8 = undefined;
        var count: usize = 0;
        while (split.next()) |part| {
            raw[count] = part;
            count += 1;
        }
        const parts = raw[0..count];
        switch (parts[0][0]) {
            'H' => {
                const value = try uint(parts, 1);
                try writer.print("{d};{d};", .{ vaxis.widgets.LineNumbers.numDigits(value), vaxis.widgets.LineNumbers.extractDigit(value, try uint(parts, 2)) });
            },
            'D', 'R', 'P' => {
                var view = try vaxis.widgets.View.init(allocator, .{ .width = @intCast(try uint(parts, 1)), .height = @intCast(try uint(parts, 2)) });
                defer view.deinit();
                view.clear();
                for (0..view.screen.buf.len) |index| view.writeCell(@intCast(index % view.screen.width), @intCast(index / view.screen.width), .{ .char = .{ .grapheme = clusters[index % 5], .width = @intCast(index % 3) }, .style = style(index % 4), .link = .{ .uri = "uri", .params = "id=x" }, .default = index % 2 == 0, .wrapped = index % 3 == 0, .scale = .{ .scale = @intCast(index % 8), .numerator = @intCast(index % 16), .denominator = @intCast(index % 16), .vertical_alignment = @enumFromInt(index % 3) }, .image = if (index % 2 == 0) .{ .img_id = 7, .options = .{} } else null });
                var screen = try vaxis.Screen.init(allocator, .{ .cols = @intCast(try uint(parts, 3)), .rows = @intCast(try uint(parts, 4)), .x_pixel = 0, .y_pixel = 0 });
                defer screen.deinit(allocator);
                const win: vaxis.Window = .{ .x_off = try std.fmt.parseInt(i17, parts[5], 10), .y_off = try std.fmt.parseInt(i17, parts[6], 10), .parent_x_off = 0, .parent_y_off = 0, .width = @intCast(try uint(parts, 7)), .height = @intCast(try uint(parts, 8)), .screen = &screen };
                if (parts[0][0] == 'D') {
                    view.draw(win, .{ .x_off = @intCast(try uint(parts, 9)), .y_off = @intCast(try uint(parts, 10)) });
                } else if (parts[0][0] == 'R') {
                    const result = try view.toWin(win, .{ .x = @intCast(try uint(parts, 9)), .y = @intCast(try uint(parts, 10)), .width = if (try uint(parts, 11) == 0) .fit else .{ .max = @intCast(try uint(parts, 12)) }, .height = if (try uint(parts, 13) == 0) .fit else .{ .max = @intCast(try uint(parts, 14)) } });
                    try writer.print("{d},{d};", .{ result[0], result[1] });
                } else {
                    view.clear();
                    view.screen.width_method = @enumFromInt(try uint(parts, 9));
                    const text = clusters[try uint(parts, 10)];
                    const segment: vaxis.Cell.Segment = .{ .text = text, .style = style(1), .link = .{ .uri = "uri", .params = "id=x" } };
                    const result = view.printSegment(segment, .{ .wrap = @enumFromInt(try uint(parts, 11)), .commit = try uint(parts, 12) != 0, .col_offset = @intCast(try uint(parts, 13)), .row_offset = @intCast(try uint(parts, 14)) });
                    try writer.print("{d};{d},{d},{d};", .{ view.gwidth(text), result.col, result.row, @intFromBool(result.overflow) });
                    if (view.readCell(@intCast(try uint(parts, 13)), @intCast(try uint(parts, 14)))) |value| try cell(writer, value) else try writer.writeAll("none;");
                }
                try screenValues(writer, screen);
                if (parts[0][0] == 'P') try screenValues(writer, view.screen);
            },
            'N' => {
                var screen = try vaxis.Screen.init(allocator, .{ .cols = @intCast(try uint(parts, 1)), .rows = @intCast(try uint(parts, 2)), .x_pixel = 0, .y_pixel = 0 });
                defer screen.deinit(allocator);
                const win = root(&screen).child(.{ .x_off = try std.fmt.parseInt(i17, parts[3], 10), .y_off = try std.fmt.parseInt(i17, parts[4], 10), .width = @intCast(try uint(parts, 5)), .height = @intCast(try uint(parts, 6)) });
                const n: vaxis.widgets.LineNumbers = .{ .num_lines = try uint(parts, 7), .highlighted_line = try uint(parts, 9), .style = style(try uint(parts, 10)), .highlighted_style = style(try uint(parts, 11)) };
                n.draw(win, try uint(parts, 8));
                try screenValues(writer, screen);
            },
            'T' => {
                var buffer: vaxis.widgets.TextView.Buffer = .{};
                defer buffer.deinit(allocator);
                var x: usize = 0;
                var splitclusters = std.mem.splitScalar(u8, parts[1], ',');
                while (splitclusters.next()) |rawcluster| {
                    const cluster = clusters[try std.fmt.parseInt(usize, rawcluster, 10)];
                    try buffer.grapheme.append(allocator, .{ .len = @intCast(cluster.len), .offset = @intCast(buffer.content.items.len) });
                    try buffer.content.appendSlice(allocator, cluster);
                    if (std.mem.eql(u8, cluster, "\n")) {
                        buffer.cols = @max(buffer.cols, x);
                        x = 0;
                        buffer.rows += 1;
                    } else {
                        x += vaxis.gwidth.gwidth(cluster, .unicode);
                    }
                }
                const adapter = buffer.writer(allocator);
                try writer.print("{d},{d};", .{ @intFromBool(adapter.context.buffer == &buffer), @intFromBool(adapter.context.writer().context.buffer == &buffer) });
                buffer.last_cols = x;
                buffer.cols = @max(buffer.cols, x);
                for (0..3) |i| try buffer.updateStyle(allocator, .{ .begin = i, .end = buffer.content.items.len + i, .style = style(i % 2 + 1) });
                try writer.print("{d},{d};{d},{d},{d};", .{ buffer.style_list.items.len, buffer.style_map.count(), buffer.rows, buffer.cols, buffer.last_cols });
                var screen = try vaxis.Screen.init(allocator, .{ .cols = @intCast(try uint(parts, 2)), .rows = @intCast(try uint(parts, 3)), .x_pixel = 0, .y_pixel = 0 });
                defer screen.deinit(allocator);
                screen.width_method = @enumFromInt(try uint(parts, 8));
                const win = root(&screen).child(.{ .x_off = try std.fmt.parseInt(i17, parts[4], 10), .y_off = try std.fmt.parseInt(i17, parts[5], 10), .width = @intCast(try uint(parts, 6)), .height = @intCast(try uint(parts, 7)) });
                var view: vaxis.widgets.TextView = .{ .scroll_view = .{ .scroll = .{ .x = try uint(parts, 9), .y = try uint(parts, 10) }, .vertical_scrollbar = if (try uint(parts, 11) == 0) null else .{} } };
                view.input(try key(parts, 12, 13));
                view.draw(win, buffer);
                try writer.print("{d},{d};", .{ view.scroll_view.scroll.x, view.scroll_view.scroll.y });
                try screenValues(writer, screen);
                buffer.clear(allocator);
                try writer.print("{d},{d},{d},{d},{d},{d},{d};", .{ buffer.content.items.len, buffer.grapheme.len, buffer.style_list.items.len, buffer.style_map.count(), buffer.rows, buffer.cols, buffer.last_cols });
            },
            'I' => {
                var view: vaxis.widgets.CodeView = .{};
                view.input(try key(parts, 1, 2));
                try writer.print("{d},{d},{d};", .{ view.scroll_view.scroll.x, view.scroll_view.scroll.y, @intFromBool(view.scroll_view.vertical_scrollbar != null) });
                try cell(writer, view.indentation_cell);
            },
            else => return error.InvalidMode,
        }
        try writer.writeByte('\n');
    }
    try writer.flush();
}
