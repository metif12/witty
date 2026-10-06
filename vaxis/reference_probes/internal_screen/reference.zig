const std = @import("std");
const vx = @import("vaxis");
const W = std.Io.Writer;
// Fixture-only observation; original default panic still supplies diagnostics.
pub const panic = std.debug.FullPanic(observePanic);
var observed_screen: ?*const vx.AllocatingScreen = null;
var observed_path: ?[]const u8 = null;
fn observePanic(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| {
        if (observed_screen) |screen| {
            if (std.fs.cwd().createFile(path, .{})) |file| {
                defer file.close();
                var buffer: [4096]u8 = undefined;
                var writer = file.writer(&buffer);
                state(&writer.interface, screen, "abcURIid0", .{}) catch {};
                writer.interface.flush() catch {};
            } else |_| {}
        }
    }
    std.debug.defaultPanic(message, address);
}
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
fn internalValue(out: *W, c: vx.AllocatingScreen.InternalCell, data: []const u8, incoming: vx.Cell) !void {
    try cellValue(out, .{ .char = .{ .grapheme = c.char.items }, .style = c.style, .link = .{ .uri = c.uri.items, .params = c.uri_id.items }, .default = c.default, .scale = c.scale }, data);
    var ignored = incoming;
    ignored.char.width = 255;
    ignored.image = null;
    ignored.wrapped = !incoming.wrapped;
    ignored.scale = .{ .scale = 7, .numerator = 0, .denominator = 0, .vertical_alignment = .center };
    try out.print("{d},{d},{d},{d};", .{ @intFromBool(c.skipped), @intFromBool(c.skip), @intFromBool(c.eql(incoming)), @intFromBool(c.eql(ignored)) });
}
fn state(out: *W, s: *const vx.AllocatingScreen, data: []const u8, incoming: vx.Cell) !void {
    try out.print("{d},{d},{d},{d},{d},{d},{d},{d}|", .{ s.width, s.height, s.buf.len, s.cursor_col, s.cursor_row, @intFromBool(s.cursor_vis), @intFromEnum(s.mouse_shape), @intFromEnum(s.cursor_shape) });
    for (s.buf) |c| try internalValue(out, c, data, incoming);
}
fn fitRecord(out: *W, p: []const []const u8, data: []const u8) !void {
    const a = std.heap.c_allocator;
    const field = try number(p, 1);
    const first = try number(p, 2);
    const second = try number(p, 3);
    var s = try vx.AllocatingScreen.init(a, 1, 1);
    defer s.deinit(a);
    const first_text = try a.alloc(u8, first);
    defer a.free(first_text);
    @memset(first_text, 'a');
    const second_text = try a.alloc(u8, second);
    defer a.free(second_text);
    @memset(second_text, 'b');
    s.writeCell(0, 0, .{ .char = .{ .grapheme = if (field == 0) first_text else "C" }, .link = .{ .uri = if (field == 1) first_text else "U", .params = if (field == 2) first_text else "I" } });
    const old = s.readCell(0, 0).?;
    s.writeCell(0, 0, .{ .char = .{ .grapheme = if (field == 0) second_text else "D" }, .link = .{ .uri = if (field == 1) second_text else "V", .params = if (field == 2) second_text else "J" } });
    const current = s.readCell(0, 0).?;
    try cellValue(out, old, data);
    try out.writeByte('|');
    try cellValue(out, current, data);
    try out.print("|{d},{d},{d}", .{ @intFromBool(old.char.grapheme.ptr == current.char.grapheme.ptr), @intFromBool(old.link.uri.ptr == current.link.uri.ptr), @intFromBool(old.link.params.ptr == current.link.params.ptr) });
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
    if (std.mem.eql(u8, p[0], "F")) {
        try out.print("{d}|", .{index});
        try fitRecord(out, p, &data);
        try out.writeByte('\n');
        return;
    }
    if (std.mem.eql(u8, p[0], "E")) {
        try out.print("{d}|", .{index});
        try internalValue(out, .{}, &data, cell(&data, @intCast(try number(p, 1))));
        try out.writeByte('\n');
        return;
    }
    var screen = try vx.AllocatingScreen.init(a, if (std.mem.eql(u8, p[0], "N") or std.mem.eql(u8, p[0], "P")) try number(p, 1) else try number(p, 3), if (std.mem.eql(u8, p[0], "N") or std.mem.eql(u8, p[0], "P")) try number(p, 2) else 1);
    defer screen.deinit(a);
    var read: ?vx.Cell = null;
    var incoming = cell(&data, 0);
    if (!std.mem.eql(u8, p[0], "N") and !std.mem.eql(u8, p[0], "P")) {
        for (screen.buf, 0..) |*c, i| {
            screen.writeCell(@intCast(i), 0, cell(&data, @truncate(i + 3)));
            c.skipped = i % 2 == 0;
            c.skip = i % 3 == 0;
            c.scale = .{ .scale = @intCast(i % 8), .numerator = @intCast(i % 16), .denominator = @intCast((i + 1) % 16), .vertical_alignment = @enumFromInt(i % 3) };
        }
        const n: u8 = @intCast(try number(p, 9));
        const meta = try number(p, 11);
        incoming = cell(&data, n);
        screen.width = try number(p, 1);
        screen.height = try number(p, 2);
        screen.cursor_col = meta * 257;
        screen.cursor_row = 65535 - meta * 257;
        screen.cursor_vis = meta & 1 != 0;
        screen.mouse_shape = @enumFromInt(meta % 9);
        screen.cursor_shape = @enumFromInt(meta % 7);
        if (!std.mem.eql(u8, p[0], "R")) screen.writeCell(try number(p, 4), try number(p, 5), incoming);
        if (!std.mem.eql(u8, p[0], "W")) read = screen.readCell(try number(p, 6), try number(p, 7));
    }
    if (std.mem.eql(u8, p[0], "P")) read = screen.readCell(0, 0);
    try out.print("{d}|", .{index});
    try state(out, &screen, &data, incoming);
    try out.writeByte('|');
    if (read) |c| try cellValue(out, c, &data) else try out.writeByte('-');
    if (!std.mem.eql(u8, p[0], "N")) {
        if (try number(p, 10) != 0) {
            data[0] = 'X';
            data[3] = 'Y';
            data[6] = 'Z';
        }
        if (std.mem.eql(u8, p[0], "B") or std.mem.eql(u8, p[0], "P")) {
            if (read) |c| {
                if (c.char.grapheme.len > 0) @constCast(c.char.grapheme)[0] = 'Q';
                if (c.link.uri.len > 0) @constCast(c.link.uri)[0] = 'R';
                if (c.link.params.len > 0) @constCast(c.link.params)[0] = 'S';
            }
        }
        try out.writeByte('|');
        try state(out, &screen, &data, incoming);
        try out.writeByte('|');
        if (read) |c| try cellValue(out, c, &data) else try out.writeByte('-');
    }
    try out.writeByte('\n');
}
fn aliasCase(label: []const u8, path: ?[]const u8) !void {
    const a = std.heap.c_allocator;
    var s = try vx.AllocatingScreen.init(a, 1, 1);
    defer s.deinit(a);
    s.writeCell(0, 0, .{ .char = .{ .grapheme = "abc" }, .link = .{ .uri = "URI", .params = "id0" } });
    s.buf[0].skip = true;
    s.buf[0].skipped = true;
    observed_screen = &s;
    observed_path = path;
    var value = s.readCell(0, 0).?;
    value.style = .{ .italic = true };
    value.default = true;
    if (std.mem.eql(u8, label, "alias_uri") or std.mem.eql(u8, label, "alias_id")) value.char.grapheme = "NEW";
    if (std.mem.eql(u8, label, "alias_uri")) value.link.uri = value.link.uri[1..];
    if (std.mem.eql(u8, label, "alias_id")) {
        value.link.uri = "NEW_URI";
        value.link.params = value.link.params[1..];
    }
    if (std.mem.eql(u8, label, "alias_partial")) value.char.grapheme = value.char.grapheme[1..];
    s.writeCell(0, 0, value);
    var buffer: [128]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&buffer);
    try stdout.interface.writeAll("UNEXPECTED: alias returned\n");
    try stdout.interface.flush();
}
fn boundaryCase(label: []const u8) !void {
    var output_buffer: [256]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&output_buffer);
    const out = &stdout.interface;
    if (std.mem.eql(u8, label, "alloc_init")) {
        var buffer: [0]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buffer);
        var s = vx.AllocatingScreen.init(fba.allocator(), 1, 1) catch |err| {
            try out.print("INIT_ERROR: {s}\n", .{@errorName(err)});
            try out.flush();
            return;
        };
        s.deinit(fba.allocator());
        try out.writeAll("UNEXPECTED: init succeeded\n");
        try out.flush();
        return;
    }
    if (std.mem.eql(u8, label, "alloc_write")) {
        var buffer: [4096]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buffer);
        const a = fba.allocator();
        var s = try vx.AllocatingScreen.init(a, 1, 1);
        defer s.deinit(a);
        const text = [_]u8{'a'} ** 8192;
        s.writeCell(0, 0, .{ .char = .{ .grapheme = &text }, .link = .{ .uri = "URI", .params = "id0" }, .style = .{ .bold = true }, .default = true });
        const c = s.readCell(0, 0).?;
        try out.print("WRITE: {d},{s},{s},{d},{d}\n", .{ c.char.grapheme.len, c.link.uri, c.link.params, @intFromBool(c.style.bold), @intFromBool(c.default) });
        try out.flush();
        return;
    }
    const a = std.heap.c_allocator;
    var s = try vx.AllocatingScreen.init(a, 1, 1);
    defer s.deinit(a);
    s.writeCell(0, 0, .{ .char = .{ .grapheme = "abc" } });
    const old = s.readCell(0, 0).?;
    s.writeCell(0, 0, .{ .char = .{ .grapheme = "def" } });
    const current = s.readCell(0, 0).?;
    try out.print("BORROW: {s}|{s}\n", .{ old.char.grapheme, current.char.grapheme });
    try out.flush();
}
pub fn main() !void {
    const a = std.heap.c_allocator;
    const args = try std.process.argsAlloc(a);
    if (std.mem.eql(u8, args[1], "old_view") or std.mem.eql(u8, args[1], "alloc_init") or std.mem.eql(u8, args[1], "alloc_write")) {
        try boundaryCase(args[1]);
        return;
    }
    if (std.mem.startsWith(u8, args[1], "alias_")) {
        try aliasCase(args[1], if (args.len > 2) args[2] else null);
        return;
    }
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
