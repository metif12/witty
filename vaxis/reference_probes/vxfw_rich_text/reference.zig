const std = @import("std");
const vaxis = @import("vaxis");
const fw = vaxis.vxfw;
const a = std.heap.page_allocator;

fn style(index: u8) vaxis.Style {
    return switch (index) {
        0 => .{},
        1 => .{ .fg = .{ .index = 17 }, .bg = .{ .index = 231 }, .bold = true, .italic = true },
        2 => .{ .fg = .{ .rgb = .{ 1, 128, 255 } }, .bg = .{ .rgb = .{ 99, 33, 2 } }, .ul = .{ .index = 88 }, .ul_style = .curly, .bold = true, .dim = true, .italic = true, .blink = true, .reverse = true, .invisible = true, .strikethrough = true },
        else => .{ .fg = .{ .index = 99 }, .bg = .{ .index = 3 }, .reverse = true },
    };
}
fn link(index: u8) vaxis.Cell.Hyperlink {
    return switch (index) {
        0 => .{},
        1 => .{ .uri = "https://a", .params = "id=1" },
        else => .{ .uri = "file:///b", .params = "id=2:foo=bar" },
    };
}
fn hex(out: *std.Io.Writer, text: []const u8) !void {
    for (text) |byte| try out.print("{x:0>2}", .{byte});
}
fn number(parts: []const []const u8, i: usize) !u16 {
    return std.fmt.parseInt(u16, parts[i], 10);
}
fn bound(text: []const u8) !?u16 {
    return if (std.mem.eql(u8, text, "-1")) null else try std.fmt.parseInt(u16, text, 10);
}
fn bytes(text: []const u8) ![]u8 {
    const value = try a.alloc(u8, text.len / 2);
    return std.fmt.hexToBytes(value, text);
}
fn observe(out: *std.Io.Writer, value: fw.Surface, rich: *fw.RichText) !void {
    try out.print("{d},{d},{d},{d},{d},{d},{d},{d}|", .{ value.size.width, value.size.height, value.buffer.len, @intFromBool(value.widget.eql(rich.widget())), @intFromBool(value.widget.eventHandler == null), @intFromBool(value.widget.captureHandler == null), @intFromBool(value.cursor == null), value.children.len });
    for (value.buffer) |cell| {
        try hex(out, cell.char.grapheme);
        var style_id: u8 = 255;
        for (0..4) |i| if (cell.style.eql(style(@intCast(i)))) {
            style_id = @intCast(i);
        };
        try out.print("/{d},{d},", .{ cell.char.width, style_id });
        try hex(out, cell.link.uri);
        try out.writeByte(',');
        try hex(out, cell.link.params);
        try out.print(",{d},{d},{d},{d};", .{ @intFromBool(cell.default), @intFromBool(cell.wrapped), @intFromBool(cell.image != null), @intFromBool(cell.scale.eql(.{})) });
    }
}
fn drawText(text: []const u8, width: ?u16, soft: bool) !void {
    var rich: fw.RichText = .{ .text = &.{.{ .text = text }}, .softwrap = soft, .overflow = .clip };
    const ctx: fw.DrawContext = .{ .arena = a, .min = .{}, .max = .{ .width = width }, .cell_size = .{} };
    _ = try rich.draw(ctx);
}
fn trap(mode: []const u8) !void {
    fw.DrawContext.init(.unicode);
    if (std.mem.eql(u8, mode, "trap_parent")) {
        var rich: fw.RichText = .{ .text = &.{}, .width_basis = .parent };
        _ = try rich.widget().draw(.{ .arena = a, .min = .{}, .max = .{}, .cell_size = .{} });
    } else if (std.mem.eql(u8, mode, "trap_cr0")) try drawText("\r", null, false) else if (std.mem.eql(u8, mode, "trap_cr1")) try drawText("a\r", null, true) else if (std.mem.eql(u8, mode, "trap_cr_range")) try drawText("ab\r", null, false) else if (std.mem.eql(u8, mode, "trap_line_width")) {
        const text = try a.alloc(u8, 65536);
        @memset(text, 'x');
        try drawText(text, null, true);
    } else if (std.mem.eql(u8, mode, "trap_col")) {
        const text = try a.alloc(u8, 65536);
        @memset(text, 'x');
        try drawText(text, 1, false);
    } else if (std.mem.eql(u8, mode, "trap_rows")) {
        const text = try a.alloc(u8, 65536);
        @memset(text, '\n');
        try drawText(text, null, false);
    } else if (std.mem.eql(u8, mode, "trap_nonadvancing")) try drawText("界", 1, true) else if (std.mem.eql(u8, mode, "trap_area")) {
        var rich: fw.RichText = .{ .text = &.{.{ .text = "a" }} };
        _ = try rich.draw(.{ .arena = a, .min = .{ .width = 256, .height = 256 }, .max = .{}, .cell_size = .{} });
    } else if (std.mem.eql(u8, mode, "trap_char_cast")) {
        fw.DrawContext.init(.no_zwj);
        var text: std.ArrayList(u8) = .empty;
        for (0..128) |_| try text.appendSlice(a, "👩\u{200d}");
        try text.appendSlice(a, "👩");
        try drawText(text.items, 65535, true);
    } else if (std.mem.eql(u8, mode, "trap_unicode")) try drawText("\x80\xcc\x81", 10, true) else return error.UnknownTrap;
    std.debug.print("UNEXPECTED returned\n", .{});
}
fn allocationFailure(out: *std.Io.Writer) !void {
    for (0..8) |index| {
        var failing = std.testing.FailingAllocator.init(a, .{ .fail_index = index });
        var rich: fw.RichText = .{ .text = &.{.{ .text = "a\tb\nc" }} };
        const ctx: fw.DrawContext = .{ .arena = failing.allocator(), .min = .{}, .max = .{ .width = 8, .height = 8 }, .cell_size = .{} };
        const result = rich.draw(ctx);
        if (result) |surface| {
            try out.print("{d}|OK|{d},{d}\n", .{ index, surface.size.width, surface.size.height });
        } else |err| try out.print("{d}|{s}\n", .{ index, @errorName(err) });
    }
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    if (std.mem.startsWith(u8, args[1], "trap_")) {
        trap(args[1]) catch |err| std.debug.print("UNEXPECTED error {s}\n", .{@errorName(err)});
        return;
    }
    var output: [65536]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&output);
    const out = &stdout.interface;
    if (std.mem.eql(u8, args[1], "oom")) {
        try allocationFailure(out);
        try out.flush();
        return;
    }
    const data = try std.fs.cwd().readFileAlloc(a, args[1], 64 * 1024 * 1024);
    var lines = std.mem.splitScalar(u8, data, '\n');
    var index: usize = 0;
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var split = std.mem.splitScalar(u8, line, '|');
        var parts: [64][]const u8 = undefined;
        var length: usize = 0;
        while (split.next()) |p| {
            parts[length] = p;
            length += 1;
        }
        const p = parts[0..length];
        var spans: std.ArrayList(fw.RichText.TextSpan) = .empty;
        var i: usize = 12;
        while (i < p.len) : (i += 3) try spans.append(a, .{ .text = try bytes(p[i]), .style = style(@intCast(try number(p, i + 1))), .link = link(@intCast(try number(p, i + 2))) });
        var rich: fw.RichText = .{ .text = spans.items, .softwrap = (try number(p, 5)) != 0, .text_align = @enumFromInt(try number(p, 6)), .overflow = @enumFromInt(try number(p, 7)), .width_basis = @enumFromInt(try number(p, 8)), .base_style = style(@intCast(try number(p, 10))) };
        fw.DrawContext.init(@enumFromInt(try number(p, 9)));
        var arena = std.heap.ArenaAllocator.init(a);
        defer arena.deinit();
        const ctx: fw.DrawContext = .{ .arena = arena.allocator(), .min = .{ .width = try number(p, 1), .height = try number(p, 2) }, .max = .{ .width = try bound(p[3]), .height = try bound(p[4]) }, .cell_size = .{ .width = 10, .height = 20 } };
        const surface = if ((try number(p, 11)) != 0) try rich.widget().draw(ctx) else try rich.draw(ctx);
        if (std.mem.eql(u8, p[0], "B")) for (spans.items) |*span| {
            if (span.text.len != 0) @constCast(span.text)[0] = 'Z';
            span.style = style(3);
        };
        try out.print("{d}|", .{index});
        index += 1;
        try observe(out, surface, &rich);
        try out.writeByte('\n');
    }
    try out.flush();
}
