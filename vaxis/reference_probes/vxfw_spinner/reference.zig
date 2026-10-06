const std = @import("std");
const vaxis = @import("vaxis");
const fw = vaxis.vxfw;
const Spinner = fw.Spinner;
const a = std.heap.page_allocator;
const Writer = std.Io.Writer;

fn style(index: u8) vaxis.Style {
    return switch (index) {
        0 => .{},
        1 => .{ .fg = .{ .index = 17 }, .bg = .{ .index = 231 }, .bold = true, .italic = true },
        else => .{ .fg = .{ .rgb = .{ 1, 128, 255 } }, .bg = .{ .rgb = .{ 99, 33, 2 } }, .ul = .{ .index = 88 }, .ul_style = .curly, .bold = true, .dim = true, .italic = true, .blink = true, .reverse = true, .invisible = true, .strikethrough = true },
    };
}
fn number(parts: []const []const u8, i: usize) !u16 { return std.fmt.parseInt(u16, parts[i], 10); }
fn initial(parts: []const []const u8) !Spinner {
    return .{ .count = .{ .raw = try number(parts, 1) }, .frame = @intCast(try number(parts, 2)), .was_spinning = .{ .raw = (try number(parts, 3)) != 0 }, .style = style(@intCast(try number(parts, 4))) };
}
fn state(out: *Writer, spinner: *Spinner, ctx: *fw.EventContext) !void {
    try out.print("{d},{d},{d},{d},{d},{d},{d},{d}", .{ spinner.count.load(.unordered), spinner.frame, @intFromBool(spinner.wasSpinning()), @intFromEnum(ctx.phase), @intFromBool(ctx.consume_event), @intFromBool(ctx.redraw), @intFromBool(ctx.quit), ctx.cmds.items.len });
}
fn command(out: *Writer, spinner: *Spinner, cmd: ?fw.Command, before: i64, after: i64) !void {
    if (cmd) |value| switch (value) {
        .tick => |tick| try out.print("T{d},{d},{d},{d},{d};", .{ @intFromBool(tick.deadline_ms >= before + 83 and tick.deadline_ms <= after + 83), @intFromBool(tick.widget.eql(spinner.widget())), @intFromBool(@intFromPtr(tick.widget.userdata) == @intFromPtr(spinner)), @intFromBool(tick.widget.eventHandler != null), @intFromBool(tick.widget.captureHandler == null) }),
        .queue_refresh => try out.writeAll("Q;"),
        else => return error.UnexpectedCommand,
    } else try out.writeAll("-;");
}
fn drawContext(width: u16, height: u16, bounded: bool) fw.DrawContext {
    return .{ .arena = a, .min = .{ .width = width, .height = height }, .max = if (bounded) .{ .width = 0, .height = 0 } else .{}, .cell_size = .{ .width = 10, .height = 20 } };
}
fn plain(value: vaxis.Cell, expected: vaxis.Style) bool {
    return value.char.width == 1 and value.style.eql(expected) and !value.default and !value.wrapped and value.link.uri.len == 0 and value.link.params.len == 0 and value.image == null and value.scale.eql(.{});
}
fn cell(out: *Writer, value: vaxis.Cell, expected: vaxis.Style) !void {
    for (value.char.grapheme) |byte| try out.print("{x:0>2}", .{byte});
    try out.print("/{d},{d}", .{ value.char.width, @intFromBool(plain(value, expected)) });
}
fn surface(out: *Writer, value: fw.Surface, spinner: *Spinner) !void {
    defer a.free(value.buffer);
    var rest_ok = true;
    for (value.buffer[1..]) |entry| rest_ok = rest_ok and plain(entry, spinner.style) and std.mem.eql(u8, entry.char.grapheme, " ");
    try out.print("{d},{d},{d},{d},{d},{d},{d}|", .{ value.size.width, value.size.height, value.buffer.len, @intFromBool(value.widget.eql(spinner.widget())), @intFromBool(value.cursor == null), value.children.len, @intFromBool(rest_ok) });
    try cell(out, value.buffer[0], spinner.style); try out.writeByte('|'); try cell(out, value.buffer[value.buffer.len-1], spinner.style);
}
fn worker(spinner: *Spinner, n: u32, cmds: *std.atomic.Value(u32)) void {
    for (0..n) |_| { if (spinner.start() != null) _ = cmds.fetchAdd(1, .monotonic); }
}
fn trap(mode: []const u8) !void {
    var spinner: Spinner = .{ .count = .{ .raw = 1 }, .frame = 15 };
    var ctx: fw.EventContext = .{ .alloc = a, .cmds = .empty };
    if (std.mem.eql(u8, mode, "trap_tick_direct")) {
        try spinner.handleEvent(&ctx, .tick);
    } else if (std.mem.eql(u8, mode, "trap_tick_callback")) {
        try spinner.widget().handleEvent(&ctx, .tick);
    } else if (std.mem.eql(u8, mode, "trap_draw_direct")) {
        spinner.frame = 8; _ = try spinner.draw(drawContext(0, 0, false));
    } else if (std.mem.eql(u8, mode, "trap_draw_callback")) {
        _ = try spinner.widget().draw(drawContext(0, 0, false));
    } else if (std.mem.eql(u8, mode, "trap_area")) {
        spinner.count.store(0, .unordered); _ = try spinner.draw(drawContext(256, 256, false));
    } else if (std.mem.eql(u8, mode, "trap_area_before_frame")) {
        _ = try spinner.draw(drawContext(256, 256, false));
    } else return error.InvalidTrap;
    var bytes: [64]u8 = undefined; var stdout = std.fs.File.stdout().writer(&bytes);
    try stdout.interface.writeAll("UNEXPECTED returned\n"); try stdout.interface.flush();
}
fn allocationFailure(mode: []const u8) !void {
    var failing = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
    var spinner: Spinner = .{ .count = .{ .raw = 1 }, .frame = 7, .was_spinning = .{ .raw = true } };
    var ctx: fw.EventContext = .{ .alloc = failing.allocator(), .cmds = .empty, .redraw = false };
    const returned: []const u8 = blk: {
        if (std.mem.eql(u8, mode, "oom_tick")) {
            spinner.handleEvent(&ctx, .tick) catch |err| break :blk @errorName(err);
        } else {
            if (std.mem.eql(u8, mode, "oom_stopped_draw")) spinner.count.store(0, .unordered);
            var dc = drawContext(1, 1, false); dc.arena = failing.allocator();
            _ = spinner.widget().draw(dc) catch |err| break :blk @errorName(err);
        }
        break :blk "UNEXPECTED";
    };
    var bytes: [512]u8 = undefined; var stdout = std.fs.File.stdout().writer(&bytes);
    try stdout.interface.print("{s}|", .{returned}); try state(&stdout.interface, &spinner, &ctx); try stdout.interface.writeByte('\n'); try stdout.interface.flush();
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    if (std.mem.startsWith(u8, args[1], "oom_")) return allocationFailure(args[1]);
    if (std.mem.startsWith(u8, args[1], "trap_")) { trap(args[1]) catch |err| { std.debug.print("UNEXPECTED error {s}\n", .{@errorName(err)}); }; return; }
    const data = try std.fs.cwd().readFileAlloc(a, args[1], 16 * 1024 * 1024);
    var bytes: [65536]u8 = undefined; var stdout = std.fs.File.stdout().writer(&bytes); const out = &stdout.interface;
    var lines = std.mem.splitScalar(u8, data, '\n'); var index: usize = 0;
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var fields = std.mem.splitScalar(u8, line, '|'); var parts: [12][]const u8 = undefined; var length: usize = 0;
        while (fields.next()) |field| { parts[length] = field; length += 1; }
        const p = parts[0..length]; try out.print("{d}|", .{index}); index += 1;
        var spinner = try initial(p);
        var ctx: fw.EventContext = .{ .alloc = a, .cmds = .empty, .phase = @enumFromInt(try number(p, 5)), .consume_event = (try number(p, 6)) & 1 != 0, .redraw = (try number(p, 6)) & 2 != 0, .quit = (try number(p, 6)) & 4 != 0 };
        defer ctx.cmds.deinit(a);
        try ctx.cmds.append(a, .queue_refresh);
        if (std.mem.eql(u8, p[0], "S")) {
            for (p[7]) |op| {
                const before = std.time.milliTimestamp();
                switch (op) {
                    's' => { const cmd = spinner.start(); try command(out, &spinner, cmd, before, std.time.milliTimestamp()); },
                    'p' => spinner.stop(),
                    't', 'u', 'n', 'c' => {
                        const previous = ctx.cmds.items.len;
                        if (op == 't') try spinner.handleEvent(&ctx, .tick)
                        else if (op == 'u') try spinner.widget().handleEvent(&ctx, .tick)
                        else if (op == 'n') try spinner.handleEvent(&ctx, .{ .app = .{ .name = "test" } })
                        else try spinner.widget().captureEvent(&ctx, .tick);
                        const after = std.time.milliTimestamp();
                        for (ctx.cmds.items[previous..]) |cmd| try command(out, &spinner, cmd, before, after);
                    },
                    else => return error.InvalidOperation,
                }
                try state(out, &spinner, &ctx); try out.writeByte(';');
            }
        } else if (std.mem.eql(u8, p[0], "D")) {
            const dc = drawContext(try number(p, 7), try number(p, 8), (try number(p, 9)) != 0);
            const value = if ((try number(p, 10)) != 0) try spinner.widget().draw(dc) else try spinner.draw(dc);
            try surface(out, value, &spinner); try out.writeByte('|'); try state(out, &spinner, &ctx);
        } else if (std.mem.eql(u8, p[0], "C")) {
            var copied = spinner;
            _ = copied.start(); copied.stop(); copied.stop(); copied.was_spinning.store(false, .unordered);
            try copied.handleEvent(&ctx, .tick);
            try state(out, &spinner, &ctx); try out.writeByte('|'); try state(out, &copied, &ctx);
            try out.print("|{d}", .{@intFromBool(spinner.widget().eql(copied.widget()))});
        } else if (std.mem.eql(u8, p[0], "A")) {
            var commands = std.atomic.Value(u32).init(0);
            const n: u32 = try number(p, 7);
            var threads: [4]std.Thread = undefined;
            for (&threads) |*thread| thread.* = try std.Thread.spawn(.{}, worker, .{ &spinner, n, &commands });
            for (threads) |thread| thread.join();
            try state(out, &spinner, &ctx); try out.print("|{d}", .{commands.load(.unordered)});
        } else return error.InvalidMode;
        try out.print("|Q{d}\n", .{@intFromBool(ctx.cmds.items[0] == .queue_refresh)});
    }
    try out.flush();
}
