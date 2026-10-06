const std = @import("std");
const v = @import("vaxis");
const W = std.Io.Writer;
extern "c" fn setenv([*:0]const u8, [*:0]const u8, c_int) c_int;
extern "c" fn unsetenv([*:0]const u8) c_int;
pub const std_options: std.Options = .{ .log_level = .err };
pub const panic = std.debug.FullPanic(observePanic);
var observed: ?*const v.Vaxis = null;
var observed_path: ?[]const u8 = null;
fn observePanic(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| if (observed) |vx| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var bytes: [256]u8 = undefined;
            var writer = file.writer(&bytes);
            state(&writer.interface, vx) catch {};
            writer.interface.flush() catch {};
        } else |_| {}
    };
    std.debug.defaultPanic(message, address);
}
fn number(p: []const []const u8, i: usize) !u16 {
    return std.fmt.parseInt(u16, p[i], 10);
}
fn decode(a: std.mem.Allocator, text: []const u8) ![]u8 {
    const bytes = try a.alloc(u8, text.len / 2);
    _ = try std.fmt.hexToBytes(bytes, text);
    return bytes;
}
fn hex(out: *W, bytes: []const u8) !void {
    for (bytes) |b| try out.print("{x:0>2}", .{b});
}
fn hn(value: u64, number_: u64) u64 {
    var h = value;
    for (0..8) |n| h = (h ^ @as(u8, @truncate(number_ >> @intCast(n * 8)))) *% 1099511628211;
    return h;
}
fn hs(value: u64, bytes: []const u8) u64 {
    var h = hn(value, bytes.len);
    for (bytes) |b| h = (h ^ b) *% 1099511628211;
    return h;
}
fn color(c: v.Cell.Color) u32 {
    return switch (c) {
        .default => 0,
        .index => |n| 0x1000000 + @as(u32, n),
        .rgb => |r| 0x2000000 + (@as(u32, r[0]) << 16) + (@as(u32, r[1]) << 8) + r[2],
    };
}
fn styleHash(value: u64, s: v.Style) u64 {
    var h = hn(hn(hn(value, color(s.fg)), color(s.bg)), color(s.ul));
    h = hn(h, @intFromEnum(s.ul_style));
    for ([_]bool{ s.bold, s.dim, s.italic, s.blink, s.reverse, s.invisible, s.strikethrough }) |b| h = hn(h, @intFromBool(b));
    return h;
}
fn state(out: *W, vx: *const v.Vaxis) !void {
    var h: u64 = 14695981039346656037;
    for (vx.screen_last.buf) |c| {
        h = styleHash(hs(hs(hs(h, c.char.items), c.uri.items), c.uri_id.items), c.style);
        h = hn(hn(hn(hn(h, @intFromBool(c.skipped)), @intFromBool(c.skip)), @intFromBool(c.default)), @as(u13, @bitCast(c.scale)));
    }
    try out.print("{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}", .{ @intFromBool(vx.refresh), vx.state.cursor.row, vx.state.cursor.col, @intFromEnum(vx.screen_last.mouse_shape), @intFromEnum(vx.screen_last.cursor_shape), vx.screen_last.width, vx.screen_last.height, vx.screen_last.buf.len, h, @intFromEnum(vx.caps.unicode), @intFromEnum(vx.sgr) });
}
fn cell(i: usize, pattern: u16, seed: u16, text: []const u8, width: u8) v.Cell {
    if (pattern == 0 or (pattern == 4 or pattern == 6) and i > 0) return .{ .default = true };
    const n: u8 = @truncate(@as(usize, seed) + i);
    var c: v.Cell = .{ .char = .{ .grapheme = text, .width = width }, .default = pattern == 2 and n % 3 == 0, .wrapped = pattern == 3 or n % 5 == 0, .style = .{ .fg = switch (n % 4) {
        0 => .default,
        1 => .{ .index = n % 16 },
        2 => .{ .index = n },
        else => .{ .rgb = .{ n, n ^ 0xaa, 255 - n } },
    }, .bg = .{ .rgb = .{ 255 - n, n, n ^ 0x55 } }, .ul = if (n % 2 == 0) .{ .index = n } else .{ .rgb = .{ n, 255 - n, n } }, .ul_style = @enumFromInt(n % 6), .bold = n & 1 != 0, .dim = n & 2 != 0, .italic = n & 4 != 0, .blink = n & 8 != 0, .reverse = n & 16 != 0, .invisible = n & 32 != 0, .strikethrough = n & 64 != 0 }, .link = if (n % 3 == 0) .{} else .{ .uri = if (n % 3 == 1) "u:one" else "u:two", .params = if (n % 2 == 0) "id=a" else "id=b" } };
    if (pattern == 4) c.scale = .{ .scale = 2 };
    if (pattern == 5) c.scale = .{ .scale = @intCast(n % 2), .numerator = @intCast(n % 15 + 1), .denominator = @intCast((n +% 3) % 15 + 1), .vertical_alignment = @enumFromInt(n % 3) };
    if (pattern == 6) c.image = .{ .img_id = @as(u32, seed) + 1, .options = .{ .pixel_offset = .{ .x = seed, .y = 65535 - seed }, .z_index = -@as(i32, seed), .clip_region = .{ .x = seed, .height = 65535 }, .size = .{ .rows = 1, .cols = 2 } } };
    return c;
}
fn record(out: *W, p: []const []const u8, id: usize) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var vx = try v.init(a, .{});
    try out.print("{d}|", .{id});
    if (p[0][0] == 'U') {
        const path = try decode(a, p[1]);
        if (std.mem.eql(u8, p[2], "-")) {
            _ = unsetenv("HOSTNAME");
        } else {
            _ = setenv("HOSTNAME", try a.dupeZ(u8, try decode(a, p[2])), 1);
        }
        var bytes = W.Allocating.init(a);
        vx.setTerminalWorkingDirectory(&bytes.writer, path) catch |err| {
            try out.print("E{s}\n", .{@errorName(err)});
            return;
        };
        try hex(out, bytes.written());
    } else if (p[0][0] == 'M') {
        vx.screen.width = try number(p, 1);
        vx.screen.height = try number(p, 2);
        vx.screen.width_pix = try number(p, 3);
        vx.screen.height_pix = try number(p, 4);
        vx.state.pixel_mouse = try number(p, 5) != 0;
        const m = vx.translateMouse(.{ .col = try number(p, 6), .row = try number(p, 7), .xoffset = try number(p, 8), .yoffset = try number(p, 9), .button = @enumFromInt(try number(p, 10)), .type = @enumFromInt(try number(p, 11)), .mods = @bitCast(@as(u3, @intCast(try number(p, 12)))) });
        try out.print("{d},{d},{d},{d},{d},{d},{d}", .{ m.col, m.row, m.xoffset, m.yoffset, @intFromEnum(m.button), @intFromEnum(m.type), @as(u3, @bitCast(m.mods)) });
    } else {
        const w = try number(p, 1);
        const h = try number(p, 2);
        const pattern = try number(p, 3);
        const seed = try number(p, 4);
        const flags = try number(p, 5);
        const text = try decode(a, p[10]);
        const width: u8 = @intCast(try number(p, 11));
        vx.screen = try v.Screen.init(a, .{ .cols = w, .rows = h, .x_pixel = 0, .y_pixel = 0 });
        vx.screen_last = try v.AllocatingScreen.init(a, w, h);
        vx.state.alt_screen = flags & 1 != 0;
        vx.refresh = flags & 2 != 0;
        vx.caps.kitty_graphics = flags & 4 != 0;
        vx.caps.explicit_width = flags & 8 != 0;
        vx.caps.scaled_text = flags & 16 != 0;
        vx.sgr = if (flags & 32 != 0) .legacy else .standard;
        vx.enable_workarounds = flags & 64 == 0;
        vx.screen.cursor_vis = flags & 128 != 0;
        vx.caps.unicode = @enumFromInt(seed % 3);
        vx.screen.mouse_shape = @enumFromInt(try number(p, 6));
        vx.screen.cursor_shape = @enumFromInt(try number(p, 7));
        vx.screen.cursor_row = try number(p, 8);
        vx.screen.cursor_col = try number(p, 9);
        vx.state.cursor = .{ .row = seed % 3, .col = seed % 4 };
        for (vx.screen.buf, 0..) |*c, i| c.* = cell(i, pattern, seed, text, width);
        for (vx.screen_last.buf, 0..) |*c, i| {
            c.skipped = (i + seed) % 5 == 0;
            c.skip = (i + seed) % 7 == 0;
            c.scale = .{ .scale = @intCast(seed % 8), .numerator = @intCast(seed % 16), .denominator = @intCast((seed + 1) % 16) };
        }
        for (0..3) |frame| {
            if (frame == 2 and vx.screen.buf.len > 0) {
                vx.screen.buf[0].char.grapheme = "z";
                vx.screen.buf[0].char.width = 1;
                vx.screen.buf[0].style.bold = !vx.screen.buf[0].style.bold;
                vx.screen.buf[0].scale = .{};
                vx.screen.buf[0].image = null;
            }
            var bytes = W.Allocating.init(a);
            if (p[0][0] == 'P') vx.prettyPrint(&bytes.writer) catch |err| {
                try out.print("E{s}", .{@errorName(err)});
            } else try vx.render(&bytes.writer);
            try hex(out, bytes.written());
            try out.writeByte('/');
            try state(out, &vx);
            try out.writeByte('|');
        }
    }
    try out.writeByte('\n');
}
fn trap(name: []const u8, path: []const u8) !void {
    const a = std.heap.page_allocator;
    var vx = try v.init(a, .{});
    observed = &vx;
    observed_path = path;
    vx.refresh = true;
    var bytes = W.Allocating.init(a);
    if (std.mem.startsWith(u8, name, "mouse")) {
        vx.screen = .{ .width = 1, .height = 1 };
        vx.state.pixel_mouse = true;
        _ = vx.translateMouse(.{ .col = 0, .row = 0, .button = .none, .type = .motion, .mods = .{}, .xoffset = if (std.mem.eql(u8, name, "mouse_y")) 0 else 1, .yoffset = 1 });
    } else if (std.mem.eql(u8, name, "render_size")) {
        vx.screen.width = 65535;
        vx.screen.height = 65535;
        try vx.render(&bytes.writer);
    } else if (std.mem.eql(u8, name, "render_last")) {
        vx.screen = try v.Screen.init(a, .{ .cols = 1, .rows = 1, .x_pixel = 0, .y_pixel = 0 });
        try vx.render(&bytes.writer);
    } else if (std.mem.startsWith(u8, name, "cursor")) {
        vx.state.alt_screen = true;
        vx.screen.cursor_vis = true;
        vx.screen.cursor_col = if (std.mem.eql(u8, name, "cursor_col")) 65535 else 0;
        vx.screen.cursor_row = if (std.mem.eql(u8, name, "cursor_row")) 65535 else 0;
        try vx.render(&bytes.writer);
    } else if (std.mem.eql(u8, name, "pretty_index")) {
        vx.screen = try v.Screen.init(a, .{ .cols = 2, .rows = 32768, .x_pixel = 0, .y_pixel = 0 });
        for (vx.screen.buf) |*c| c.default = true;
        try vx.prettyPrint(&bytes.writer);
    } else if (std.mem.eql(u8, name, "render_col")) {
        vx.screen = try v.Screen.init(a, .{ .cols = 65535, .rows = 1, .x_pixel = 0, .y_pixel = 0 });
        vx.screen_last = try v.AllocatingScreen.init(a, 65535, 1);
        for (vx.screen.buf) |*c| c.* = .{ .char = .{ .grapheme = "x", .width = 250 } };
        try vx.render(&bytes.writer);
    } else {
        vx.screen = try v.Screen.init(a, .{ .cols = 300, .rows = 3, .x_pixel = 0, .y_pixel = 0 });
        vx.screen_last = try v.AllocatingScreen.init(a, 300, 3);
        vx.caps.scaled_text = true;
        vx.screen.buf[0] = .{ .char = .{ .grapheme = "X", .width = if (std.mem.eql(u8, name, "scaled_unknown")) 0 else if (std.mem.eql(u8, name, "scaled_overflow")) 100 else 1 }, .scale = .{ .scale = if (std.mem.eql(u8, name, "denominator")) 1 else 3, .denominator = if (std.mem.eql(u8, name, "denominator")) 0 else 1 } };
        if (std.mem.eql(u8, name, "scaled_bounds")) {
            vx.screen.buf[0].scale.scale = 2;
            vx.screen_last.width = 65535;
        }
        try vx.render(&bytes.writer);
    }
    @panic("UNEXPECTED returning trap");
}
pub fn main() !void {
    const a = std.heap.page_allocator;
    const args = try std.process.argsAlloc(a);
    if (args.len > 2 and std.mem.eql(u8, args[1], "--trap")) {
        try trap(args[2], args[3]);
        return;
    }
    const input = try std.fs.cwd().readFileAlloc(a, args[1], 128 * 1024 * 1024);
    var buffer: [65536]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&buffer);
    const out = &writer.interface;
    var rows = std.mem.splitScalar(u8, input, '\n');
    var id: usize = 0;
    while (rows.next()) |line| {
        if (line.len == 0) continue;
        var split = std.mem.splitScalar(u8, line, '|');
        var parts: [16][]const u8 = undefined;
        var len: usize = 0;
        while (split.next()) |p| {
            parts[len] = p;
            len += 1;
        }
        try record(out, parts[0..len], id);
        id += 1;
    }
    try out.flush();
}
