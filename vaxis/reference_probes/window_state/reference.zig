const std = @import("std");
const v = @import("vaxis");
const a = std.heap.page_allocator;

fn number(p: []const []const u8, i: usize) !i32 {
    return std.fmt.parseInt(i32, p[i], 10);
}
fn word(p: []const []const u8, i: usize) !u16 {
    return @intCast(try number(p, i));
}
fn window(screen: *v.Screen, p: []const []const u8) !v.Window {
    return .{ .screen = screen, .width = try word(p, 4), .height = try word(p, 5), .x_off = @intCast(try number(p, 6)), .y_off = @intCast(try number(p, 7)), .parent_x_off = @intCast(try number(p, 8)), .parent_y_off = @intCast(try number(p, 9)) };
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    const input = try std.fs.cwd().readFileAlloc(a, args[1], 32 * 1024 * 1024);
    var bytes: [65536]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&bytes);
    const out = &writer.interface;
    var rows = std.mem.splitScalar(u8, input, '\n');
    var row_id: usize = 0;
    while (rows.next()) |line| {
        if (line.len == 0) continue;
        var parts = std.mem.splitScalar(u8, line, '|');
        var storage: [18][]const u8 = undefined;
        var count: usize = 0;
        while (parts.next()) |part| {
            storage[count] = part;
            count += 1;
        }
        const p = storage[0..count];
        var screen: v.Screen = .{ .width = try word(p, 1), .height = try word(p, 2), .cursor_col = 7, .cursor_row = 8, .cursor_vis = true };
        const win = try window(&screen, p);
        if (p[0][0] == 'S') {
            const size: usize = @intCast(try number(p, 3));
            const cells = try a.alloc(v.Cell, size);
            defer a.free(cells);
            const text = try a.alloc(u8, size);
            defer a.free(text);
            for (cells, 0..) |*cell, i| {
                text[i] = @intCast(33 + i % 94);
                cell.* = .{ .char = .{ .grapheme = text[i .. i + 1], .width = @intCast(i % 3) }, .style = .{ .fg = .{ .index = @intCast(i % 256) }, .bold = i % 2 == 0 }, .link = .{ .uri = "u", .params = "p" }, .default = i % 3 == 0, .wrapped = i % 2 != 0 };
            }
            screen.buf = cells;
            win.scroll(try word(p, 10));
            try out.print("{d}|S|{d},{d},{d}|", .{ row_id, screen.cursor_col, screen.cursor_row, @intFromBool(screen.cursor_vis) });
            for (cells) |cell| {
                const ptr = @intFromPtr(cell.char.grapheme.ptr);
                const start = @intFromPtr(text.ptr);
                const offset: i64 = if (cell.char.grapheme.len > 0 and ptr >= start and ptr + cell.char.grapheme.len <= start + text.len) @intCast(ptr - start) else -1;
                const color: u16 = switch (cell.style.fg) {
                    .default => 0,
                    .index => |index| @as(u16, index) + 1,
                    else => unreachable,
                };
                for (cell.char.grapheme) |byte| try out.print("{x:0>2}", .{byte});
                try out.print("/{d},{d},{d},{d},{d},{s},{s},{d},{d},{d};", .{ cell.char.width, color, @intFromBool(cell.style.bold), @intFromBool(cell.default), @intFromBool(cell.wrapped), cell.link.uri, cell.link.params, offset, @intFromBool(cell.image != null), @intFromBool(std.meta.eql(cell.scale, v.Cell.Scale{})) });
            }
            for (text) |*byte| byte.* ^= 1;
            var checksum: u64 = 14695981039346656037;
            for (cells) |cell| for (cell.char.grapheme) |byte| {
                checksum = (checksum ^ byte) *% 1099511628211;
            };
            try out.print("|{x}\n", .{checksum});
        } else {
            const event: ?v.Mouse = if (try number(p, 10) == 0) null else .{ .col = try word(p, 11), .row = try word(p, 12), .xoffset = try word(p, 13), .yoffset = try word(p, 14), .button = @enumFromInt(try word(p, 15)), .type = @enumFromInt(try word(p, 16)), .mods = .{} };
            const result = win.hasMouse(event);
            if (result) |mouse| try out.print("{d}|M|{d},{d},{d},{d},{d},{d},{d}\n", .{ row_id, mouse.col, mouse.row, mouse.xoffset, mouse.yoffset, @intFromEnum(mouse.button), @intFromEnum(mouse.type), @as(u3, @bitCast(mouse.mods)) }) else try out.print("{d}|M|-\n", .{row_id});
        }
        row_id += 1;
        try out.flush();
    }
}
