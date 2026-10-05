const std = @import("std");
const vaxis = @import("vaxis");
const a = std.heap.page_allocator;

fn trap(mode: []const u8) !void {
    if (std.mem.eql(u8, mode, "trap_iter_underflow")) {
        var iter = vaxis.unicode.graphemeIterator("\xff\xcc\x81");
        _ = iter.next();
    } else if (std.mem.eql(u8, mode, "trap_context_underflow")) {
        const context: vaxis.vxfw.DrawContext = .{ .arena = a, .min = .{}, .max = .{}, .cell_size = .{} };
        var iter = context.graphemeIterator("\xff\xcc\x81");
        _ = iter.next();
    } else if (std.mem.startsWith(u8, mode, "trap_width_underflow_")) {
        const method: vaxis.gwidth.Method = if (std.mem.endsWith(u8, mode, "unicode")) .unicode else .no_zwj;
        _ = vaxis.gwidth.gwidth("\xff\xcc\x81", method);
    } else if (std.mem.startsWith(u8, mode, "trap_width_ascii_") or std.mem.startsWith(u8, mode, "trap_width_wide_")) {
        const wide = std.mem.startsWith(u8, mode, "trap_width_wide_");
        const text = try a.alloc(u8, if (wide) 32768 * 3 else 65536);
        if (wide) {
            for (0..32768) |i| @memcpy(text[i * 3 ..][0..3], "界");
        } else @memset(text, 'a');
        const method: vaxis.gwidth.Method = if (std.mem.endsWith(u8, mode, "unicode")) .unicode else if (std.mem.endsWith(u8, mode, "wcwidth")) .wcwidth else .no_zwj;
        _ = vaxis.gwidth.gwidth(text, method);
    } else if (std.mem.eql(u8, mode, "trap_width_split")) {
        const text = try a.alloc(u8, 65536 + 3);
        @memset(text, 'a');
        @memcpy(text[32768..][0..3], "\xe2\x80\x8d");
        _ = vaxis.gwidth.gwidth(text, .no_zwj);
    } else if (std.mem.eql(u8, mode, "trap_span_add")) {
        _ = (vaxis.unicode.Grapheme{ .start = std.math.maxInt(usize), .len = 1 }).bytes("");
    } else if (std.mem.eql(u8, mode, "trap_span_bound")) {
        _ = (vaxis.unicode.Grapheme{ .start = 1, .len = 2 }).bytes("ab");
    } else if (std.mem.eql(u8, mode, "trap_span_start")) {
        _ = (vaxis.unicode.Grapheme{ .start = std.math.maxInt(usize), .len = 0 }).bytes("ab");
    } else return error.InvalidTrap;
    var buffer: [64]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&buffer);
    try stdout.interface.writeAll("UNEXPECTED\n");
    try stdout.interface.flush();
}

fn hex(out: *std.Io.Writer, bytes: []const u8) !void {
    for (bytes) |byte| try out.print("{x:0>2}", .{byte});
}

fn mutate(text: []u8, spec: []const u8) !void {
    var changes = std.mem.splitScalar(u8, spec, ',');
    while (changes.next()) |change| {
        if (change.len == 0) continue;
        var fields = std.mem.splitScalar(u8, change, ':');
        const index = try std.fmt.parseInt(usize, fields.next().?, 10);
        text[index] = try std.fmt.parseInt(u8, fields.next().?, 16);
    }
}

fn view(out: *std.Io.Writer, bytes: ?[]const u8, text: []const u8) !void {
    if (bytes) |value| {
        try out.print("{d},{d}:", .{ @intFromPtr(value.ptr) - @intFromPtr(text.ptr), value.len });
        try hex(out, value);
    } else try out.writeAll("none");
    try out.writeByte(';');
}

fn spanBytes(span: ?vaxis.unicode.Grapheme, text: []const u8) ?[]const u8 {
    return if (span) |value| value.bytes(text) else null;
}

