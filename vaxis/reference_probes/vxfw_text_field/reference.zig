const std = @import("std");
const vaxis = @import("vaxis");
const Input = vaxis.vxfw.TextField;
const Fw = vaxis.vxfw;
const Writer = std.Io.Writer;
fn uint(parts: []const []const u8, index: usize) !usize {
    return std.fmt.parseInt(usize, parts[index], 10);
}
fn bytes(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
    const decoded = try allocator.alloc(u8, value.len / 2);
    return try std.fmt.hexToBytes(decoded, value);
}
fn style(index: usize) vaxis.Style {
    return switch (index) {
        1 => .{ .fg = .{ .index = 3 }, .bg = .{ .index = 4 }, .ul = .{ .index = 5 }, .ul_style = .curly, .bold = true, .dim = true, .italic = true, .blink = true, .reverse = true, .invisible = true, .strikethrough = true },
        2 => .{ .fg = .{ .rgb = .{ 1, 2, 3 } }, .bg = .{ .rgb = .{ 5, 8, 13 } }, .ul = .{ .rgb = .{ 21, 34, 55 } }, .ul_style = .dashed, .italic = true },
        3 => .{ .ul_style = .double, .bold = true },
        else => .{},
    };
}
fn color(value: vaxis.Color) u32 {
    return switch (value) {
        .default => 0,
        .index => |index| 0x1000000 | @as(u32, index),
        .rgb => |rgb| 0x2000000 | (@as(u32, rgb[0]) << 16) | (@as(u32, rgb[1]) << 8) | @as(u32, rgb[2]),
    };
}
fn cell(writer: *Writer, value: vaxis.Cell) !void {
    const flags = @as(u8, @intFromBool(value.style.bold)) | (@as(u8, @intFromBool(value.style.dim)) << 1) | (@as(u8, @intFromBool(value.style.italic)) << 2) | (@as(u8, @intFromBool(value.style.blink)) << 3) | (@as(u8, @intFromBool(value.style.reverse)) << 4) | (@as(u8, @intFromBool(value.style.invisible)) << 5) | (@as(u8, @intFromBool(value.style.strikethrough)) << 6);
    for (value.char.grapheme) |byte| try writer.print("{x:0>2}", .{byte});
    try writer.print("/{d}/{d}/{d}/{d}/{d}/{d}/{d}/{d}/{s}/{s};", .{ value.char.width, color(value.style.fg), color(value.style.bg), color(value.style.ul), @intFromEnum(value.style.ul_style), flags, @intFromBool(value.default), @intFromBool(value.wrapped), value.link.uri, value.link.params });
    try writer.print("{d},{d},{d},{d},", .{ value.scale.scale, value.scale.numerator, value.scale.denominator, @intFromEnum(value.scale.vertical_alignment) });
    if (value.image) |img| try writer.print("{d};", .{img.img_id}) else try writer.writeAll("none;");
}

fn hex(writer: *Writer, value: []const u8) !void {
    for (value) |byte| try writer.print("{x:0>2}", .{byte});
}

fn state(writer: *Writer, input: Input) !void {
    const b = input.buf;
    try writer.print("{d},{d},{d};", .{ b.buffer.len, b.cursor, b.gap_size });
    if (b.cursor <= b.buffer.len and b.gap_size <= b.buffer.len - b.cursor) {
        try hex(writer, b.firstHalf());
        try writer.writeByte('/');
        try hex(writer, b.secondHalf());
    } else try writer.writeAll("invalid");
    try writer.print(";{d},{d},{d},{d},{d};", .{ input.draw_offset, input.prev_cursor_col, input.prev_cursor_idx, input.scroll_offset, input.prev_width });
    try hex(writer, input.previous_val);
    try writer.writeByte(';');
}

fn context(allocator: std.mem.Allocator, width: ?u16, height: u16) Fw.DrawContext {
    return .{ .arena = allocator, .min = .{ .height = height }, .max = .{ .width = width }, .cell_size = .{ .width = 10, .height = 20 } };
}

