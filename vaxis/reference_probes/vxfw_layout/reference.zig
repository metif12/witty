const std = @import("std");
const vx = @import("vaxis");
const fw = vx.vxfw;
const Out = std.Io.Writer;

fn dataset(a: std.mem.Allocator, id: u8) ![]fw.Size {
    const values: []const fw.Size = switch (id) {
        0 => &.{},
        1 => &.{.{ .width = 0, .height = 0 }},
        2 => &.{.{ .width = 1, .height = 1 }},
        3 => &.{ .{ .width = 3, .height = 1 }, .{ .width = 2, .height = 2 }, .{ .width = 4, .height = 3 } },
        4 => &.{ .{ .width = 0, .height = 0 }, .{ .width = 0, .height = 0 }, .{ .width = 0, .height = 0 } },
        5 => &.{.{ .width = 65535, .height = 0 }},
        6 => &.{.{ .width = 0, .height = 65535 }},
        7 => &.{ .{ .width = 65535, .height = 65535 }, .{ .width = 1, .height = 1 } },
        8 => &.{ .{ .width = 32767, .height = 32767 }, .{ .width = 32768, .height = 32768 } },
        9 => &.{ .{ .width = 65534, .height = 65534 }, .{ .width = 1, .height = 1 }, .{ .width = 1, .height = 1 } },
        10 => &.{ .{ .width = 5, .height = 2 }, .{ .width = 8, .height = 0 }, .{ .width = 2, .height = 5 } },
        12 => &.{ .{}, .{} },
        13 => &.{ .{ .width = 0, .height = 40000 }, .{} },
        else => &.{},
    };
    if (id == 11) {
        const result = try a.alloc(fw.Size, 258);
        @memset(result, .{});
        return result;
    }
    return a.dupe(fw.Size, values);
}
const Child = struct {
    spy: *Spy,
    index: usize,
    size: fw.Size,
    calls: usize = 0,
    fn widget(self: *Child) fw.Widget {
        return .{ .userdata = self, .drawFn = draw };
    }
    fn draw(ptr: *anyopaque, ctx: fw.DrawContext) std.mem.Allocator.Error!fw.Surface {
        const self: *Child = @ptrCast(@alignCast(ptr));
        const s = self.spy;
        s.trace.writer(s.alloc).print("{d},{d},{d},{d},{d},{d},{d},{d};", .{ self.index, self.calls, ctx.min.width, ctx.min.height, optional(ctx.max.width), optional(ctx.max.height), ctx.cell_size.width, ctx.cell_size.height }) catch unreachable;
        const call = s.calls;
        s.calls += 1;
        self.calls += 1;
        if (call == 0) switch (s.mutation) {
            1 => {
                if (s.padding) |p| {
                    p.padding = .{ .left = 1, .right = 2, .top = 1, .bottom = 2 };
                }
            },
            2 => {
                if (s.border) |b| {
                    b.labels = s.alt_labels;
                    b.style = .{ .fg = .{ .index = 5 }, .bold = true };
                }
            },
            3 => {
                if (s.items.len > 1) {
                    s.items[1].flex = 2;
                    s.children[1].size = .{ .width = 2, .height = 1 };
                }
            },
            4 => {
                if (s.items.len > 0) s.items[self.index].flex = 2;
            },
            5 => {
                if (s.items.len > 0) {
                    if (s.column) |f| {
                        f.children = s.items[0..1];
                    }
                    if (s.row) |f| {
                        f.children = s.items[0..1];
                    }
                }
            },
            else => {},
        };
        if (s.mutation == 8 and call == 2 and s.items.len > 0) s.items[0].flex = 2;
        if (s.mutation == 6 and !s.changed and ctx.max.width != null and ctx.max.height != null and s.items.len > 0) {
            if (s.column) |f| {
                f.children = s.items[0..1];
                s.changed = true;
            }
            if (s.row) |f| {
                f.children = s.items[0..1];
                s.changed = true;
            }
        }
        if (s.fail_at >= 0 and call == @as(usize, @intCast(s.fail_at))) return error.OutOfMemory;
        var size = self.size;
        switch (s.reply) {
            1 => size = ctx.min,
            2 => size = .{ .width = ctx.max.width orelse size.width, .height = ctx.max.height orelse size.height },
            3 => {
                if (ctx.max.width != null and ctx.max.height != null) {
                    size = ctx.min;
                    if (s.column != null) size.width = self.size.width;
                    if (s.row != null) size.height = self.size.height;
                }
            },
            4 => {
                if (ctx.max.width != null and ctx.max.height != null) size = .{ .width = 65535, .height = 65535 };
            },
            else => {},
        }
        return .{ .size = size, .widget = self.widget(), .buffer = &.{}, .children = &.{} };
    }
};
const Spy = struct {
    alloc: std.mem.Allocator,
    children: []Child,
    items: []fw.FlexItem,
    reply: u8,
    mutation: u8,
    fail_at: i64,
    calls: usize = 0,
    trace: std.ArrayList(u8) = .empty,
    owner: *anyopaque = undefined,
    changed: bool = false,
    padding: ?*fw.Padding = null,
    border: ?*fw.Border = null,
    column: ?*fw.FlexColumn = null,
    row: ?*fw.FlexRow = null,
    alt_labels: []fw.Border.BorderLabel,
    bytes: []u8,
};
fn optional(value: ?u16) i32 {
    return if (value) |n| @intCast(n) else -1;
}
fn num(parts: []const []const u8, index: usize) i64 {
    return std.fmt.parseInt(i64, parts[index], 10) catch unreachable;
}
fn label_bytes(a: std.mem.Allocator, id: u8) ![]u8 {
    return switch (id) {
        0 => a.dupe(u8, ""),
        1 => a.dupe(u8, "abc"),
        2 => a.dupe(u8, "a"),
        3 => a.dupe(u8, "e\xcc\x81\xe4\xb8\xadx"),
        4 => a.dupe(u8, "\x00\x1b\xffa"),
        5 => a.dupe(u8, "\xf0\x9f\x91\xa9\xe2\x80\x8d\xf0\x9f\x92\xbb"),
        6 => blk: {
            const bytes = try a.alloc(u8, 65535);
            @memset(bytes, 'a');
            break :blk bytes;
        },
        7 => blk: {
            const bytes = try a.alloc(u8, 65536);
            @memset(bytes, 'a');
            break :blk bytes;
        },
        8 => a.dupe(u8, "ab"),
        9 => blk: {
            var bytes: std.ArrayList(u8) = .empty;
            for (0..130) |i| {
                if (i != 0) try bytes.appendSlice(a, "\xe2\x80\x8d");
                try bytes.appendSlice(a, "\xf0\x9f\x91\xa9");
            }
            break :blk try bytes.toOwnedSlice(a);
        },
        else => unreachable,
    };
}
fn hash_byte(hash: *u64, byte: u8) void {
    hash.* = (hash.* ^ byte) *% 1099511628211;
}
fn cells_hash(surf: fw.Surface) u64 {
    var hash: u64 = 14695981039346656037;
    for (surf.buffer) |c| {
        for (c.char.grapheme) |b| hash_byte(&hash, b);
        hash_byte(&hash, 0);
        hash_byte(&hash, c.char.width);
        hash_byte(&hash, @intFromBool(c.default));
        hash_byte(&hash, @intFromBool(c.style.bold));
        hash_byte(&hash, @intFromBool(c.style.reverse));
        hash_byte(&hash, switch (c.style.fg) {
            .index => |i| i,
            .default => 0,
            else => unreachable,
        });
    }
    return hash;
}
fn surface(out: *Out, surf: fw.Surface, s: *Spy) !void {
    const id: usize = if (surf.widget.userdata == s.owner) 0 else blk: {
        const child: *Child = @ptrCast(@alignCast(surf.widget.userdata));
        break :blk child.index + 1;
    };
    try out.print("[{d},{d},{d},{d},{x},{d};", .{ surf.size.width, surf.size.height, id, surf.buffer.len, cells_hash(surf), surf.children.len });
    for (surf.children) |sub| {
        try out.print("({d},{d},{d})", .{ sub.origin.col, sub.origin.row, sub.z_index });
        try surface(out, sub.surface, s);
    }
    try out.writeByte(']');
}
fn record(out: *Out, a: std.mem.Allocator, p: []const []const u8) !void {
    const sizes = try dataset(a, @intCast(num(p, 5)));
    const children = try a.alloc(Child, sizes.len);
    const items = try a.alloc(fw.FlexItem, sizes.len);
    var s: Spy = .{ .alloc = a, .children = children, .items = items, .reply = @intCast(num(p, 7)), .mutation = @intCast(num(p, 8)), .fail_at = num(p, 9), .alt_labels = try a.alloc(fw.Border.BorderLabel, 1), .bytes = try label_bytes(a, @intCast(num(p, 14))) };
    s.alt_labels[0] = .{ .text = "m", .alignment = .bottom_left };
    const weight: usize = @intCast(num(p, 6));
    for (children, sizes, 0..) |*child, size, i| {
        child.* = .{ .spy = &s, .index = i, .size = size };
        items[i] = .{ .widget = child.widget(), .flex = if (weight == 999) 255 else @intCast((weight >> @as(u6, @intCast((i % 3) * 8))) & 255) };
    }
    var fallback: Child = .{ .spy = &s, .index = 0, .size = .{} };
    const widget = if (children.len == 0) fallback.widget() else children[0].widget();
    const ctx: fw.DrawContext = .{ .arena = a, .min = .{ .width = @intCast(num(p, 3)), .height = @intCast(num(p, 4)) }, .max = .{ .width = if (num(p, 1) < 0) null else @intCast(num(p, 1)), .height = if (num(p, 2) < 0) null else @intCast(num(p, 2)) }, .cell_size = .{ .width = 11, .height = 19 } };
    fw.DrawContext.init(@enumFromInt(num(p, 16)));
    var result: ?fw.Surface = null;
    var status: []const u8 = "ok";
    const kind = p[0][0];
    if (kind == 'A') {
        const all = fw.Padding.all(@intCast(num(p, 10)));
        const h = fw.Padding.horizontal(@intCast(num(p, 10)));
        const v = fw.Padding.vertical(@intCast(num(p, 10)));
        try out.print("{d},{d},{d},{d};{d},{d},{d},{d};{d},{d},{d},{d}\n", .{ all.left, all.right, all.top, all.bottom, h.left, h.right, h.top, h.bottom, v.left, v.right, v.top, v.bottom });
        return;
    }
    if (kind == 'C') {
        var view: fw.Center = .{ .child = widget };
        s.owner = &view;
        result = view.widget().draw(ctx) catch |e| blk: {
            status = @errorName(e);
            break :blk null;
        };
    }
    if (kind == 'P') {
        var view: fw.Padding = .{ .child = widget, .padding = .{ .left = @intCast(num(p, 10)), .right = @intCast(num(p, 11)), .top = @intCast(num(p, 12)), .bottom = @intCast(num(p, 13)) } };
        s.owner = &view;
        s.padding = &view;
        result = view.widget().draw(ctx) catch |e| blk: {
            status = @errorName(e);
            break :blk null;
        };
        try out.print("{d},{d},{d},{d}|", .{ view.padding.left, view.padding.right, view.padding.top, view.padding.bottom });
    }
    if (kind == 'S') {
        var view: fw.SizedBox = .{ .child = widget, .size = .{ .width = @intCast(num(p, 10)), .height = @intCast(num(p, 11)) } };
        s.owner = &view;
        result = view.widget().draw(ctx) catch |e| blk: {
            status = @errorName(e);
            break :blk null;
        };
    }
    if (kind == 'B') {
        const labels = try a.alloc(fw.Border.BorderLabel, if (s.bytes.len == 0) 0 else if (num(p, 15) == 6) 6 else 1);
        for (labels, 0..) |*label, i| label.* = .{ .text = s.bytes, .alignment = @enumFromInt(if (num(p, 15) == 6) i else @as(usize, @intCast(num(p, 15)))) };
        var view: fw.Border = .{ .child = widget, .labels = labels, .style = .{ .fg = .{ .index = 3 }, .reverse = true } };
        s.owner = &view;
        s.border = &view;
        result = view.widget().draw(ctx) catch |e| blk: {
            status = @errorName(e);
            break :blk null;
        };
        if (result) |surf| {
            var found: usize = 0;
            for (surf.buffer) |cell| {
                const ptr = @intFromPtr(cell.char.grapheme.ptr);
                if (ptr >= @intFromPtr(s.bytes.ptr) and ptr < @intFromPtr(s.bytes.ptr) + s.bytes.len) found += 1;
            }
            try out.print("{d},{d},{d}|", .{ found, view.labels.len, @intFromBool(view.style.bold) });
            if (num(p, 14) == 8) {
                try out.print("{x}|", .{cells_hash(surf)});
                s.bytes[0] = 'Z';
            }
        } else try out.writeAll("0,0,0|");
    }
    if (kind == 'V') {
        var view: fw.FlexColumn = .{ .children = items };
        s.owner = &view;
        s.column = &view;
        result = view.widget().draw(ctx) catch |e| blk: {
            status = @errorName(e);
            break :blk null;
        };
        try out.print("{d}|", .{view.children.len});
    }
    if (kind == 'H') {
        var view: fw.FlexRow = .{ .children = items };
        s.owner = &view;
        s.row = &view;
        result = view.widget().draw(ctx) catch |e| blk: {
            status = @errorName(e);
            break :blk null;
        };
        try out.print("{d}|", .{view.children.len});
    }
    try out.print("{s}|{d}|{s}|", .{ status, s.calls, s.trace.items });
    for (items) |item| try out.print("{d},", .{item.flex});
    try out.writeByte('|');
    if (result) |surf| try surface(out, surf, &s);
    try out.writeByte('\n');
}
pub fn main() !void {
    const a = std.heap.page_allocator;
    const args = try std.process.argsAlloc(a);
    const data = try std.fs.cwd().readFileAlloc(a, args[1], 64 * 1024 * 1024);
    var bytes: [65536]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&bytes);
    var lines = std.mem.splitScalar(u8, data, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var arena = std.heap.ArenaAllocator.init(a);
        defer arena.deinit();
        var parts: [17][]const u8 = undefined;
        var split = std.mem.splitScalar(u8, line, '|');
        for (&parts) |*part| part.* = split.next().?;
        try record(&writer.interface, arena.allocator(), &parts);
    }
    try writer.interface.flush();
}
