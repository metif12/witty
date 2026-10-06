const std = @import("std");
const v = @import("vaxis");
const W = v.Window;
const B = W.BorderOptions;
const a = std.heap.page_allocator;

fn window(out: *std.Io.Writer, value: W, screen: *v.Screen) !void {
    try out.print("W|{d},{d},{d},{d},{d},{d},{d}\n", .{ value.x_off, value.y_off, value.parent_x_off, value.parent_y_off, value.width, value.height, @intFromBool(value.screen == screen) });
}

fn where(value: B) u8 {
    return switch (value.where) {
        .none => 0,
        .all => 1,
        .top => 2,
        .right => 3,
        .bottom => 4,
        .left => 5,
        .other => 6,
    };
}

fn glyph(value: B) u8 {
    return switch (value.glyphs) {
        .single_rounded => 0,
        .single_square => 1,
        .custom => 2,
    };
}

fn locations(value: B.Locations) u8 {
    return @as(u8, @intFromBool(value.top)) | @as(u8, @intFromBool(value.right)) << 1 | @as(u8, @intFromBool(value.bottom)) << 2 | @as(u8, @intFromBool(value.left)) << 3;
}

pub fn main() !void {
    var bytes: [4096]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&bytes);
    const out = &stdout.interface;
    const args = try std.process.argsAlloc(a);
    if (args.len > 1) {
        try out.print("Locations|{d}|{d}\nWindow|{d}\nPrintResult|{d}\nChildOptions|{d}\nBorderOptions|{d}\nGlyphs|{d}\n", .{ @sizeOf(B.Locations), @bitSizeOf(B.Locations), @sizeOf(W), @sizeOf(W.PrintResult), @sizeOf(W.ChildOptions), @sizeOf(B), @sizeOf(B.Glyphs) });
        try out.flush();
        return;
    }
    const child: W.ChildOptions = .{};
    const border: B = .{};
    const loc: B.Locations = .{};
    const opts: W.PrintOptions = .{};
    try out.print("D|{d},{d},{d},{d},{d}\nD|{d},{d},{d}\nD|{d}\nD|{d},{d},{d},{d}\n", .{ child.x_off, child.y_off, @intFromBool(child.width == null), @intFromBool(child.height == null), where(child.border), @intFromBool(border.style.eql(.{})), where(border), glyph(border), locations(loc), opts.row_offset, opts.col_offset, @intFromEnum(opts.wrap), @intFromBool(opts.commit) });
    var screen: v.Screen = .{};
    const offsets = [_]i17{ -65536, -1, 0, 1, 65535 };
    const sizes = [_]u16{ 0, 1, 255, 65535 };
    for (0..4) |field| {
        for (offsets) |offset| {
            for (sizes) |size| {
                const value: W = .{ .x_off = if (field == 0) offset else 0, .y_off = if (field == 1) offset else 0, .parent_x_off = if (field == 2) offset else 0, .parent_y_off = if (field == 3) offset else 0, .width = size, .height = size, .screen = &screen };
                try window(out, value, &screen);
            }
        }
    }
    for (sizes) |col| for (sizes) |row| for ([_]bool{ false, true }) |overflow| {
        const value: W.PrintResult = .{ .col = col, .row = row, .overflow = overflow };
        try out.print("R|{d},{d},{d}\n", .{ value.col, value.row, @intFromBool(value.overflow) });
    };
    for (0..16) |mask| {
        const value: B.Locations = @bitCast(@as(u4, @intCast(mask)));
        try out.print("L|{d}\n", .{locations(value)});
    }
    for (0..7) |index| {
        for (0..3) |g| {
            const value: B = .{ .where = switch (index) {
                0 => .none,
                1 => .all,
                2 => .top,
                3 => .right,
                4 => .bottom,
                5 => .left,
                else => .{ .other = .{ .top = true, .left = true } },
            }, .glyphs = switch (g) {
                0 => .single_rounded,
                1 => .single_square,
                else => .{ .custom = .{ "0", "1", "2", "3", "4", "5" } },
            }, .style = .{ .bold = true } };
            try out.print("B|{d},{d},{d},{d}", .{ where(value), glyph(value), @intFromBool(value.style.bold), switch (value.where) { .other => |l| locations(l), else => @as(u8, 0) } });
            if (value.glyphs == .custom) for (value.glyphs.custom) |s| try out.print("|{s}", .{s});
            try out.writeByte('\n');
        }
    }
    for (offsets) |offset| {
        for (0..3) |w| for (0..3) |h| {
            const value: W.ChildOptions = .{ .x_off = offset, .y_off = offset, .width = if (w == 0) null else if (w == 1) 0 else 65535, .height = if (h == 0) null else if (h == 1) 0 else 65535 };
            try out.print("C|{d},{d},{d},{d},{d},{d},{d},{d}\n", .{ value.x_off, value.y_off, @intFromBool(value.width != null), value.width orelse 0, @intFromBool(value.height != null), value.height orelse 0, where(value.border), glyph(value.border) });
        };
    }
    for (sizes) |row| for (sizes) |col| {
        for (0..3) |wrap| for ([_]bool{ false, true }) |commit| {
            const value: W.PrintOptions = .{ .row_offset = row, .col_offset = col, .wrap = @enumFromInt(wrap), .commit = commit };
            try out.print("P|{d},{d},{d},{d}\n", .{ value.row_offset, value.col_offset, @intFromEnum(value.wrap), @intFromBool(value.commit) });
        };
    };
    var text = [_]u8{ 't', 'l' };
    var glyphs: [6][]const u8 = .{ &text, "h", "tr", "v", "br", "bl" };
    const custom: B.Glyphs = .{ .custom = glyphs };
    glyphs[0] = "replacement";
    text[0] = 'Z';
    try out.print("A|{s}|{s}|{d}\n", .{ custom.custom[0], glyphs[0], @intFromBool(custom.custom[0].ptr == &text) });
    const value: W = .{ .x_off = 0, .y_off = 0, .parent_x_off = 0, .parent_y_off = 0, .width = 7, .height = 3, .screen = &screen };
    screen.width = 13;
    screen.height = 9;
    try out.print("S|{d},{d},{d},{d}\n", .{ value.width, value.height, value.screen.width, value.screen.height });
    var changed = value;
    const original = changed;
    var other: v.Screen = .{};
    changed.x_off = -1;
    changed.y_off = 1;
    changed.parent_x_off = -2;
    changed.parent_y_off = -3;
    changed.width = 11;
    changed.height = 12;
    changed.screen = &other;
    try out.print("M|{d},{d},{d},{d},{d},{d},{d},{d},{d}\n", .{ changed.x_off, changed.y_off, changed.parent_x_off, changed.parent_y_off, changed.width, changed.height, @intFromBool(changed.screen == &other), original.width, @intFromBool(original.screen == &screen) });
    var result: W.PrintResult = .{ .col = 1, .row = 2, .overflow = false };
    const old_result = result;
    result.col = 3;
    result.row = 4;
    result.overflow = true;
    try out.print("M|{d},{d},{d},{d},{d},{d}\n", .{ result.col, result.row, @intFromBool(result.overflow), old_result.col, old_result.row, @intFromBool(old_result.overflow) });
    var changed_child: W.ChildOptions = .{};
    const old_child = changed_child;
    changed_child.x_off = -7;
    changed_child.y_off = 9;
    changed_child.width = 0;
    changed_child.height = 65535;
    changed_child.border = .{ .style = .{ .bold = true }, .where = .all, .glyphs = .single_square };
    try out.print("M|{d},{d},{d},{d},{d},{d},{d},{d},{d}\n", .{ changed_child.x_off, changed_child.y_off, changed_child.width.?, changed_child.height.?, where(changed_child.border), glyph(changed_child.border), @intFromBool(changed_child.border.style.bold), @intFromBool(old_child.width == null), where(old_child.border) });
    var changed_loc: B.Locations = .{};
    const old_loc = changed_loc;
    changed_loc.top = true;
    changed_loc.right = true;
    changed_loc.bottom = true;
    changed_loc.left = true;
    try out.print("M|{d},{d}\n", .{ locations(changed_loc), locations(old_loc) });
    var changed_custom: B.Glyphs = .{ .custom = .{ "0", "1", "2", "3", "4", "5" } };
    const old_custom = changed_custom;
    changed_custom.custom[0] = "new";
    try out.print("M|{s},{s}\n", .{ changed_custom.custom[0], old_custom.custom[0] });
    var changed_border: B = .{};
    const old_border = changed_border;
    changed_border.style = .{ .bold = true };
    changed_border.where = .all;
    changed_border.glyphs = .single_square;
    try out.print("M|{d},{d},{d},{d},{d},{d}\n", .{ @intFromBool(changed_border.style.bold), where(changed_border), glyph(changed_border), @intFromBool(old_border.style.bold), where(old_border), glyph(old_border) });
    var changed_opts: W.PrintOptions = .{};
    const old_opts = changed_opts;
    changed_opts.row_offset = 17;
    changed_opts.col_offset = 19;
    changed_opts.wrap = .word;
    changed_opts.commit = false;
    try out.print("M|{d},{d},{d},{d},{d},{d},{d},{d}\n", .{ changed_opts.row_offset, changed_opts.col_offset, @intFromEnum(changed_opts.wrap), @intFromBool(changed_opts.commit), old_opts.row_offset, old_opts.col_offset, @intFromEnum(old_opts.wrap), @intFromBool(old_opts.commit) });
    const winsizes = [_]v.Winsize{
        .{ .rows = 0, .cols = 0, .x_pixel = 0, .y_pixel = 0 },
        .{ .rows = 1, .cols = 1, .x_pixel = 7, .y_pixel = 9 },
        .{ .rows = 2, .cols = 3, .x_pixel = 640, .y_pixel = 480 },
        .{ .rows = 0, .cols = 65535, .x_pixel = 65535, .y_pixel = 65535 },
    };
    for (winsizes) |size| {
        var vx = try v.init(a, .{});
        vx.screen = try v.Screen.init(a, size);
        defer vx.screen.deinit(a);
        const root = vx.window();
        try window(out, root, &vx.screen);
        try out.print("V|{d},{d},{d},{d},{d},{d}\n", .{ vx.screen.width_pix, vx.screen.height_pix, vx.screen.buf.len, @intFromBool(root.screen == &vx.screen), @intFromBool(vx.screen.cursor_vis), @intFromEnum(vx.screen.width_method) });
    }
    try out.flush();
}