const Observation = struct {
    kind: u8,
    value: []const u8,
    current: []const u8,
    previous: []const u8,
    cursor: usize,
    gap: usize,
    offset: u16,
    col: u16,
    index: u16,
    consumed: bool,
    redraw: bool,
};
const Spy = struct {
    allocator: std.mem.Allocator,
    field: *Input,
    mode: usize,
    observations: std.ArrayList(Observation) = .empty,

    fn observe(self: *Spy, ctx: *Fw.EventContext, value: []const u8, kind: u8) !void {
        try self.observations.append(self.allocator, .{
            .kind = kind, .value = try self.allocator.dupe(u8, value),
            .current = try self.field.buf.dupe(), .previous = try self.allocator.dupe(u8, self.field.previous_val),
            .cursor = self.field.buf.cursor, .gap = self.field.buf.gap_size,
            .offset = self.field.draw_offset, .col = self.field.prev_cursor_col, .index = self.field.prev_cursor_idx,
            .consumed = ctx.consume_event, .redraw = ctx.redraw,
        });
        if (self.mode == 7 or self.mode == 9) {
            try self.field.insertSliceAtCursor("!");
            ctx.consume_event = false;
            ctx.redraw = false;
        } else if (self.mode == 8) {
            self.field.clearRetainingCapacity();
            ctx.quit = true;
        }
        if (self.mode == 6 or self.mode == 9 or (kind == 'C' and self.mode == 4) or (kind == 'S' and self.mode == 5)) return error.CallbackFailure;
    }

    fn change(ptr: ?*anyopaque, ctx: *Fw.EventContext, value: []const u8) anyerror!void {
        const self: *Spy = @ptrCast(@alignCast(ptr.?));
        try self.observe(ctx, value, 'C');
    }
    fn submit(ptr: ?*anyopaque, ctx: *Fw.EventContext, value: []const u8) anyerror!void {
        const self: *Spy = @ptrCast(@alignCast(ptr.?));
        try self.observe(ctx, value, 'S');
    }
};