fn mutableRow(out: *std.Io.Writer, number: usize, text: []u8, initial: []const u8, later: []const u8) !void {
    var iter = vaxis.unicode.GraphemeIterator.init(text);
    var factory = vaxis.unicode.graphemeIterator(text);
    const context: vaxis.vxfw.DrawContext = .{ .arena = a, .min = .{}, .max = .{}, .cell_size = .{} };
    var framework = context.graphemeIterator(text);
    try mutate(text, initial);
    const views = [_]?[]const u8{ spanBytes(iter.next(), text), spanBytes(factory.next(), text), spanBytes(framework.next(), text) };
    try mutate(text, later);
    try out.print("{d}|M|", .{number});
    for (views) |bytes| try view(out, bytes, text);
    for (0..text.len + 3) |_| {
        try out.writeByte('|');
        try view(out, spanBytes(iter.next(), text), text);
        try view(out, spanBytes(factory.next(), text), text);
        try view(out, spanBytes(framework.next(), text), text);
    }
    try out.writeByte('\n');
}

pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    if (std.mem.startsWith(u8, args[1], "trap_")) return trap(args[1]);
    const content = try std.fs.cwd().readFileAlloc(a, args[1], 32 * 1024 * 1024);
    var buffer: [65536]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&buffer);
    const out = &stdout.interface;
    var lines = std.mem.splitScalar(u8, content, '\n');
    var number: usize = 0;
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var parts = std.mem.splitScalar(u8, line, '|');
        const kind = parts.next().?;
        const encoded = parts.next().?;
        const unit = try a.alloc(u8, encoded.len / 2);
        _ = try std.fmt.hexToBytes(unit, encoded);
        const repeat = try std.fmt.parseInt(usize, parts.next().?, 10);
        const text = try a.alloc(u8, unit.len * repeat);
        for (0..repeat) |i| @memcpy(text[i * unit.len ..][0..unit.len], unit);
        if (std.mem.eql(u8, kind, "M")) {
            try mutableRow(out, number, text, parts.next().?, parts.next().?);
            number += 1;
            continue;
        }
        try out.print("{d}|{d},{d},{d}|", .{ number, vaxis.gwidth.gwidth(text, .unicode), vaxis.gwidth.gwidth(text, .wcwidth), vaxis.gwidth.gwidth(text, .no_zwj) });
        var iter = vaxis.unicode.GraphemeIterator.init(text);
        var other = vaxis.unicode.graphemeIterator(text);
        const context: vaxis.vxfw.DrawContext = .{ .arena = a, .min = .{}, .max = .{}, .cell_size = .{} };
        var framework = context.graphemeIterator(text);
        for ([_]vaxis.gwidth.Method{ .unicode, .wcwidth, .no_zwj }) |method| {
            vaxis.vxfw.DrawContext.init(method);
            if (context.stringWidth(text) != vaxis.gwidth.gwidth(text, method)) return error.ContextWidthMismatch;
        }
        var count: usize = 0;
        var first: usize = 0;
        var last: usize = 0;
        while (iter.next()) |span| {
            const alt = other.next().?;
            if (span.start != alt.start or span.len != alt.len) return error.FactoryMismatch;
            if (count == 0) first = span.len;
            last = span.len;
            count += 1;
            const bytes = span.bytes(text);
            const fw = framework.next().?.bytes(text);
            if (!std.mem.eql(u8, fw, bytes) or @intFromPtr(fw.ptr) != @intFromPtr(bytes.ptr)) return error.ContextIteratorMismatch;
            const borrowed = @intFromPtr(bytes.ptr) == @intFromPtr(text.ptr) + span.start;
            if (std.mem.eql(u8, kind, "S")) {
                try out.print("{d},{d},{d}:", .{ span.start, span.len, @intFromBool(borrowed) });
                try hex(out, bytes);
                try out.writeByte(';');
            } else if (!borrowed) return error.NotBorrowed;
        }
        var exhausted = true;
        for (0..3) |_| {
            if (iter.next() != null or other.next() != null or framework.next() != null) exhausted = false;
        }
        if (std.mem.eql(u8, kind, "B")) {
            const span: vaxis.unicode.Grapheme = .{
                .start = try std.fmt.parseInt(usize, parts.next().?, 10),
                .len = try std.fmt.parseInt(usize, parts.next().?, 10),
            };
            const bytes = span.bytes(text);
            try out.print("{d},{d},{d}:", .{ span.start, span.len, @intFromBool(@intFromPtr(bytes.ptr) == @intFromPtr(text.ptr) + span.start) });
            try hex(out, bytes);
        }
        // Source has no first-grapheme-length helper: the public iterator's
        // first span supplies that adapter's reference value.
        try out.print("|{d},{d},{d},{d}\n", .{ count, first, last, @intFromBool(exhausted) });
        number += 1;
    }
    try out.flush();
}
