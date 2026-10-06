const std = @import("std");
const vaxis = @import("vaxis");
const fw = vaxis.vxfw;

fn draw(_: *anyopaque, _: fw.DrawContext) std.mem.Allocator.Error!fw.Surface {
    return error.OutOfMemory;
}

fn widget(id: usize) fw.Widget {
    return .{ .userdata = @ptrFromInt(id), .drawFn = draw };
}

fn focusId(value: ?fw.Widget) usize {
    return if (value) |w| @intFromPtr(w.userdata) else 0;
}

pub fn main() !void {
    var writer = std.Io.Writer.Allocating.init(std.heap.page_allocator);
    defer writer.deinit();
    const out = &writer.writer;
    try out.print("D|{d}\n", .{(fw.App.Options{}).framerate});
    for (0..256) |fps| {
        var opts: fw.App.Options = .{};
        opts.framerate = @intCast(fps);
        var copied = opts;
        copied.framerate = @intCast(255 - fps);
        try out.print("O|{d}|{d}\n", .{ opts.framerate, copied.framerate });
    }
    const widths = [_]u16{ 0, 1, 31, 255, 65535 };
    const deadlines = [_]i64{ std.math.minInt(i64), -1, 0, 17, std.math.maxInt(i64) };
    for (widths) |width| for (0..32) |flags| for (0..2) |clipboard| for (0..4) |count| for (0..4) |focus| {
        var storage = [_]fw.Tick{
            .{ .deadline_ms = deadlines[0], .widget = widget(1) },
            .{ .deadline_ms = deadlines[3], .widget = widget(2) },
            .{ .deadline_ms = deadlines[4], .widget = widget(3) },
        };
        var app: fw.App = .{
            .allocator = std.heap.page_allocator,
            .tty = undefined,
            .vx = .{
                .screen = .{ .width = width },
                .screen_last = undefined,
                .opts = .{
                    .kitty_keyboard_flags = @bitCast(@as(u5, @intCast(flags))),
                    .system_clipboard_allocator = if (clipboard != 0) std.heap.page_allocator else null,
                },
            },
            .timers = .{ .items = storage[0..count], .capacity = storage.len },
            .wants_focus = if (focus == 0) null else widget(focus),
            .buffer = undefined,
        };
        var copied = app;
        const shared = app.timers.items.ptr == copied.timers.items.ptr;
        if (count != 0) copied.timers.items[0].deadline_ms = deadlines[(flags + focus) % deadlines.len];
        copied.timers.items = copied.timers.items[0..if (count == 0) 0 else count - 1];
        copied.wants_focus = if (focus == 0) widget(9) else null;
        copied.vx.screen.width = width ^ 65535;
        copied.vx.opts.kitty_keyboard_flags = @bitCast(@as(u5, @intCast(31 - flags)));
        app.tty = undefined;
        try out.print("A|{d}|{d}|{d}|{d}|{d}|{d}|{d}|{d}|{d}|{d}|{d}\n", .{
            app.vx.screen.width,                                              copied.vx.screen.width,
            @as(u5, @bitCast(app.vx.opts.kitty_keyboard_flags)),              @as(u5, @bitCast(copied.vx.opts.kitty_keyboard_flags)),
            @intFromBool(app.vx.opts.system_clipboard_allocator != null),     app.timers.items.len,
            copied.timers.items.len,                                          @intFromBool(shared),
            if (count == 0) @as(i64, 0) else app.timers.items[0].deadline_ms, focusId(app.wants_focus),
            focusId(copied.wants_focus),
        });
    };
    var stdout = std.fs.File.stdout().writerStreaming(&.{});
    try stdout.interface.writeAll(writer.written());
}
