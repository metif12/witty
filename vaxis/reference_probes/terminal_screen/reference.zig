const std = @import("std");
const vaxis = @import("vaxis");
const Screen = @FieldType(vaxis.widgets.Terminal, "front_screen");
const Writer = std.Io.Writer;
fn uint(parts: []const []const u8, i: usize) !usize {
    return std.fmt.parseInt(usize, parts[i], 10);
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

fn values(out: *Writer, screen: Screen) !void {
    try out.print("{d},{d};{d},{d},{d},{d};", .{ screen.width, screen.height, screen.scrolling_region.top, screen.scrolling_region.bottom, screen.scrolling_region.left, screen.scrolling_region.right });
    const cursor = screen.cursor;
    try out.print("{d},{d},{d},{d},{d},{d};", .{ cursor.col, cursor.row, @intFromBool(cursor.pending_wrap), @intFromEnum(cursor.shape), @intFromBool(cursor.visible), @as(u5, @bitCast(screen.csi_u_flags)) });
    try cell(out, .{ .style = cursor.style, .link = .{ .uri = cursor.uri.items, .params = cursor.uri_id.items } });
    for (screen.buf) |value| {
        try cell(out, .{ .char = .{ .grapheme = value.char.items, .width = value.width }, .style = value.style, .wrapped = value.wrapped, .link = .{ .uri = value.uri.items, .params = value.uri_id.items } });
        try out.print("{d};", .{@intFromBool(value.dirty)});
    }
}
fn seed(screen: *Screen, offset: usize) !void {
    const a = screen.allocator;
    for (screen.buf, 0..) |*value, i| {
        value.char.clearRetainingCapacity();
        try value.char.appendSlice(a, try std.fmt.allocPrint(a, "{d}", .{i + offset}));
        try value.uri.appendSlice(a, try std.fmt.allocPrint(a, "u{d}", .{i + offset}));
        try value.uri_id.appendSlice(a, try std.fmt.allocPrint(a, "i{d}", .{i + offset}));
        value.style = style((i + offset) % 4);
        value.width = @intCast(i % 3);
        value.wrapped = i % 2 == 0;
        value.dirty = i % 3 != 0;
    }
    screen.cursor.uri = .empty;
    screen.cursor.uri_id = .empty;
    try screen.cursor.uri.appendSlice(a, "cursor");
    try screen.cursor.uri_id.appendSlice(a, "id");
    screen.cursor.style = style(2);
    screen.cursor.shape = .beam;
    screen.cursor.visible = false;
    screen.csi_u_flags = @bitCast(@as(u5, 17));
}
fn trap(mode: []const u8) !void {
    const a = std.heap.c_allocator;
    if (std.mem.eql(u8, mode, "trap_zero_w") or std.mem.eql(u8, mode, "trap_zero_h")) {
        _ = try Screen.init(a, if (std.mem.eql(u8, mode, "trap_zero_w")) 0 else 1, if (std.mem.eql(u8, mode, "trap_zero_h")) 0 else 1);
    } else {
        var screen = try Screen.init(a, 2, 2);
        try seed(&screen, 0);
        if (std.mem.eql(u8, mode, "trap_read")) _ = screen.readCell(0, 2) else if (std.mem.eql(u8, mode, "trap_read_add")) _ = screen.readCell(std.math.maxInt(usize), 0) else if (std.mem.eql(u8, mode, "trap_right")) {
            screen.cursor.col = 65535;
            screen.cursorRight(1);
        } else if (std.mem.eql(u8, mode, "trap_down")) {
            screen.cursor.row = 1;
            screen.cursorDown(std.math.maxInt(usize));
        } else if (std.mem.eql(u8, mode, "trap_index")) {
            screen.cursor.row = 65535;
            try screen.index();
        } else if (std.mem.eql(u8, mode, "trap_print")) {
            screen.width = 65535;
            screen.height = 3;
            screen.cursor.row = 2;
            try screen.print("x", 1, false);
        } else if (std.mem.eql(u8, mode, "trap_delete_count")) {
            screen.width = 1;
            screen.height = 65535;
            screen.scrolling_region.bottom = 65535;
            screen.scrolling_region.right = 0;
            try screen.deleteLine(1);
        } else if (std.mem.eql(u8, mode, "trap_erase_below_count")) {
            var tall = try Screen.init(a, 256, 256);
            tall.eraseBelow();
        } else if (std.mem.eql(u8, mode, "trap_erase")) {
            screen.width = 65535;
            screen.height = 3;
            screen.cursor.row = 2;
            screen.eraseLine();
        } else if (std.mem.eql(u8, mode, "trap_enum")) screen.sgr(.{ .params = "4:6", .final = 'm' }) else if (std.mem.eql(u8, mode, "trap_sgr")) screen.sgr(.{ .params = "256", .final = 'm' }) else if (std.mem.eql(u8, mode, "trap_self_to")) {
            try screen.copyTo(a, &screen);
        } else if (std.mem.eql(u8, mode, "trap_copy")) {
            var dst = try Screen.init(a, 1, 1);
            try screen.copyTo(a, &dst);
        } else if (std.mem.eql(u8, mode, "hang_insert")) {
            screen.cursor.row = 1;
            try screen.insertLine(1);
        }
    }
    std.debug.print("UNEXPECTED\n", .{});
}
pub fn main() !void {
    const a = std.heap.c_allocator;
    const args = try std.process.argsAlloc(a);
    if (std.mem.startsWith(u8, args[1], "trap_") or std.mem.startsWith(u8, args[1], "hang_")) {
        try trap(args[1]);
        return;
    }
    const file = try std.fs.cwd().openFile(args[1], .{});
    defer file.close();
    const data = try file.readToEndAlloc(a, 64 * 1024 * 1024);
    var stdoutbuf: [65536]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&stdoutbuf);
    const out = &stdout.interface;
    var lines = std.mem.splitScalar(u8, data, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var fields = std.mem.splitScalar(u8, line, '|');
        var list: std.ArrayList([]const u8) = .empty;
        while (fields.next()) |part| try list.append(a, part);
        const parts = list.items;
        defer list.deinit(a);
        var screen = try Screen.init(a, @intCast(try uint(parts, 1)), @intCast(try uint(parts, 2)));
        defer screen.deinit(a);
        screen.cursor.uri = .empty;
        screen.cursor.uri_id = .empty;
        if (parts[0][0] == 'N') {
            try values(out, screen);
            try out.writeByte('\n');
            continue;
        }
        try seed(&screen, 0);
        screen.scrolling_region = .{ .top = @intCast(try uint(parts, 3)), .bottom = @intCast(try uint(parts, 4)), .left = @intCast(try uint(parts, 5)), .right = @intCast(try uint(parts, 6)) };
        screen.cursor.col = @intCast(try uint(parts, 7));
        screen.cursor.row = @intCast(try uint(parts, 8));
        screen.cursor.pending_wrap = try uint(parts, 9) != 0;
        const op = try uint(parts, 10);
        const n = try uint(parts, 11);
        const bytes = try a.alloc(u8, parts[12].len / 2);
        defer a.free(bytes);
        const text = try std.fmt.hexToBytes(bytes, parts[12]);
        switch (op) {
            0 => try screen.print(text, @intCast(try uint(parts, 13)), try uint(parts, 14) != 0),
            1 => try screen.index(),
            2 => screen.cursorUp(@intCast(n)),
            3 => screen.cursorLeft(@intCast(n)),
            4 => screen.cursorRight(@intCast(n)),
            5 => screen.cursorDown(n),
            6 => screen.eraseRight(),
            7 => screen.eraseLeft(),
            8 => screen.eraseLine(),
            9 => try screen.deleteLine(n),
            10 => try screen.insertLine(n),
            11 => screen.eraseBelow(),
            12 => screen.eraseAbove(),
            13 => screen.eraseAll(),
            14 => try screen.deleteCharacters(n),
            15 => try screen.reverseIndex(),
            16 => try screen.scrollDown(n),
            17 => screen.sgr(.{ .params = text, .final = 'm' }),
            18 => {
                var dst = try Screen.init(a, screen.width, screen.height);
                defer dst.deinit(a);
                try seed(&dst, 100);
                try screen.copyTo(a, &dst);
                if (n != 0) try screen.copyTo(a, &dst);
                try values(out, dst);
            },
            19 => screen.buf[0].erase(a, screen.cursor.style.bg),
            20 => try screen.buf[0].copyFrom(a, screen.buf[n % screen.buf.len]),
            21 => {
                try out.print("{d},{d},{d};", .{ @intFromBool(screen.withinScrollingRegion()), @intFromBool(screen.cursor.isInsideScrollingRegion(screen.scrolling_region)), @intFromBool(screen.cursor.isOutsideScrollingRegion(screen.scrolling_region)) });
                if (screen.readCell(try uint(parts, 13), try uint(parts, 14))) |value| try cell(out, value) else try out.writeAll("none;");
            },
            else => return error.InvalidOp,
        }
        try values(out, screen);
        try out.writeByte('\n');
    }
    try out.flush();
}
