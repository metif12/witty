const std = @import("std");
const v = @import("vaxis");
const a = std.heap.page_allocator;

// Fixture-only observation of the state at an ordinary checked panic. All
// dependency bodies remain unchanged, and defaultPanic supplies diagnostics.
pub const panic = std.debug.FullPanic(observePanic);
var observed_screen: ?*const v.Screen = null;
var observed_glyphs: [6][]const u8 = @splat("");
var observed_path: ?[]const u8 = null;

fn observePanic(message: []const u8, return_address: ?usize) noreturn {
    if (observed_path) |path| {
        if (observed_screen) |screen| {
            if (std.fs.cwd().createFile(path, .{})) |file| {
                defer file.close();
                var bytes: [128]u8 = undefined;
                var writer = file.writer(&bytes);
                writer.interface.print("{x}\n", .{bufferHash(screen.buf, &observed_glyphs, true)}) catch {};
                writer.interface.flush() catch {};
            } else |_| {}
        }
    }
    std.debug.defaultPanic(message, return_address);
}

fn style(index: usize) v.Style {
    return switch (index) {
        0 => .{},
        1 => .{ .fg = .{ .index = 9 }, .bg = .{ .rgb = .{ 1, 2, 3 } }, .ul = .{ .index = 7 }, .ul_style = .dashed, .bold = true, .dim = true, .italic = true, .blink = true, .reverse = true, .invisible = true, .strikethrough = true },
        2 => .{ .fg = .{ .rgb = .{ 251, 129, 3 } }, .bg = .{ .index = 17 }, .ul = .{ .rgb = .{ 7, 8, 9 } }, .ul_style = .curly, .italic = true },
        3 => .{ .bg = .{ .index = 2 }, .reverse = true },
        else => unreachable,
    };
}
fn seed() v.Cell {
    return .{ .char = .{ .grapheme = "o", .width = 3 }, .style = style(3), .link = .{ .uri = "old", .params = "id=old" }, .default = true, .wrapped = true, .scale = .{ .scale = 2, .numerator = 3, .denominator = 4, .vertical_alignment = .bottom } };
}
fn mix(hash: u64, byte: u8) u64 {
    return (hash ^ byte) *% 1099511628211;
}
fn mixNumber(hash: u64, number: u64) u64 {
    var result = hash;
    for (0..8) |index| result = mix(result, @truncate(number >> @as(u6, @intCast(index * 8))));
    return result;
}
fn mixBytes(hash: u64, bytes: []const u8) u64 {
    var result = mixNumber(hash, bytes.len);
    for (bytes) |byte| result = mix(result, byte);
    return result;
}
fn bufferHash(cells: []const v.Cell, glyphs: *const [6][]const u8, custom: bool) u64 {
    var hash = mixNumber(14695981039346656037, cells.len);
    for (cells) |*cell| {
        hash = mixBytes(hash, cell.char.grapheme);
        hash = mix(hash, cell.char.width);
        var style_id: u8 = 255;
        for (0..4) |index| if (v.Style.eql(cell.style, style(index))) {
            style_id = @intCast(index);
            break;
        };
        hash = mix(hash, style_id);
        hash = mixBytes(hash, cell.link.uri);
        hash = mixBytes(hash, cell.link.params);
        hash = mix(hash, @intFromBool(cell.default));
        hash = mix(hash, @intFromBool(cell.wrapped));
        hash = mix(hash, @intFromBool(cell.image != null));
        hash = mix(hash, cell.scale.scale);
        hash = mix(hash, cell.scale.numerator);
        hash = mix(hash, cell.scale.denominator);
        hash = mix(hash, @intFromEnum(cell.scale.vertical_alignment));
        var glyph_id: u8 = 255;
        if (custom and cell.char.grapheme.len > 0) {
            for (glyphs, 0..) |glyph, index| if (glyph.len == cell.char.grapheme.len and glyph.ptr == cell.char.grapheme.ptr) {
                glyph_id = @intCast(index);
                break;
            };
        }
        hash = mix(hash, glyph_id);
    }
    return hash;
}
fn location(index: usize) v.Window.BorderOptions {
    return switch (index) {
        0 => .{ .where = .none },
        1 => .{ .where = .all },
        2 => .{ .where = .top },
        3 => .{ .where = .right },
        4 => .{ .where = .bottom },
        5 => .{ .where = .left },
        else => .{ .where = .{ .other = .{ .top = ((index - 6) & 1) != 0, .right = ((index - 6) & 2) != 0, .bottom = ((index - 6) & 4) != 0, .left = ((index - 6) & 8) != 0 } } },
    };
}
fn window(screen: *v.Screen, width: u16, height: u16, x: i17, y: i17, px: i17, py: i17) v.Window {
    return .{ .width = width, .height = height, .x_off = x, .y_off = y, .parent_x_off = px, .parent_y_off = py, .screen = screen };
}
fn trap(name: []const u8, path: []const u8) !void {
    const storage = try a.alloc(v.Cell, 8);
    @memset(storage, seed());
    var screen: v.Screen = .{ .width = 4, .height = 2, .buf = storage };
    var w = window(&screen, 4, 2, 0, 0, 0, 0);
    var opts: v.Window.ChildOptions = .{ .border = .{ .where = .all } };
    observed_glyphs = .{ "A", "H", "B", "V", "C", "D" };
    opts.border.glyphs = .{ .custom = observed_glyphs };
    if (std.mem.eql(u8, name, "trap_init_width")) {
        w.width = 65535;
        opts.x_off = -1;
    } else if (std.mem.eql(u8, name, "trap_init_height")) {
        w.height = 65535;
        opts.y_off = -1;
    } else if (std.mem.eql(u8, name, "trap_init_x")) {
        w.x_off = 65535;
        opts.x_off = 1;
    } else if (std.mem.eql(u8, name, "trap_init_y")) {
        w.y_off = 65535;
        opts.y_off = 1;
    } else if (std.mem.eql(u8, name, "trap_init_parent_x")) {
        w.parent_x_off = -65536;
        opts.x_off = -1;
    } else if (std.mem.eql(u8, name, "trap_init_parent_y")) {
        w.parent_y_off = -65536;
        opts.y_off = -1;
    } else if (std.mem.eql(u8, name, "trap_top_x")) {
        w.x_off = 65535;
        opts.border.where = .top;
    } else if (std.mem.eql(u8, name, "trap_bottom_y")) {
        w.y_off = 65535;
        opts.border.where = .bottom;
    } else if (std.mem.eql(u8, name, "trap_left_y")) {
        w.y_off = 65535;
        opts.border.where = .left;
    } else if (std.mem.eql(u8, name, "trap_right_x")) {
        w.x_off = 65535;
        opts.border.where = .right;
    } else if (std.mem.eql(u8, name, "trap_inner_x")) {
        w.x_off = 65535;
        w.width = 0;
        w.height = 0;
        opts.border.where = .left;
    } else if (std.mem.eql(u8, name, "trap_inner_y")) {
        w.y_off = 65535;
        w.width = 0;
        w.height = 0;
        opts.border.where = .top;
    } else if (std.mem.eql(u8, name, "trap_top_bottom_order")) {
        screen.buf = storage[0..4];
        opts.border.where = .{ .other = .{ .top = true, .bottom = true } };
    } else if (std.mem.eql(u8, name, "trap_left_right_order")) {
        screen.width = 2;
        screen.height = 3;
        screen.buf = storage[0..2];
        w.width = 2;
        w.height = 3;
        opts.border.where = .{ .other = .{ .left = true, .right = true } };
    } else if (std.mem.eql(u8, name, "trap_empty_buffer")) {
        screen.buf = storage[0..0];
        opts.border.where = .top;
    } else if (std.mem.eql(u8, name, "trap_large_index")) {
        screen.width = 65535;
        screen.height = 65535;
        screen.buf = storage[0..1];
        w.width = 1;
        w.height = 1;
        w.y_off = 32769;
        opts.border.where = .top;
    } else return error.InvalidTrap;
    observed_screen = &screen;
    observed_path = path;
    _ = w.child(opts);
    var bytes: [64]u8 = undefined;
    var out = std.fs.File.stdout().writer(&bytes);
    try out.interface.writeAll("UNEXPECTED\n");
    try out.interface.flush();
}
fn n(parts: []const []const u8, index: usize) !i32 {
    return std.fmt.parseInt(i32, parts[index], 10);
}
fn u(parts: []const []const u8, index: usize) !u16 {
    return @intCast(try n(parts, index));
}
fn optional(parts: []const []const u8, index: usize) !?u16 {
    const value = try n(parts, index);
    return if (value < 0) null else @intCast(value);
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    if (std.mem.startsWith(u8, args[1], "trap_")) return trap(args[1], args[2]);
    const input = try std.fs.cwd().readFileAlloc(a, args[1], 64 * 1024 * 1024);
    var out_bytes: [65536]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&out_bytes);
    const out = &stdout.interface;
    var lines = std.mem.splitScalar(u8, input, '\n');
    var number: usize = 0;
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var fields = std.mem.splitScalar(u8, line, '|');
        var parts: [17][]const u8 = undefined;
        for (&parts) |*part| part.* = fields.next() orelse return error.InvalidCase;
        const length = try n(&parts, 2);
        var screen: v.Screen = .{ .width = try u(&parts, 0), .height = try u(&parts, 1) };
        const size: usize = if (length < 0) @as(usize, screen.width) * screen.height else @intCast(length);
        const cells = try a.alloc(v.Cell, size);
        defer a.free(cells);
        @memset(cells, seed());
        screen.buf = cells;
        const w = window(&screen, try u(&parts, 3), try u(&parts, 4), @intCast(try n(&parts, 5)), @intCast(try n(&parts, 6)), @intCast(try n(&parts, 7)), @intCast(try n(&parts, 8)));
        const glyph_mode = try n(&parts, 14);
        const glyphs: [6][]const u8 = if (glyph_mode == 3) .{ "", "wide界", "\x00", "\xff\x1b", "e\u{301}", "end" } else .{ "A", "H", "B", "V", "C", "D" };
        var owned: [6][]u8 = undefined;
        defer for (owned) |bytes| a.free(bytes);
        var borrowed: [6][]const u8 = undefined;
        for (glyphs, 0..) |bytes, i| {
            owned[i] = try a.dupe(u8, bytes);
            borrowed[i] = owned[i];
        }
        var border = location(@intCast(try n(&parts, 13)));
        border.style = style(@intCast(try n(&parts, 15)));
        border.glyphs = switch (glyph_mode) {
            0 => .single_rounded,
            1 => .single_square,
            else => .{ .custom = borrowed },
        };
        var opts: v.Window.ChildOptions = .{ .x_off = @intCast(try n(&parts, 9)), .y_off = @intCast(try n(&parts, 10)), .width = try optional(&parts, 11), .height = try optional(&parts, 12), .border = border };
        const result = w.child(opts);
        const before = bufferHash(cells, &borrowed, glyph_mode >= 2);
        if (try n(&parts, 16) != 0) {
            for (owned) |bytes| @memset(bytes, 'Z');
            opts.border.style = style(3);
        }
        const after = bufferHash(cells, &borrowed, glyph_mode >= 2);
        try out.print("{d}|{d},{d},{d},{d},{d},{d},{d}|{x}|{x}\n", .{ number, result.width, result.height, result.x_off, result.y_off, result.parent_x_off, result.parent_y_off, @intFromBool(result.screen == &screen), before, after });
        number += 1;
        try out.flush();
    }
}
