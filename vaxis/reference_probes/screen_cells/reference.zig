const std = @import("std");
const vx = @import("vaxis");
const W = std.Io.Writer;
fn number(p: []const []const u8, i: usize) !u16 {
    return std.fmt.parseInt(u16, p[i], 10);
}
fn hex(out: *W, bytes: []const u8) !void {
    for (bytes) |b| try out.print("{x:0>2}", .{b});
}
fn color(value: vx.Cell.Color) u32 {
    return switch (value) {
        .default => 0,
        .index => |n| 0x1000000 + @as(u32, n),
        .rgb => |r| 0x2000000 + (@as(u32, r[0]) << 16) + (@as(u32, r[1]) << 8) + r[2],
    };
}
fn offset(value: []const u8, data: []const u8) i64 {
    const ptr = @intFromPtr(value.ptr);
    const base = @intFromPtr(data.ptr);
    return if (ptr >= base and ptr <= base + data.len and value.len <= base + data.len - ptr) @intCast(ptr - base) else -1;
}
fn flags(s: vx.Style) u8 {
    return @as(u8, @intFromBool(s.bold)) | (@as(u8, @intFromBool(s.dim)) << 1) | (@as(u8, @intFromBool(s.italic)) << 2) | (@as(u8, @intFromBool(s.blink)) << 3) | (@as(u8, @intFromBool(s.reverse)) << 4) | (@as(u8, @intFromBool(s.invisible)) << 5) | (@as(u8, @intFromBool(s.strikethrough)) << 6);
}
fn cell(data: []const u8, n: u8) vx.Cell {
    return .{ .char = .{ .grapheme = data[0 .. n % 4], .width = n }, .style = .{ .fg = switch (n % 3) {
        0 => .default,
        1 => .{ .index = n },
        else => .{ .rgb = .{ n, n ^ 0xaa, 255 - n } },
    }, .bg = .{ .rgb = .{ n, 0, 255 - n } }, .ul = .{ .index = 255 - n }, .ul_style = @enumFromInt(n % 6), .bold = n & 1 != 0, .dim = n & 2 != 0, .italic = n & 4 != 0, .blink = n & 8 != 0, .reverse = n & 16 != 0, .invisible = n & 32 != 0, .strikethrough = n & 64 != 0 }, .link = .{ .uri = data[3..6], .params = data[6..9] }, .default = n & 1 != 0, .wrapped = n & 2 != 0, .scale = .{ .scale = @intCast(n % 8), .numerator = @intCast(n % 16), .denominator = @intCast((n +% 1) % 16), .vertical_alignment = @enumFromInt(n % 3) }, .image = if (n & 1 != 0) .{ .img_id = 0x1000000 + @as(u32, n), .options = .{ .pixel_offset = .{ .x = n, .y = 255 - n }, .z_index = -@as(i32, n), .clip_region = .{ .x = n, .height = 65535 }, .scale = @enumFromInt(n % 4), .size = .{ .cols = n } } } else null };
}
fn cellValue(out: *W, c: vx.Cell, data: []const u8) !void {
    try hex(out, c.char.grapheme);
    try out.print(",{d},{d},{d},{d},{d},{d},{d},{d},{d},", .{ offset(c.char.grapheme, data), c.char.width, @intFromBool(c.default), @intFromBool(c.wrapped), color(c.style.fg), color(c.style.bg), color(c.style.ul), @intFromEnum(c.style.ul_style), flags(c.style) });
    try hex(out, c.link.uri);
    try out.print(",{d},", .{offset(c.link.uri, data)});
    try hex(out, c.link.params);
    try out.print(",{d},{d},{d},{d},{d},", .{ offset(c.link.params, data), c.scale.scale, c.scale.numerator, c.scale.denominator, @intFromEnum(c.scale.vertical_alignment) });
    if (c.image) |img| {
        const opts = img.options;
        try out.print("I{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d};", .{ img.img_id, opts.pixel_offset.?.x, opts.pixel_offset.?.y, opts.z_index.?, opts.clip_region.?.x.?, @intFromBool(opts.clip_region.?.y != null), @intFromBool(opts.clip_region.?.width != null), opts.clip_region.?.height.?, @intFromEnum(opts.scale), @intFromBool(opts.size.?.rows != null), opts.size.?.cols.?, @intFromBool(opts.size != null), @intFromBool(opts.clip_region != null) });
    } else try out.writeAll("-;");
}
fn state(out: *W, s: *const vx.Screen, data: []const u8) !void {
    try out.print("{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}|", .{ s.width, s.height, s.width_pix, s.height_pix, s.buf.len, s.cursor_col, s.cursor_row, @intFromBool(s.cursor_vis), @intFromEnum(s.width_method), @intFromEnum(s.mouse_shape), @intFromEnum(s.cursor_shape) });
    for (s.buf) |c| try cellValue(out, c, data);
}
fn record(out: *W, line: []const u8, index: usize) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var split = std.mem.splitScalar(u8, line, '|');
    var parts: [16][]const u8 = undefined;
    var len: usize = 0;
    while (split.next()) |p| {
        parts[len] = p;
        len += 1;
    }
    const p = parts[0..len];
    var data = [_]u8{ 'a', 'b', 'c', 'U', 'R', 'I', 'i', 'd', '0' };
    var screen: vx.Screen = .{};
    var read: ?vx.Cell = null;
    if (std.mem.eql(u8, p[0], "D")) {
        // Public default construction does not allocate.
    } else if (std.mem.eql(u8, p[0], "N")) {
        screen = try vx.Screen.init(a, .{ .cols = try number(p, 1), .rows = try number(p, 2), .x_pixel = try number(p, 3), .y_pixel = try number(p, 4) });
    } else {
        const n: u8 = @intCast(try number(p, 9));
        const meta = try number(p, 11);
        const backing = try a.alloc(vx.Cell, try number(p, 3));
        for (backing, 0..) |*c, i| c.* = cell(&data, @truncate(i + 3));
        screen = .{ .width = try number(p, 1), .height = try number(p, 2), .buf = backing, .width_pix = meta * 257, .height_pix = 65535 - meta * 257, .cursor_col = meta * 257, .cursor_row = 65535 - meta * 257, .cursor_vis = meta & 1 != 0, .width_method = @enumFromInt(meta % 3), .mouse_shape = @enumFromInt(meta % 9), .cursor_shape = @enumFromInt(meta % 7) };
        if (!std.mem.eql(u8, p[0], "R")) screen.writeCell(try number(p, 4), try number(p, 5), cell(&data, n));
        if (!std.mem.eql(u8, p[0], "W")) read = screen.readCell(try number(p, 6), try number(p, 7));
    }
    try out.print("{d}|", .{index});
    try state(out, &screen, &data);
    try out.writeByte('|');
    if (read) |c| try cellValue(out, c, &data) else try out.writeByte('-');
    if (!std.mem.eql(u8, p[0], "N") and !std.mem.eql(u8, p[0], "D")) {
        if (try number(p, 10) != 0) {
            data[0] = 'X';
            data[3] = 'Y';
            data[6] = 'Z';
        }
        try out.writeByte('|');
        try state(out, &screen, &data);
        try out.writeByte('|');
        if (read) |c| try cellValue(out, c, &data) else try out.writeByte('-');
        if (try number(p, 8) != 0) screen.clear();
        try out.writeByte('|');
        try state(out, &screen, &data);
    }
    try out.writeByte('\n');
    screen.deinit(a);
}
pub fn main() !void {
    const a = std.heap.c_allocator;
    const args = try std.process.argsAlloc(a);
    const data = try std.fs.cwd().readFileAlloc(a, args[1], 1024 * 1024);
    var buffer: [65536]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&buffer);
    const out = &stdout.interface;
    var lines = std.mem.splitScalar(u8, data, '\n');
    var i: usize = 0;
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        try record(out, line, i);
        try out.flush();
        i += 1;
    }
}
