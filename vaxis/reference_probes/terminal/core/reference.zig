const std = @import("std");
const vaxis = @import("main.zig");
const Terminal = @import("widgets/terminal/Terminal.zig");
const TS = @import("widgets/terminal/Screen.zig");
const Command = @import("widgets/terminal/Command.zig");
const a = std.heap.page_allocator;
fn number(text: []const u8) !u16 {
    return std.fmt.parseInt(u16, text, 10);
}
fn newTerminal(alloc: std.mem.Allocator, env: *const std.process.EnvMap, w: u16, h: u16, bh: u16, buf: []u8) !Terminal {
    var result = Terminal{ .allocator = alloc, .scrollback_size = bh - h, .pty = .{ .pty = .{ .handle = -1 }, .tty = .{ .handle = -1 } }, .pty_writer = (std.fs.File{ .handle = -1 }).writerStreaming(buf), .cmd = Command{ .argv = &.{"true"}, .working_directory = null, .env_map = env, .pty = .{ .pty = .{ .handle = -1 }, .tty = .{ .handle = -1 } } }, .front_screen = try TS.init(alloc, w, h), .back_screen_pri = try TS.init(alloc, w, bh), .back_screen_alt = try TS.init(alloc, w, h), .tab_stops = .empty };
    result.front_screen.cursor.uri = .empty;
    result.front_screen.cursor.uri_id = .empty;
    result.back_screen_pri.cursor.uri = .empty;
    result.back_screen_pri.cursor.uri_id = .empty;
    result.back_screen_alt.cursor.uri = .empty;
    result.back_screen_alt.cursor.uri_id = .empty;
    var col: u16 = 0;
    while (col < w) : (col += 8) {
        try result.tab_stops.append(alloc, col);
    }
    return result;
}
fn state(t: *Terminal, out: *std.Io.Writer) !void {
    try out.print("{d},{d},{d}/{d}{d}{d}{d}/{d}/", .{ t.back_screen.cursor.col, t.back_screen.cursor.row, @intFromBool(t.back_screen.cursor.pending_wrap), @intFromBool(t.mode.origin), @intFromBool(t.mode.autowrap), @intFromBool(t.mode.cursor), @intFromBool(t.mode.sync), @intFromBool(t.back_screen == &t.back_screen_alt) });
    for (t.back_screen.buf) |cell| try out.print("{d}", .{@intFromBool(cell.dirty)});
}
fn control(parts: [][]const u8, out: *std.Io.Writer) !void {
    var arena = std.heap.ArenaAllocator.init(a);
    defer arena.deinit();
    const alloc = arena.allocator();
    var env = std.process.EnvMap.init(alloc);
    var bytes: [8]u8 = undefined;
    var t = try newTerminal(alloc, &env, try number(parts[1]), 3, 3, &bytes);
    t.back_screen = &t.back_screen_pri;
    t.back_screen.cursor.col = try number(parts[2]);
    t.back_screen.cursor.row = 1;
    t.back_screen.cursor.pending_wrap = true;
    t.back_screen.scrolling_region.left = try number(parts[3]);
    t.mode.origin = std.mem.eql(u8, parts[4], "1");
    const n = try std.fmt.parseInt(usize, parts[6], 10);
    switch (parts[5][0]) {
        'c' => t.carriageReturn(),
        't' => t.horizontalTab(n),
        'b' => t.horizontalBackTab(n),
        'm' => t.setMode(@intCast(n), std.mem.eql(u8, parts[7], "1")),
        else => unreachable,
    }
    try state(&t, out);
    try out.writeByte('\n');
}
fn draw(parts: [][]const u8, out: *std.Io.Writer) !void {
    var arena = std.heap.ArenaAllocator.init(a);
    defer arena.deinit();
    const alloc = arena.allocator();
    var env = std.process.EnvMap.init(alloc);
    var bytes: [8]u8 = undefined;
    const w = try number(parts[1]);
    const h = try number(parts[2]);
    var t = try newTerminal(alloc, &env, w, h, try number(parts[3]), &bytes);
    t.back_screen = &t.back_screen_pri;
    try t.back_screen.print("x", 1, true);
    try t.back_screen.print("界", 2, true);
    t.back_screen.cursor.row = h - 1;
    t.back_screen.cursor.col = w - 1;
    t.mode.sync = std.mem.eql(u8, parts[4], "1");
    t.mode.cursor = std.mem.eql(u8, parts[5], "1");
    t.dirty = true;
    const lock = std.mem.eql(u8, parts[6], "1");
    if (lock) t.back_mutex.lock();
    var screen = try vaxis.Screen.init(alloc, .{ .cols = try number(parts[7]), .rows = try number(parts[8]), .x_pixel = 0, .y_pixel = 0 });
    const win = vaxis.Window{ .x_off = 0, .y_off = 0, .parent_x_off = 0, .parent_y_off = 0, .width = screen.width, .height = screen.height, .screen = &screen };
    try t.draw(alloc, win);
    if (lock) t.back_mutex.unlock();
    for (screen.buf) |cell| try out.print("{x}:{d},", .{ cell.char.grapheme, cell.char.width });
    try out.print("/{d},{d},{d},{d}/{d}/", .{ screen.cursor_col, screen.cursor_row, @intFromBool(screen.cursor_vis), @intFromEnum(screen.cursor_shape), @intFromBool(t.dirty) });
    try state(&t, out);
    try out.writeByte('\n');
}
fn update(parts: [][]const u8, out: *std.Io.Writer, file_path: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(a);
    defer arena.deinit();
    const alloc = arena.allocator();
    var env = std.process.EnvMap.init(alloc);
    const bytes = try alloc.alloc(u8, try number(parts[1]));
    var t = try newTerminal(alloc, &env, 4, 2, 2, bytes);
    t.back_screen = &t.back_screen_pri;
    const f = try std.fs.cwd().createFile(file_path, .{ .read = true });
    defer f.close();
    t.pty_writer = f.writerStreaming(bytes);
    const writer = t.get_pty_writer();
    try writer.writeAll(parts[2]);
    var result: []const u8 = "ok";
    t.update(.{ .key_press = .{ .codepoint = try std.fmt.parseInt(u21, parts[3], 10), .mods = @bitCast(try std.fmt.parseInt(u8, parts[4], 10)) } }) catch |err| {
        result = @errorName(err);
    };
    try writer.writeByte('!');
    try writer.flush();
    try f.seekTo(0);
    const content = try f.readToEndAlloc(alloc, 1024);
    try out.print("{s}/{x}/{d}\n", .{ result, content, writer.end });
}
fn cleanup(parts: [][]const u8, out: *std.Io.Writer) !void {
    var arena = std.heap.ArenaAllocator.init(a);
    defer arena.deinit();
    const alloc = arena.allocator();
    var env = std.process.EnvMap.init(alloc);
    var bytes: [8]u8 = undefined;
    const first = try std.fs.openFileAbsolute("/dev/null", .{ .mode = .read_write });
    const second = try std.fs.openFileAbsolute("/dev/null", .{ .mode = .read_write });
    const pair = @import("widgets/terminal/Pty.zig"){ .pty = first, .tty = second };
    var t = try newTerminal(alloc, &env, 4, 2, 2, &bytes);
    t.back_screen = &t.back_screen_pri;
    t.pty = pair;
    t.cmd.pty = pair;
    if (std.mem.eql(u8, parts[1], "terminal")) {
        t.event_queue.push(.bell);
        t.deinit();
    } else if (std.mem.eql(u8, parts[1], "pty")) {
        pair.deinit();
    } else {
        if (std.mem.eql(u8, parts[1], "dead")) t.cmd.pid = 2147483647;
        t.cmd.kill();
        pair.deinit();
    }
    var scratch: [1]u8 = undefined;
    const closed_first = std.posix.errno(std.posix.system.read(first.handle, &scratch, 0)) == .BADF;
    const closed_second = std.posix.errno(std.posix.system.read(second.handle, &scratch, 0)) == .BADF;
    const event = t.tryEvent();
    const bell = if (event) |e| e == .bell else false;
    try out.print("{d},{d}/{d},{d},{d}\n", .{ @intFromBool(closed_first), @intFromBool(closed_second), @intFromBool(t.should_quit), @intFromBool(t.cmd.pid == null), @intFromBool(bell) });
}
fn registry(out: *std.Io.Writer) !void {
    var env = std.process.EnvMap.init(a);
    var first_buf: [8]u8 = undefined;
    var second_buf: [8]u8 = undefined;
    var first = try newTerminal(a, &env, 4, 2, 2, &first_buf);
    var second = try newTerminal(a, &env, 4, 2, 2, &second_buf);
    first.pty = .{ .pty = try std.fs.openFileAbsolute("/dev/null", .{ .mode = .read_write }), .tty = try std.fs.openFileAbsolute("/dev/null", .{ .mode = .read_write }) };
    second.pty = .{ .pty = try std.fs.openFileAbsolute("/dev/null", .{ .mode = .read_write }), .tty = try std.fs.openFileAbsolute("/dev/null", .{ .mode = .read_write }) };
    const first_pid: i32 = 2147483646;
    const second_pid: i32 = 2147483647;
    first.cmd.pid = first_pid;
    second.cmd.pid = second_pid;
    Terminal.global_vts = std.AutoHashMap(i32, *Terminal).init(a);
    try Terminal.global_vts.?.put(first_pid, &first);
    try Terminal.global_vts.?.put(second_pid, &second);
    defer {
        Terminal.global_vts.?.deinit();
        Terminal.global_vts = null;
    }
    for (0..3) |step| {
        if (step == 1) first.deinit();
        if (step == 2) second.deinit();
        var live: usize = 0;
        var iterator = Terminal.global_vts.?.iterator();
        while (iterator.next() != null) live += 1;
        try out.print("{d}|{d}|{d}|{d}|{d}\n", .{ Terminal.global_vts.?.count(), live, @intFromBool(Terminal.global_vts.?.get(first_pid) != null), @intFromBool(Terminal.global_vts.?.get(second_pid) != null), @intFromBool(Terminal.global_vts != null) });
    }
}
fn trap(name: []const u8) !void {
    var env = std.process.EnvMap.init(a);
    var bytes: [8]u8 = undefined;
    var t = try newTerminal(a, &env, 4, 2, if (std.mem.eql(u8, name, "tall")) 3 else 2, &bytes);
    t.back_screen = &t.back_screen_pri;
    if (std.mem.eql(u8, name, "tall")) {
        var s = try vaxis.Screen.init(a, .{ .cols = 4, .rows = 2, .x_pixel = 0, .y_pixel = 0 });
        try t.draw(a, .{ .x_off = 0, .y_off = 0, .parent_x_off = 0, .parent_y_off = 0, .width = 4, .height = 2, .screen = &s });
    } else if (std.mem.eql(u8, name, "back")) {
        t.back_screen.cursor.col = 3;
        t.horizontalBackTab(1);
    } else if (std.mem.eql(u8, name, "tabs")) {
        t.tab_stops = .empty;
        t.horizontalBackTab(1);
    } else if (std.mem.eql(u8, name, "zero")) {
        t.back_screen.width = 0;
        t.horizontalTab(1);
    } else if (std.mem.eql(u8, name, "kitty")) {
        t.back_screen.csi_u_flags = @bitCast(@as(u5, 1));
        t.update(.{ .key_press = .{ .codepoint = 'a' } }) catch |err| {
            std.debug.print("UNEXPECTED: {s}\n", .{@errorName(err)});
            return;
        };
    } else unreachable;
    std.debug.print("UNEXPECTED: returned\n", .{});
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    if (std.mem.eql(u8, args[1], "registry")) {
        var out = std.Io.Writer.Allocating.init(a);
        defer out.deinit();
        try registry(&out.writer);
        _ = try std.posix.write(1, out.written());
        return;
    }

    if (std.mem.startsWith(u8, args[1], "trap:")) {
        try trap(args[1][5..]);
        return;
    }
    const text = try std.fs.cwd().readFileAlloc(a, args[1], 10000000);
    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    var output = std.Io.Writer.Allocating.init(a);
    defer output.deinit();
    while (lines.next()) |line| {
        var it = std.mem.splitScalar(u8, line, '|');
        var parts: std.ArrayList([]const u8) = .empty;
        while (it.next()) |p| try parts.append(a, p);
        switch (parts.items[0][0]) {
            'C' => try control(parts.items, &output.writer),
            'D' => try draw(parts.items, &output.writer),
            'U' => try update(parts.items, &output.writer, args[2]),
            'N' => try cleanup(parts.items, &output.writer),
            else => unreachable,
        }
    }
    _ = try std.posix.write(1, output.written());
}
