const std = @import("std");
const v = @import("vaxis");
const a = std.heap.page_allocator;
pub const std_options: std.Options = .{ .log_level = .err };
fn fmt(comptime pattern: []const u8, args: anytype) []const u8 {
    return std.fmt.allocPrint(a, pattern, args) catch @panic("fixture format");
}
fn color(kind: u8, value: u32) v.Cell.Color {
    return switch (kind) {
        0 => .default,
        1 => .{ .index = @intCast(value) },
        2 => v.Cell.Color.rgbFromUint(@intCast(value)),
        else => @panic("fixture kind"),
    };
}
fn text(c: v.Cell.Color) []const u8 {
    return switch (c) {
        .default => "d",
        .index => |n| fmt("i{d}", .{n}),
        .rgb => |r| fmt("r{d},{d},{d}", .{ r[0], r[1], r[2] }),
    };
}
fn flags(s: v.Style) u8 {
    return @as(u8, @intFromBool(s.bold)) | (@as(u8, @intFromBool(s.dim)) << 1) | (@as(u8, @intFromBool(s.italic)) << 2) | (@as(u8, @intFromBool(s.blink)) << 3) | (@as(u8, @intFromBool(s.reverse)) << 4) | (@as(u8, @intFromBool(s.invisible)) << 5) | (@as(u8, @intFromBool(s.strikethrough)) << 6);
}
fn styleText(s: v.Style) []const u8 {
    return fmt("{s}/{s}/{s}/{d}/{d}", .{ text(s.fg), text(s.bg), text(s.ul), @intFromEnum(s.ul_style), flags(s) });
}
fn equalityChecks(value: v.Style) u16 {
    const copied = value;
    var result: u16 = @as(u16, @intFromBool(v.Style.eql(value, value))) | (@as(u16, @intFromBool(v.Style.eql(value, copied))) << 1);
    for (0..11) |field| {
        var changed = value;
        switch (field) {
            0 => changed.fg = if (value.fg == .default) .{ .index = 0 } else .default,
            1 => changed.bg = if (value.bg == .default) .{ .index = 0 } else .default,
            2 => changed.ul = if (value.ul == .default) .{ .index = 0 } else .default,
            3 => changed.ul_style = @enumFromInt((@intFromEnum(value.ul_style) + 1) % 6),
            4 => changed.bold = !value.bold,
            5 => changed.dim = !value.dim,
            6 => changed.italic = !value.italic,
            7 => changed.blink = !value.blink,
            8 => changed.reverse = !value.reverse,
            9 => changed.invisible = !value.invisible,
            10 => changed.strikethrough = !value.strikethrough,
            else => unreachable,
        }
        result |= @as(u16, @intFromBool(v.Style.eql(value, changed))) << @as(u4, @intCast(field + 2));
    }
    return result;
}
fn unsigned(raw: []const u8) u32 {
    return std.fmt.parseInt(u32, raw, 10) catch @panic("fixture integer");
}
fn decode(raw: []const u8) []u8 {
    const bytes = a.alloc(u8, raw.len / 2) catch @panic("fixture bytes");
    _ = std.fmt.hexToBytes(bytes, raw) catch @panic("fixture hex");
    return bytes;
}
fn spec(raw: []const u8) []const u8 {
    const bytes = decode(raw);
    const direct = if (v.Cell.Color.rgbFromSpec(bytes)) |c| text(c) else |err| fmt("E{s}", .{@errorName(err)});
    var parser: v.Parser = .{ .buf = @splat(17) };
    const input = fmt("\x1b]10;{s}\x07", .{bytes});
    const parsed = if (parser.parse(input, null)) |r| blk: {
        if (r.event) |e| if (e == .color_report) break :blk text(.{ .rgb = e.color_report.value });
        break :blk "-";
    } else |err| fmt("E{s}", .{@errorName(err)});
    return fmt("{s}|{s}", .{ direct, parsed });
}
fn style(p: []const []const u8) []const u8 {
    var value: v.Style = .{};
    const before = value;
    value.fg = color(@intCast(unsigned(p[1])), unsigned(p[2]));
    value.bg = color(@intCast(unsigned(p[3])), unsigned(p[4]));
    value.ul = color(@intCast(unsigned(p[5])), unsigned(p[6]));
    value.ul_style = @enumFromInt(unsigned(p[7]));
    const bits = unsigned(p[8]);
    value.bold = bits & 1 != 0;
    value.dim = bits & 2 != 0;
    value.italic = bits & 4 != 0;
    value.blink = bits & 8 != 0;
    value.reverse = bits & 16 != 0;
    value.invisible = bits & 32 != 0;
    value.strikethrough = bits & 64 != 0;
    var copied = value;
    copied.bold = !copied.bold;
    copied.fg = .default;
    return fmt("{s}|{s}|{s}|{d}|{d}|{d}", .{ styleText(before), styleText(value), styleText(copied), @intFromBool(v.Style.eql(before, value)), @intFromBool(v.Style.eql(value, copied)), equalityChecks(value) });
}
fn out(value: []const u8) void {
    _ = std.posix.write(1, value) catch @panic("fixture stdout");
    _ = std.posix.write(1, "\n") catch @panic("fixture stdout");
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    if (std.mem.eql(u8, args[1], "trap")) {
        _ = v.Cell.Color.rgbFromUint(@intCast(unsigned(args[2])));
        out("UNEXPECTED return");
        return;
    }
    if (std.mem.eql(u8, args[1], "boxed")) {
        var c: v.Cell.Color = .{ .rgb = .{ 1, 2, 3 } };
        const old = c;
        c.rgb[0] = 9;
        var s: v.Style = .{ .fg = .{ .rgb = .{ 4, 5, 6 } } };
        const copied = s;
        s.fg.rgb[0] = 8;
        out(fmt("{s}|{s}|{s}|{s}", .{ text(c), text(old), text(s.fg), text(copied.fg) }));
        return;
    }
    if (std.mem.eql(u8, args[1], "layout")) {
        out(fmt("{d},{d},{d},{d}", .{ @sizeOf(v.Cell.Color), @alignOf(v.Cell.Color), @sizeOf(v.Style), @alignOf(v.Style) }));
        return;
    }
    const input = try std.fs.cwd().readFileAlloc(a, args[1], 64 * 1024 * 1024);
    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var split = std.mem.splitScalar(u8, line, '|');
        var fields: [9][]const u8 = undefined;
        var count: usize = 0;
        while (split.next()) |f| {
            fields[count] = f;
            count += 1;
        }
        const p = fields[0..count];
        const output = switch (p[0][0]) {
            'U' => text(v.Cell.Color.rgbFromUint(@intCast(unsigned(p[1])))),
            'S' => spec(p[1]),
            'E' => blk: {
                const left = color(@intCast(unsigned(p[1])), unsigned(p[2]));
                const right = color(@intCast(unsigned(p[3])), unsigned(p[4]));
                break :blk fmt("{d},{d}", .{ @intFromBool(v.Cell.Color.eql(left, right)), @intFromBool(v.Cell.Color.eql(right, left)) });
            },
            'T' => style(p),
            'A' => blk: {
                const Alias = v.Style;
                const ColorAlias = v.Cell.Color;
                var s: Alias = .{};
                s.bold = true;
                s.fg = ColorAlias.rgbFromUint(0x123456);
                const old = s;
                s.dim = true;
                break :blk fmt("{s}|{s}|{d}", .{ styleText(s), styleText(old), @intFromBool(Alias.eql(s, old)) });
            },
            'B' => blk: {
                var rgb = [_]u8{ 1, 2, 3 };
                const c: v.Cell.Color = .{ .rgb = rgb };
                rgb[0] = 9;
                const old = c;
                break :blk fmt("{s}|{s}|{d}", .{ text(c), text(old), rgb[0] });
            },
            else => @panic("fixture case"),
        };
        out(output);
    }
}
