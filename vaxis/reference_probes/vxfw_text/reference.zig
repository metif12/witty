const std = @import("std");
const vx = @import("vaxis");
const fw = vx.vxfw;
const W = std.Io.Writer;
fn number(p: []const []const u8, i: usize) !i64 {
    return std.fmt.parseInt(i64, p[i], 10);
}
fn hex(out: *W, bytes: []const u8) !void {
    for (bytes) |b| try out.print("{x:0>2}", .{b});
}
fn flags(s: vx.Style) u8 {
    return @as(u8, @intFromBool(s.bold)) | (@as(u8, @intFromBool(s.dim)) << 1) | (@as(u8, @intFromBool(s.italic)) << 2) | (@as(u8, @intFromBool(s.blink)) << 3) | (@as(u8, @intFromBool(s.reverse)) << 4) | (@as(u8, @intFromBool(s.invisible)) << 5) | (@as(u8, @intFromBool(s.strikethrough)) << 6);
}
fn color(c: vx.Color) i16 {
    return switch (c) {
        .default => -1,
        .index => |i| i,
        .rgb => -2,
    };
}
fn cells(out: *W, surface: fw.Surface, input: []u8) !void {
    for (surface.buffer) |c| {
        try hex(out, c.char.grapheme);
        const pointer = @intFromPtr(c.char.grapheme.ptr);
        const base = @intFromPtr(input.ptr);
        const offset: i64 = if (pointer >= base and pointer <= base + input.len and c.char.grapheme.len <= base + input.len - pointer) @intCast(pointer - base) else -1;
        try out.print(",{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d};", .{ offset, c.char.width, color(c.style.fg), color(c.style.bg), color(c.style.ul), @intFromEnum(c.style.ul_style), flags(c.style), @intFromBool(c.default), @intFromBool(c.wrapped), c.link.uri.len, c.link.params.len, @intFromBool(c.image != null), c.scale.scale, c.scale.numerator, c.scale.denominator });
    }
}
fn record(out: *W, line: []const u8, index: usize) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var split = std.mem.splitScalar(u8, line, '|');
    var fields: [16][]const u8 = undefined;
    var n: usize = 0;
    while (split.next()) |field| {
        fields[n] = field;
        n += 1;
    }
    const p = fields[0..n];
    const data = try a.alloc(u8, p[0].len / 2);
    _ = try std.fmt.hexToBytes(data, p[0]);
    fw.DrawContext.init(@enumFromInt(try number(p, 1)));
    const text: fw.Text = .{ .text = data, .softwrap = try number(p, 2) != 0, .text_align = @enumFromInt(try number(p, 3)), .overflow = @enumFromInt(try number(p, 4)), .width_basis = if (try number(p, 5) == 0) .longest_line else .parent, .style = if (try number(p, 10) != 0) .{ .fg = .{ .index = 4 }, .bg = .{ .index = 5 }, .ul = .{ .index = 6 }, .ul_style = .curly, .bold = true, .dim = true, .italic = true, .blink = true, .reverse = true, .invisible = true, .strikethrough = true } else .{} };
    const ctx: fw.DrawContext = .{ .arena = a, .min = .{ .width = @intCast(try number(p, 6)), .height = @intCast(try number(p, 7)) }, .max = .{ .width = if (try number(p, 8) < 0) null else @intCast(try number(p, 8)), .height = if (try number(p, 9) < 0) null else @intCast(try number(p, 9)) }, .cell_size = .{} };
    const surface = if (try number(p, 11) == 0) try text.draw(ctx) else try text.widget().draw(ctx);
    try out.print("{d}|{d},{d},{d},{d},{d},{d}|", .{ index, surface.size.width, surface.size.height, surface.buffer.len, surface.children.len, @intFromBool(surface.cursor != null), @intFromBool(surface.widget.eql(text.widget())) });
    try cells(out, surface, data);
    if (p.len > 12 and p[12].len > 0) {
        var changes = std.mem.splitScalar(u8, p[12], ',');
        while (changes.next()) |change| {
            var pair = std.mem.splitScalar(u8, change, ':');
            const i = try std.fmt.parseInt(usize, pair.next().?, 10);
            data[i] = try std.fmt.parseInt(u8, pair.next().?, 16);
        }
        try out.writeByte('|');
        try cells(out, surface, data);
    }
    try out.writeByte('\n');
}
pub fn main() !void {
    const a = std.heap.c_allocator;
    const args = try std.process.argsAlloc(a);
    const data = try std.fs.cwd().readFileAlloc(a, args[1], 32 * 1024 * 1024);
    var buffer: [65536]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&buffer);
    const out = &stdout.interface;
    var lines = std.mem.splitScalar(u8, data, '\n');
    var index: usize = 0;
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        try record(out, line, index);
        try out.flush();
        index += 1;
    }
    try out.flush();
}
