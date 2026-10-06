const std = @import("std");
const vaxis = @import("vaxis");
const fw = vaxis.vxfw;
pub const std_options: std.Options = .{ .log_level = .err };
const a = std.heap.page_allocator;
var mode: []const u8 = undefined;
var nodes: [4]Node = undefined;
var ticks: u8 = 0;
var draws: u16 = 0;
var held_fd: std.posix.fd_t = undefined;
var app_pointer: *fw.App = undefined;
var event_context: *fw.EventContext = undefined;

fn out(comptime format: []const u8, args: anytype) void {
    var bytes: [512]u8 = undefined;
    const text = std.fmt.bufPrint(&bytes, format, args) catch @panic("fixture format");
    var index: usize = 0;
    while (index < text.len) index += std.posix.write(1, text[index..]) catch @panic("fixture stdout");
}
fn is(text: []const u8) bool {
    return std.mem.eql(u8, mode, text);
}
const Node = struct {
    id: u8,
    fn widget(self: *Node) fw.Widget {
        return .{ .userdata = self, .captureHandler = capture, .eventHandler = handle, .drawFn = draw };
    }
    fn capture(ptr: *anyopaque, ctx: *fw.EventContext, event: fw.Event) !void {
        const self: *Node = @ptrCast(@alignCast(ptr));
        trace(self.id, 'C', ctx.phase, event);
        if (event == .key_press) {
            const key = event.key_press.codepoint;
            if (is("error_capture") and key == 'e') return error.ProbeFailure;
            if (key == 'c' and self.id == 0) ctx.consumeEvent();
        }
    }
    fn handle(ptr: *anyopaque, ctx: *fw.EventContext, event: fw.Event) !void {
        const self: *Node = @ptrCast(@alignCast(ptr));
        trace(self.id, 'H', ctx.phase, event);
        switch (event) {
            .init => {
                event_context = ctx;
                if (is("error_init")) return error.ProbeFailure;
                if (is("init_quit") or is("commands") or is("buffer_probe")) ctx.quit = true;
                if (is("buffer_probe")) try app_pointer.tty.writer().writeAll("buffered-proof");
                if (is("seed_sorted")) {
                    try app_pointer.timers.append(a, .{ .deadline_ms = std.math.maxInt(i64), .widget = self.widget() });
                    for (1..4) |index| try app_pointer.timers.append(a, .{ .deadline_ms = @intCast(3 - index), .widget = nodes[index].widget() });
                }
                if (is("seed_resort")) {
                    const deadlines = [_]i64{ 0, 2, 1 };
                    for (deadlines, 1..) |deadline, index| try app_pointer.timers.append(a, .{ .deadline_ms = deadline, .widget = nodes[index].widget() });
                    try ctx.addCmd(.{ .tick = .{ .deadline_ms = std.math.maxInt(i64), .widget = self.widget() } });
                }
                if (is("seed_unsorted")) {
                    try app_pointer.timers.append(a, .{ .deadline_ms = 0, .widget = nodes[1].widget() });
                    try app_pointer.timers.append(a, .{ .deadline_ms = std.math.maxInt(i64), .widget = self.widget() });
                }
                if (is("focus") or is("focus_absent")) try ctx.requestFocus(nodes[1].widget());
                if (is("focus_invalid")) {
                    var invalid = nodes[1].widget();
                    invalid.eventHandler = null;
                    try ctx.requestFocus(invalid);
                }
                if (is("timers") or is("timer_nested") or is("error_tick")) {
                    for (1..4) |index| try ctx.addCmd(.{ .tick = .{ .deadline_ms = 0, .widget = nodes[index].widget() } });
                    try ctx.addCmd(.{ .tick = .{ .deadline_ms = std.math.maxInt(i64), .widget = self.widget() } });
                }
                if (is("commands")) {
                    try ctx.setTitle("proof-title");
                    try ctx.copyToClipboard("proof-clip");
                    try ctx.sendNotification("proof-note", "proof-body");
                    try ctx.queryColor(.fg);
                    try ctx.setMouseShape(.pointer);
                    try ctx.queueRefresh();
                }
            },
            .focus_in => {
                if (is("error_focus") or (is("error_focus_in") and self.id == 1)) return error.ProbeFailure;
                if (is("buffer_probe")) {
                    out("BARRIER\n", .{});
                    var byte: [1]u8 = undefined;
                    _ = try std.posix.read(held_fd, &byte);
                }
            },
            .focus_out => {
                if (is("error_focus_out")) return error.ProbeFailure;
            },
            .key_press => |key| {
                if (key.codepoint == 'q') ctx.quit = true;
                if (key.codepoint == 'e' and is("error_key")) return error.ProbeFailure;
                if (key.codepoint == 't') ctx.consumeEvent();
                if (key.codepoint == 'f' and ctx.phase == .at_target) {
                    try ctx.requestFocus(nodes[1].widget());
                    ctx.redraw = true;
                }
                if (key.codepoint == 'r' and ctx.phase == .at_target) try ctx.queueRefresh();
            },
            .tick => {
                ticks += 1;
                if (is("error_tick")) return error.ProbeFailure;
                if (is("timer_nested") and ticks == 1) try ctx.addCmd(.{ .tick = .{ .deadline_ms = 0, .widget = nodes[0].widget() } });
                if (ticks == (if (is("timer_nested")) @as(u8, 4) else 3)) ctx.quit = true;
            },
            .mouse_enter => {
                if (is("error_enter")) return error.ProbeFailure;
            },
            .mouse => {
                if (is("error_mouse")) return error.ProbeFailure;
            },
            else => {},
        }
    }
    fn draw(ptr: *anyopaque, ctx: fw.DrawContext) std.mem.Allocator.Error!fw.Surface {
        const self: *Node = @ptrCast(@alignCast(ptr));
        draws += 1;
        out("D|{d}|{d}|{d}|{d}|{d}|{d}\n", .{ self.id, draws, ctx.max.width.?, ctx.max.height.?, ctx.cell_size.width, ctx.cell_size.height });
        if (is("error_draw")) return error.OutOfMemory;
        if (is("layout_commands")) try event_context.addCmd(.queue_refresh);
        var surface = try fw.Surface.init(ctx.arena, self.widget(), .{ .width = ctx.max.width.?, .height = ctx.max.height.? });
        if (is("render_invalid")) surface.buffer = try ctx.arena.alloc(vaxis.Cell, 1);
        if (self.id == 0 and !is("focus_absent") and !is("render_invalid")) {
            var child = try fw.Surface.init(ctx.arena, nodes[1].widget(), .{ .width = 2, .height = 2 });
            child.writeCell(0, 0, .{ .char = .{ .grapheme = "X", .width = 1 } });
            const children = try ctx.arena.alloc(fw.SubSurface, 1);
            children[0] = .{ .origin = .{ .row = 1, .col = 1 }, .surface = child };
            surface.children = children;
        }
        return surface;
    }
};
fn trace(id: u8, kind: u8, phase: fw.EventContext.Phase, event: fw.Event) void {
    switch (event) {
        .key_press => |key| out("{c}|{d}|{s}|key|{d}\n", .{ kind, id, @tagName(phase), key.codepoint }),
        .mouse => |mouse| out("{c}|{d}|{s}|mouse|{d}|{d}|{s}|{s}\n", .{ kind, id, @tagName(phase), mouse.col, mouse.row, @tagName(mouse.button), @tagName(mouse.type) }),
        else => out("{c}|{d}|{s}|{s}\n", .{ kind, id, @tagName(phase), @tagName(event) }),
    }
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    mode = args[1];
    const rate = try std.fmt.parseInt(u8, args[2], 10);
    const release_fd = try std.fmt.parseInt(std.posix.fd_t, args[3], 10);
    held_fd = release_fd;
    for (&nodes, 0..) |*node, index| node.* = .{ .id = @intCast(index) };
    var app = try fw.App.init(a);
    app_pointer = &app;
    out("I|{d}|{d}|{d}|{d}|{d}|{d}\n", .{ @as(u5, @bitCast(app.vx.opts.kitty_keyboard_flags)), @intFromBool(app.vx.opts.system_clipboard_allocator != null), app.timers.items.len, @intFromBool(app.wants_focus != null), app.vx.screen.width, app.vx.screen.height });
    if (!is("init_only")) try app.vx.resize(a, app.tty.writer(), try vaxis.Tty.getWinsize(app.tty.fd));
    var result: []const u8 = "ok";
    if (!is("init_only")) app.run(nodes[0].widget(), .{ .framerate = rate }) catch |err| {
        result = @errorName(err);
    };
    out("R|{s}|{d}|{d}|{d}|{d}|{d}|{d}|{d}\n", .{ result, app.timers.items.len, @intFromBool(app.wants_focus != null), app.vx.screen.width, app.vx.screen.height, @intFromBool(app.vx.state.alt_screen), @intFromBool(app.vx.state.mouse), @intFromBool(app.vx.state.bracketed_paste) });
    app.deinit();
    out("DONE\n", .{});
    var release: [1]u8 = undefined;
    _ = try std.posix.read(release_fd, &release);
}
