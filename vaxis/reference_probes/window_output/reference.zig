const std = @import("std");
const v = @import("vaxis");
const a = std.heap.page_allocator;
const Writer = std.Io.Writer;

fn n(p: []const []const u8, i: usize) !i32 {
    return std.fmt.parseInt(i32, p[i], 10);
}
fn u(p: []const []const u8, i: usize) !u16 {
    return @intCast(try n(p, i));
}
fn makeWindow(screen: *v.Screen, width: u16, height: u16, x: i17, y: i17, px: i17, py: i17) v.Window {
    return .{ .width = width, .height = height, .x_off = x, .y_off = y, .parent_x_off = px, .parent_y_off = py, .screen = screen };
}
fn segment(text: []const u8, index: u8) v.Segment {
    return .{ .text = text, .style = .{ .fg = .{ .index = index }, .bold = index == 2 }, .link = .{ .uri = if (index == 1) "one" else "two", .params = "id=probe" } };
}
fn cell(out: *Writer, c: v.Cell, original: []const u8) !void {
    for (c.char.grapheme) |byte| try out.print("{x:0>2}", .{byte});
    const color: u16 = switch (c.style.fg) {
        .default => 0,
        .index => |i| @as(u16, i) + 1,
        else => unreachable,
    };
    const pointer = @intFromPtr(c.char.grapheme.ptr);
    const start = @intFromPtr(original.ptr);
    const offset: i64 = if (c.char.grapheme.len > 0 and pointer >= start and pointer + c.char.grapheme.len <= start + original.len) @intCast(pointer - start) else -1;
    try out.print("/{d},{d},{d},{d},{d},{s},{s},{d};", .{ c.char.width, @intFromBool(c.default), @intFromBool(c.wrapped), color, @intFromBool(c.style.bold), c.link.uri, c.link.params, offset });
}
fn trap(name: []const u8) !void {
    var screen: v.Screen = .{};
    var win = makeWindow(&screen, 0, 0, 0, 0, 0, 0);
    var opts: v.Window.PrintOptions = .{ .commit = false };
    var text: []const u8 = "a";
    if (std.mem.startsWith(u8, name, "trap_width_")) {
        const unit = "👩\u{200d}";
        const wide = try a.alloc(u8, unit.len * 130);
        for (0..130) |i| @memcpy(wide[i * unit.len ..][0..unit.len], unit);
        screen.width_method = .no_zwj;
        win.width = 65535;
        win.height = 1;
        _ = win.printSegment(.{ .text = wide }, .{ .wrap = if (std.mem.endsWith(u8, name, "word")) .word else if (std.mem.endsWith(u8, name, "none")) .none else .grapheme });
    } else if (std.mem.eql(u8, name, "trap_fill_x")) {
        win.x_off = 65535;
        win.width = 1;
        win.fill(.{});
    } else if (std.mem.eql(u8, name, "trap_fill_y")) {
        win.y_off = 65535;
        win.height = 1;
        win.fill(.{});
    } else {
        if (std.mem.eql(u8, name, "trap_row_initial")) opts.row_offset = 65535 else if (std.mem.eql(u8, name, "trap_row_final")) {
            opts.row_offset = 65535;
            text = "";
        } else if (std.mem.eql(u8, name, "trap_col") or std.mem.eql(u8, name, "trap_wrapped")) {
            win.width = 65535;
            win.height = 1;
            opts.col_offset = 65534;
            text = "界";
            opts.commit = std.mem.eql(u8, name, "trap_wrapped");
        } else if (std.mem.eql(u8, name, "trap_word_sum")) {
            win.width = 65535;
            opts.wrap = .word;
            opts.col_offset = 65535;
        } else if (std.mem.eql(u8, name, "trap_word_whitespace")) {
            opts.wrap = .word;
            opts.row_offset = 65535;
            text = " ";
        } else if (std.mem.eql(u8, name, "trap_word_defer")) {
            win.width = 1;
            opts.wrap = .word;
            opts.row_offset = 65535;
            text = "\n";
        } else if (std.mem.startsWith(u8, name, "trap_unicode_")) {
            text = "\xff\xcc\x81";
            opts.wrap = if (std.mem.endsWith(u8, name, "word")) .word else if (std.mem.endsWith(u8, name, "none")) .none else .grapheme;
        } else return error.InvalidTrap;
        _ = win.printSegment(.{ .text = text }, opts);
    }
    var bytes: [64]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&bytes);
    try stdout.interface.writeAll("UNEXPECTED\n");
    try stdout.interface.flush();
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    if (std.mem.startsWith(u8, args[1], "trap_")) return trap(args[1]);
    const input = try std.fs.cwd().readFileAlloc(a, args[1], 64 * 1024 * 1024);
    var bytes: [65536]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&bytes);
    const out = &stdout.interface;
    var rows = std.mem.splitScalar(u8, input, '\n');
    var number: usize = 0;
    while (rows.next()) |row| {
        if (row.len == 0) continue;
        var fields = std.mem.splitScalar(u8, row, '|');
        var storage: [18][]const u8 = undefined;
        var count: usize = 0;
        while (fields.next()) |field| {
            storage[count] = field;
            count += 1;
        }
        const p = storage[0..count];
        var screen: v.Screen = .{ .width = try u(p, 1), .height = try u(p, 2) };
        const size: usize = if (p[0][0] == 'F') @intCast(try n(p, 3)) else @as(usize, screen.width) * screen.height;
        const buffer = try a.alloc(v.Cell, size);
        defer a.free(buffer);
        @memset(buffer, .{ .char = .{ .grapheme = "o" }, .default = true });
        screen.buf = buffer;
        const win = makeWindow(&screen, try u(p, 4), try u(p, 5), @intCast(try n(p, 6)), @intCast(try n(p, 7)), @intCast(try n(p, 8)), @intCast(try n(p, 9)));
        try out.print("{d}|", .{number});
        number += 1;
        if (p[0][0] == 'F') {
            if (try n(p, 10) == 0) win.fill(.{ .char = .{ .grapheme = "x", .width = 2 }, .style = .{ .fg = .{ .index = 9 } }, .wrapped = true }) else win.clear();
            for (buffer) |value| try cell(out, value, "");
        } else {
            screen.width_method = @enumFromInt(try u(p, 14));
            const text = try a.alloc(u8, p[16].len / 2);
            defer a.free(text);
            _ = try std.fmt.hexToBytes(text, p[16]);
            const cut = try n(p, 15);
            var segments: [2]v.Segment = undefined;
            const values: []const v.Segment = if (cut < 0) blk: {
                segments[0] = segment(text, 1);
                break :blk segments[0..1];
            } else blk: {
                const point: usize = @intCast(cut);
                segments[0] = segment(text[0..point], 1);
                segments[1] = segment(text[point..], 2);
                break :blk &segments;
            };
            const opts: v.Window.PrintOptions = .{ .wrap = @enumFromInt(try u(p, 10)), .row_offset = try u(p, 11), .col_offset = try u(p, 12), .commit = try n(p, 13) != 0 };
            const result = if (cut < 0) win.printSegment(values[0], opts) else win.print(values, opts);
            try out.print("{d},{d},{d}|", .{ result.col, result.row, @intFromBool(result.overflow) });
            for (buffer) |value| try cell(out, value, text);
            try out.writeByte('|');
            @memset(text, 'Z');
            for (buffer) |value| for (value.char.grapheme) |byte| {
                try out.print("{x:0>2}", .{byte});
            };
        }
        try out.writeByte('\n');
        try out.flush();
    }
    try out.flush();
}
