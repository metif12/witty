const std = @import("std");
const v = @import("vaxis");
const a = std.heap.page_allocator;
pub const std_options: std.Options = .{ .log_level = .err };
fn format(comptime pattern: []const u8, args: anytype) []const u8 {
    return std.fmt.allocPrint(a, pattern, args) catch @panic("fixture format");
}
fn hex(bytes: []const u8) []const u8 {
    const output = a.alloc(u8, bytes.len * 2) catch @panic("fixture hex");
    const digits = "0123456789abcdef";
    for (bytes, 0..) |byte, i| {
        output[i * 2] = digits[byte >> 4];
        output[i * 2 + 1] = digits[byte & 15];
    }
    return output;
}
fn decode(text: []const u8) []u8 {
    const output = a.alloc(u8, text.len / 2) catch @panic("fixture decode");
    _ = std.fmt.hexToBytes(output, text) catch @panic("fixture hex input");
    return output;
}
fn optional(cp: ?u21) i64 {
    return if (cp) |value| @intCast(value) else -1;
}
fn key(k: v.Key) []const u8 {
    return format("{d},{d},{d},{d},{s}", .{ k.codepoint, @as(u8, @bitCast(k.mods)), optional(k.shifted_codepoint), optional(k.base_layout_codepoint), if (k.text) |text| hex(text) else "-" });
}
fn event(e: @import("vaxis").Event) []const u8 {
    return switch (e) {
        .key_press => |k| format("k:{s}", .{key(k)}),
        .key_release => |k| format("r:{s}", .{key(k)}),
        .mouse => |m| format("m:{d},{d},{d},{d},{d},{d},{d}", .{ @intFromEnum(m.button), @intFromEnum(m.type), m.col, m.row, m.xoffset, m.yoffset, @as(u3, @bitCast(m.mods)) }),
        .mouse_leave => "leave",
        .focus_in => "in",
        .focus_out => "out",
        .paste_start => "start",
        .paste_end => "end",
        .paste => |text| format("p:{s}", .{hex(text)}),
        .color_scheme => |s| format("s:{d}", .{@intFromEnum(s)}),
        .winsize => |w| format("w:{d},{d},{d},{d}", .{ w.rows, w.cols, w.x_pixel, w.y_pixel }),
        .color_report => |c| format("c:{s},{d},{d},{d}", .{ switch (c.kind) {
            .fg => "f",
            .bg => "b",
            .cursor => "c",
            .index => |i| format("i{d}", .{i}),
        }, c.value[0], c.value[1], c.value[2] }),
        .cap_kitty_keyboard => "cap:0",
        .cap_kitty_graphics => "cap:1",
        .cap_rgb => "cap:2",
        .cap_sgr_pixels => "cap:3",
        .cap_unicode => "cap:4",
        .cap_da1 => "cap:5",
        .cap_color_scheme_updates => "cap:6",
        .cap_multi_cursor => "cap:7",
    };
}
fn result(r: v.Parser.Result) []const u8 {
    return format("{d}:{s}", .{ r.n, if (r.event) |e| event(e) else "-" });
}
fn out(text: []const u8) void {
    _ = std.posix.write(1, text) catch @panic("fixture stdout");
    _ = std.posix.write(1, "\n") catch @panic("fixture stdout");
}
fn parse_case(parts: []const []const u8) []const u8 {
    var p: v.Parser = .{ .buf = @splat(17) };
    const bytes = decode(parts[1]);
    const clipboard = std.mem.eql(u8, parts[2], "1");
    const r = p.parse(bytes, if (clipboard) a else null) catch |err| return format("!{s}/{s}", .{ @errorName(err), hex(&p.buf) });
    return format("{s}/{s}", .{ result(r), hex(&p.buf) });
}
fn borrow_case(parts: []const []const u8) []const u8 {
    var p: v.Parser = .{ .buf = @splat(17) };
    const bytes = decode(parts[1]);
    const first = p.parse(bytes, null) catch @panic("fixture first");
    const before = result(first);
    bytes[0] = 'Q';
    p.buf[0] = 'Z';
    const mutated = result(first);
    const next = p.parse(decode(parts[2]), null) catch @panic("fixture next");
    return format("{s}/{s}/{s}/{s}/{s}", .{ before, mutated, result(next), result(first), hex(&p.buf) });
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    if (std.mem.eql(u8, args[1], "trap")) {
        var p: v.Parser = .{ .buf = @splat(17) };
        _ = p.parse(decode(args[2]), if (std.mem.eql(u8, args[3], "1")) a else null) catch |err| {
            out(format("UNEXPECTED error {s}", .{@errorName(err)}));
            return;
        };
        out("UNEXPECTED return");
        return;
    }
    const input = try std.fs.cwd().readFileAlloc(a, args[1], 64 * 1024 * 1024);
    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var fields = std.mem.splitScalar(u8, line, '|');
        var parts: [3][]const u8 = undefined;
        for (&parts) |*part| part.* = fields.next() orelse @panic("fixture fields");
        out(if (std.mem.eql(u8, parts[0], "P")) parse_case(&parts) else borrow_case(&parts));
    }
}
