const std = @import("std");
const vaxis = @import("vaxis");
const Input = vaxis.widgets.TextInput;
const Writer = std.Io.Writer;
fn uint(parts: []const []const u8, index: usize) !usize {
    return std.fmt.parseInt(usize, parts[index], 10);
}
fn bytes(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
    const decoded = try allocator.alloc(u8, value.len / 2);
    return try std.fmt.hexToBytes(decoded, value);
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

fn state(writer: *Writer, input: Input) !void {
    const b = input.buf;
    try writer.print("{d},{d},{d};", .{ b.buffer.len, b.cursor, b.gap_size });
    if (b.cursor <= b.buffer.len and b.gap_size <= b.buffer.len - b.cursor) {
        for (b.firstHalf()) |byte| try writer.print("{x:0>2}", .{byte});
        try writer.writeByte('/');
        for (b.secondHalf()) |byte| try writer.print("{x:0>2}", .{byte});
        try writer.writeByte(';');
    } else try writer.writeAll("invalid;");
    try writer.print("{d},{d},{d},{d};", .{ input.draw_offset, input.prev_cursor_col, input.prev_cursor_idx, input.scroll_offset });
}
fn trap(mode: []const u8) !void {
    var input = Input.init(std.heap.page_allocator);
    defer input.deinit();
    try input.buf.insertSliceAtCursor("abc");
    if (std.mem.eql(u8, mode, "trap_count")) {
        input.buf.clearAndFree();
        const repeated = try std.heap.page_allocator.alloc(u8, 65536);
        @memset(repeated, 'a');
        try input.buf.insertSliceAtCursor(repeated);
        _ = input.graphemesBeforeCursor();
    } else if (std.mem.eql(u8, mode, "trap_width")) {
        input.buf.clearAndFree();
        const repeated = try std.heap.page_allocator.alloc(u8, 32768 * 3);
        for (0..32768) |i| @memcpy(repeated[i * 3 ..][0..3], "界");
        try input.buf.insertSliceAtCursor(repeated);
        var screen = try vaxis.Screen.init(std.heap.page_allocator, .{ .cols = 16, .rows = 2, .x_pixel = 0, .y_pixel = 0 });
        _ = input.widthToCursor(root(&screen));
    } else if (std.mem.startsWith(u8, mode, "trap_utf8_")) {
        input.buf.clearAndFree();
        try input.buf.insertSliceAtCursor("\xff\xcc\x81");
        if (std.mem.eql(u8, mode, "trap_utf8_left")) input.cursorLeft() else if (std.mem.eql(u8, mode, "trap_utf8_delete")) input.deleteBeforeCursor() else if (std.mem.eql(u8, mode, "trap_utf8_count")) _ = input.graphemesBeforeCursor() else if (std.mem.eql(u8, mode, "trap_utf8_width")) {
            var screen = try vaxis.Screen.init(std.heap.page_allocator, .{ .cols = 16, .rows = 2, .x_pixel = 0, .y_pixel = 0 });
            _ = input.widthToCursor(root(&screen));
        } else if (std.mem.eql(u8, mode, "trap_utf8_right")) {
            input.buf.moveGapLeft(3);
            input.cursorRight();
        } else if (std.mem.eql(u8, mode, "trap_utf8_after")) {
            input.buf.moveGapLeft(3);
            input.deleteAfterCursor();
        }
    } else if (std.mem.eql(u8, mode, "trap_right")) input.buf.moveGapRight(1) else if (std.mem.eql(u8, mode, "trap_right_order")) {
        input.buf.cursor = input.buf.buffer.len + 1;
        input.buf.gap_size = std.math.maxInt(usize);
        input.buf.moveGapRight(0);
    } else if (std.mem.eql(u8, mode, "trap_right_add")) {
        input.buf.cursor = std.math.maxInt(usize);
        input.buf.moveGapRight(1);
    } else if (std.mem.eql(u8, mode, "trap_right_end")) {
        input.buf.gap_size = std.math.maxInt(usize);
        input.buf.moveGapRight(1);
    } else if (std.mem.eql(u8, mode, "trap_gap_left")) {
        input.buf.gap_size = std.math.maxInt(usize);
        input.buf.growGapLeft(1);
    } else if (std.mem.eql(u8, mode, "trap_grow")) {
        try input.buf.grow(std.math.maxInt(usize));
    } else if (std.mem.eql(u8, mode, "trap_first_half")) {
        input.buf.cursor = 1 << 32;
        _ = input.buf.firstHalf();
    } else if (std.mem.eql(u8, mode, "trap_second_half")) {
        input.buf.cursor = std.math.maxInt(usize);
        input.buf.gap_size = 1;
        _ = input.buf.secondHalf();
    } else if (std.mem.eql(u8, mode, "trap_left_add")) {
        input.buf.cursor = std.math.maxInt(usize);
        input.buf.gap_size = std.math.maxInt(usize);
        input.buf.moveGapLeft(0);
    } else if (std.mem.eql(u8, mode, "trap_left_zero")) {
        input.buf.cursor = input.buf.buffer.len + 1;
        input.buf.gap_size = 0;
        input.buf.moveGapLeft(0);
    } else if (std.mem.eql(u8, mode, "trap_gap_right_add")) {
        input.buf.growGapRight(std.math.maxInt(usize));
    } else if (std.mem.eql(u8, mode, "trap_gap_right_sub")) {
        input.buf.cursor = input.buf.buffer.len + 1;
        input.buf.gap_size = 0;
        input.buf.growGapRight(0);
    } else if (std.mem.eql(u8, mode, "trap_insert_add")) {
        input.buf.cursor = std.math.maxInt(usize);
        try input.buf.insertSliceAtCursor("x");
    } else if (std.mem.eql(u8, mode, "trap_slice_short")) {
        var output: [2]u8 = undefined;
        _ = input.sliceToCursor(&output);
    } else if (std.mem.eql(u8, mode, "trap_slice_alias")) {
        _ = input.sliceToCursor(input.buf.buffer);
    } else if (std.mem.eql(u8, mode, "trap_unicode")) try input.insertSliceAtCursor("\xff\xcc\x81");
    std.debug.print("UNEXPECTED\n", .{});
}
fn root(screen: *vaxis.Screen) vaxis.Window {
    return .{ .x_off = 0, .y_off = 0, .parent_x_off = 0, .parent_y_off = 0, .width = screen.width, .height = screen.height, .screen = screen };
}
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    if (std.mem.startsWith(u8, args[1], "trap_")) {
        try trap(args[1]);
        return;
    }
    const file = try std.fs.cwd().openFile(args[1], .{});
    defer file.close();
    const data = try file.readToEndAlloc(allocator, 64 * 1024 * 1024);
    var stdoutbuf: [65536]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&stdoutbuf);
    const writer = &stdout.interface;
    const codes = [_]u21{ vaxis.Key.backspace, vaxis.Key.delete, vaxis.Key.left, vaxis.Key.right, vaxis.Key.home, vaxis.Key.end, 'a', 'b', 'd', 'e', 'f', 'k', 'u', 'w', 'x' };
    var lines = std.mem.splitScalar(u8, data, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var fields = std.mem.splitScalar(u8, line, '|');
        var list: std.ArrayList([]const u8) = .empty;
        while (fields.next()) |part| try list.append(allocator, part);
        defer list.deinit(allocator);
        const parts = list.items;
        var input = Input.init(allocator);
        defer input.deinit();
        const text = try bytes(allocator, parts[1]);
        defer allocator.free(text);
        switch (parts[0][0]) {
            'I' => {
                for (0..try uint(parts, 2)) |_| try input.insertSliceAtCursor(text);
            },
            'B' => {
                try input.buf.insertSliceAtCursor(text);
                input.buf.moveGapLeft(try uint(parts, 2));
                input.buf.moveGapRight(try uint(parts, 3));
                input.buf.growGapRight(try uint(parts, 5));
                input.buf.growGapLeft(try uint(parts, 4));
            },
            'S' => {
                try input.buf.insertSliceAtCursor(text);
                input.buf.moveGapLeft(try uint(parts, 2));
                const output = try allocator.alloc(u8, input.buf.cursor + try uint(parts, 3));
                defer allocator.free(output);
                @memset(output, 0xa5);
                const prefix = input.sliceToCursor(output);
                try writer.print("{d};", .{@intFromBool(prefix.ptr == output.ptr)});
                for (prefix) |byte| try writer.print("{x:0>2}", .{byte});
                try writer.writeByte(';');
                for (output) |byte| try writer.print("{x:0>2}", .{byte});
                try writer.writeByte(';');
            },
            'D' => {
                try input.insertSliceAtCursor(text);
                for (0..try uint(parts, 2)) |_| input.cursorLeft();
                input.draw_offset = @intCast(try uint(parts, 6));
                input.prev_cursor_col = 19;
                input.prev_cursor_idx = 23;
                var screen = try vaxis.Screen.init(allocator, .{ .cols = 16, .rows = 2, .x_pixel = 0, .y_pixel = 0 });
                defer screen.deinit(allocator);
                screen.width_method = @enumFromInt(try uint(parts, 5));
                const win = root(&screen).child(.{ .width = @intCast(try uint(parts, 3)), .height = @intCast(try uint(parts, 4)) });
                input.drawWithStyle(win, style(try uint(parts, 7)));
                try writer.print("{d},{d},{d};", .{ screen.cursor_col, screen.cursor_row, @intFromBool(screen.cursor_vis) });
                for (screen.buf) |value| try cell(writer, value);
            },
            'E' => {
                try input.buf.insertSliceAtCursor(text);
                input.buf.moveGapLeft(try uint(parts, 2));
                switch (try uint(parts, 3)) {
                    0 => input.cursorLeft(),
                    1 => input.cursorRight(),
                    2 => input.deleteBeforeCursor(),
                    3 => input.deleteAfterCursor(),
                    else => {},
                }
                input.draw_offset = @intCast(try uint(parts, 5));
                var screen = try vaxis.Screen.init(allocator, .{ .cols = 16, .rows = 2, .x_pixel = 0, .y_pixel = 0 });
                defer screen.deinit(allocator);
                screen.width_method = @enumFromInt(try uint(parts, 4));
                const win = root(&screen).child(.{ .width = @intCast(try uint(parts, 6)), .height = 1 });
                try writer.print("{d},{d};", .{ input.graphemesBeforeCursor(), input.widthToCursor(win) });
                input.drawWithStyle(win, style(try uint(parts, 7)));
                try writer.print("{d},{d},{d};", .{ screen.cursor_col, screen.cursor_row, @intFromBool(screen.cursor_vis) });
                for (screen.buf) |value| try cell(writer, value);
            },
            'U' => {
                try input.insertSliceAtCursor(text);
                for (0..try uint(parts, 2)) |_| input.cursorLeft();
                const keytext: ?[]const u8 = if (std.mem.eql(u8, parts[5], "none")) null else try bytes(allocator, parts[5]);
                defer if (keytext) |s| allocator.free(s);
                try input.update(.{ .key_press = .{ .codepoint = codes[try uint(parts, 3)], .mods = @bitCast(@as(u8, @intCast(try uint(parts, 4)))), .text = keytext } });
            },
            else => return error.InvalidMode,
        }
        try state(writer, input);
        try writer.writeByte('\n');
    }
    try writer.flush();
}