fn trap(mode: []const u8) !void {
    const allocator = std.heap.page_allocator;
    var input = Input.init(allocator);
    Fw.DrawContext.init(.unicode);
    if (std.mem.eql(u8, mode, "trap_count") or std.mem.eql(u8, mode, "trap_second_count")) {
        const repeated = try allocator.alloc(u8, 65536);
        @memset(repeated, if (std.mem.eql(u8, mode, "trap_second_count")) 0 else 'a');
        try input.buf.insertSliceAtCursor(repeated);
        if (std.mem.eql(u8, mode, "trap_count")) _ = input.graphemesBeforeCursor() else {
            input.buf.moveGapLeft(repeated.len);
            _ = try input.draw(context(allocator, 1, 1));
        }
    } else if (std.mem.eql(u8, mode, "trap_width")) {
        const repeated = try allocator.alloc(u8, 32768 * 3);
        for (0..32768) |i| @memcpy(repeated[i * 3 ..][0..3], "界");
        try input.buf.insertSliceAtCursor(repeated);
        _ = input.widthToCursor(context(allocator, 1, 1));
    } else if (std.mem.eql(u8, mode, "trap_grapheme_width")) {
        const repeated = try allocator.alloc(u8, 4 + 128 * 4);
        @memcpy(repeated[0..4], "👍");
        for (0..128) |i| @memcpy(repeated[4 + i * 4 ..][0..4], "🏽");
        try input.buf.insertSliceAtCursor(repeated);
        input.buf.moveGapLeft(repeated.len);
        Fw.DrawContext.init(.wcwidth);
        _ = try input.draw(context(allocator, 512, 1));
    } else if (std.mem.eql(u8, mode, "trap_surface_size")) {
        _ = try input.draw(context(allocator, 32768, 2));
    } else if (std.mem.eql(u8, mode, "trap_unbounded")) {
        _ = try input.draw(context(allocator, null, 1));
    } else if (std.mem.startsWith(u8, mode, "trap_utf8_")) {
        try input.buf.insertSliceAtCursor("\xff\xcc\x81");
        if (std.mem.eql(u8, mode, "trap_utf8_left")) input.cursorLeft() else if (std.mem.eql(u8, mode, "trap_utf8_delete")) input.deleteBeforeCursor() else if (std.mem.eql(u8, mode, "trap_utf8_count")) _ = input.graphemesBeforeCursor() else if (std.mem.eql(u8, mode, "trap_utf8_width")) _ = input.widthToCursor(context(allocator, 1, 1)) else if (std.mem.eql(u8, mode, "trap_utf8_right")) {
            input.buf.moveGapLeft(3);
            input.cursorRight();
        } else if (std.mem.eql(u8, mode, "trap_utf8_after")) {
            input.buf.moveGapLeft(3);
            input.deleteAfterCursor();
        } else if (std.mem.eql(u8, mode, "trap_utf8_draw")) _ = try input.draw(context(allocator, 1, 1));
    } else if (std.mem.eql(u8, mode, "trap_unicode")) {
        try input.insertSliceAtCursor("\xff\xcc\x81");
    } else if (std.mem.eql(u8, mode, "trap_slice_short")) {
        try input.buf.insertSliceAtCursor("abc");
        var output: [2]u8 = undefined;
        _ = input.sliceToCursor(&output);
    } else if (std.mem.eql(u8, mode, "trap_slice_alias")) {
        try input.buf.insertSliceAtCursor("abc");
        _ = input.sliceToCursor(input.buf.buffer);
    }
    std.debug.print("UNEXPECTED: returned\n", .{});
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    if (std.mem.startsWith(u8, args[1], "trap_")) return trap(args[1]);
    const file = try std.fs.cwd().openFile(args[1], .{});
    defer file.close();
    const data = try file.readToEndAlloc(allocator, 64 * 1024 * 1024);
    var stdoutbuf: [65536]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&stdoutbuf);
    const writer = &stdout.interface;
    const codes = [_]u21{ vaxis.Key.backspace, vaxis.Key.delete, vaxis.Key.left, vaxis.Key.right, vaxis.Key.home, vaxis.Key.end, 'a', 'b', 'd', 'e', 'f', 'k', 'u', 'w', 'x', vaxis.Key.enter, 'j' };
    var lines = std.mem.splitScalar(u8, data, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var fields = std.mem.splitScalar(u8, line, '|');
        var list: std.ArrayList([]const u8) = .empty;
        while (fields.next()) |part| try list.append(allocator, part);
        defer list.deinit(allocator);
        const parts = list.items;
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const scratch = arena.allocator();
        var input = Input.init(scratch);
        const text = try bytes(scratch, parts[1]);
        switch (parts[0][0]) {
            'I' => for (0..try uint(parts, 2)) |_| try input.insertSliceAtCursor(text),
            'S' => {
                try input.buf.insertSliceAtCursor(text);
                input.buf.moveGapLeft(try uint(parts, 2));
                const output = try scratch.alloc(u8, input.buf.cursor + try uint(parts, 3));
                @memset(output, 0xa5);
                const prefix = input.sliceToCursor(output);
                if (prefix.len > 0) output[0] ^= 0xff;
                try writer.print("{d};", .{@intFromBool(prefix.ptr == output.ptr)});
                try hex(writer, prefix); try writer.writeByte(';');
                try hex(writer, output); try writer.writeByte(';');
            },
            'M', 'D', 'P' => {
                try input.buf.insertSliceAtCursor(text);
                input.buf.moveGapLeft(try uint(parts, 2));
                const action = try uint(parts, 3);
                Fw.DrawContext.init(@enumFromInt(try uint(parts, 4)));
                input.draw_offset = @intCast(try uint(parts, 5));
                input.prev_cursor_col = 19; input.prev_cursor_idx = 23;
                input.prev_width = @intCast(try uint(parts, 6));
                input.scroll_offset = @intCast(try uint(parts, 7));
                if (parts[0][0] == 'M') {
                    switch (action) {
                        0 => input.cursorLeft(), 1 => input.cursorRight(),
                        2 => input.deleteBeforeCursor(), 3 => input.deleteAfterCursor(),
                        4 => input.deleteToStart(), 5 => input.deleteToEnd(),
                        6 => input.moveBackwardWordwise(), 7 => input.moveForwardWordwise(),
                        8 => input.deleteWordBefore(), 9 => input.deleteWordAfter(),
                        10 => input.clearAndFree(), 11 => input.clearRetainingCapacity(),
                        12 => { try hex(writer, try input.toOwnedSlice()); try writer.writeByte(';'); },
                        13 => { try writer.print("{d};", .{input.graphemesBeforeCursor()}); },
                        14 => { try writer.print("{d};", .{input.widthToCursor(context(scratch, 16, 1))}); },
                        else => input.reset(),
                    }
                } else {
                    input.style = style(try uint(parts, 9));
                    const surface = try input.widget().draw(context(scratch, @intCast(action), @intCast(try uint(parts, 8))));
                    try writer.print("{d},{d};", .{ surface.size.width, surface.size.height });
                    if (surface.cursor) |cursor| try writer.print("{d},{d},{d};", .{ cursor.col, cursor.row, @intFromEnum(cursor.shape) }) else try writer.writeAll("none;");
                    if (parts[0][0] == 'P') {
                        const base = @intFromPtr(input.buf.buffer.ptr);
                        const limit = base + input.buf.buffer.len;
                        for (surface.buffer) |value| {
                            const address = @intFromPtr(value.char.grapheme.ptr);
                            if (value.char.grapheme.len == 0) try writer.writeAll("empty,") else if (address >= base and address <= limit and value.char.grapheme.len <= limit - address) try writer.print("{d},", .{address - base}) else try writer.writeAll("external,");
                        }
                        try writer.writeByte(';');
                        if (input.buf.firstHalf().len > 0) input.buf.buffer[0] ^= 0x20;
                        if (input.buf.secondHalf().len > 0) input.buf.buffer[input.buf.cursor + input.buf.gap_size] ^= 0x20;
                    }
                    for (surface.buffer) |value| try cell(writer, value);
                }
            },
            'E' => {
                try input.buf.insertSliceAtCursor(text);
                input.buf.moveGapLeft(try uint(parts, 2));
                input.draw_offset = 7; input.prev_cursor_col = 11; input.prev_cursor_idx = 13; input.prev_width = 17;
                input.previous_val = try bytes(scratch, parts[8]);
                var spy: Spy = .{ .allocator = scratch, .field = &input, .mode = try uint(parts, 7) };
                input.userdata = &spy;
                if (spy.mode == 1 or spy.mode == 3 or spy.mode == 4 or spy.mode == 6 or spy.mode >= 7) input.onChange = Spy.change;
                if (spy.mode == 2 or spy.mode == 3 or spy.mode == 5 or spy.mode == 6 or spy.mode >= 7) input.onSubmit = Spy.submit;
                const flags = try uint(parts, 9);
                var ctx: Fw.EventContext = .{ .alloc = scratch, .cmds = .empty, .redraw = flags & 1 != 0, .consume_event = flags & 2 != 0, .quit = flags & 4 != 0 };
                const keytext: ?[]const u8 = if (std.mem.eql(u8, parts[5], "none")) null else try bytes(scratch, parts[5]);
                const key: vaxis.Key = .{ .codepoint = codes[try uint(parts, 3)], .mods = @bitCast(@as(u8, @intCast(try uint(parts, 4)))), .text = keytext };
                const event: Fw.Event = switch (try uint(parts, 6)) { 1 => .focus_in, 2 => .focus_out, 3 => .{ .key_release = key }, 4 => .init, else => .{ .key_press = key } };
                var failure: []const u8 = "none";
                input.widget().handleEvent(&ctx, event) catch |err| { failure = @errorName(err); };
                try writer.print("{s},{d},{d},{d};", .{ failure, @intFromBool(ctx.consume_event), @intFromBool(ctx.redraw), @intFromBool(ctx.quit) });
                for (spy.observations.items) |record| {
                    try writer.print("{c}:", .{record.kind}); try hex(writer, record.value); try writer.writeByte('/');
                    try hex(writer, record.current); try writer.writeByte('/'); try hex(writer, record.previous);
                    try writer.print("/{d},{d},{d},{d},{d},{d},{d};", .{record.cursor, record.gap, record.offset, record.col, record.index, @intFromBool(record.consumed), @intFromBool(record.redraw)});
                }
            },
            else => return error.InvalidMode,
        }
        try state(writer, input);
        try writer.writeByte('\n');
    }
    try writer.flush();
}
