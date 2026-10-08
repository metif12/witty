const std = @import("std");
const png = @import("src/formats/png/types.zig");
const EncoderOptions = @import("src/formats/png.zig").PNG.EncoderOptions;
const filtering = @import("src/formats/png/filtering.zig");
const W = std.Io.Writer;
fn n(p: []const []const u8, i: usize) !u32 {
    return std.fmt.parseInt(u32, p[i], 10);
}
fn fields(out: *W, h: png.HeaderData) !void {
    try out.print("{d},{d},{d},{d},{d},{d},{d}", .{ h.width, h.height, h.bit_depth, @intFromEnum(h.color_type), @intFromEnum(h.compression_method), @intFromEnum(h.filter_method), @intFromEnum(h.interlace_method) });
}
fn hex(out: *W, bytes: []const u8) !void {
    for (bytes) |b| try out.print("{x:0>2}", .{b});
}
fn choice(value: u32) filtering.FilterChoice {
    return switch (value) {
        0 => .try_all,
        1 => .heuristic,
        else => .{ .specified = @enumFromInt(value - 2) },
    };
}
fn options(out: *W, value: EncoderOptions) !void {
    try out.print("{d},{d},{d}", .{ @intFromBool(value.interlaced), @intFromEnum(std.meta.activeTag(value.filter_choice)), if (value.filter_choice == .specified) @intFromEnum(value.filter_choice.specified) else @as(u8, 0) });
}
fn record(out: *W, p: []const []const u8) !void {
    if (p[0][0] == 'H') {
        var h: png.HeaderData = .{ .width = try n(p, 1), .height = try n(p, 2), .bit_depth = @intCast(try n(p, 3)), .color_type = @enumFromInt(try n(p, 4)), .compression_method = @enumFromInt(try n(p, 5)), .filter_method = @enumFromInt(try n(p, 6)), .interlace_method = @enumFromInt(try n(p, 7)) };
        const before = h;
        var copy = h;
        switch (try n(p, 8)) {
            0 => copy.width = 27,
            1 => copy.height = 9,
            2 => copy.bit_depth = 16,
            3 => copy.color_type = .rgba_color,
            4 => copy.compression_method = @enumFromInt(255),
            5 => copy.filter_method = @enumFromInt(1),
            6 => copy.interlace_method = .adam7,
            else => {},
        }
        h.width ^= 1;
        try fields(out, before);
        try out.writeByte('|');
        try fields(out, h);
        try out.writeByte('|');
        try fields(out, copy);
        try out.print("|{d},{d}", .{ @intFromBool(h.isValid()), @intFromBool(copy.isValid()) });
    } else if (p[0][0] == 'C') {
        var a: [4:0]u8 = @splat(0);
        var b: [4:0]u8 = @splat(0);
        _ = try std.fmt.hexToBytes(a[0..4], p[1]);
        _ = try std.fmt.hexToBytes(b[0..4], p[2]);
        var c = png.Chunk{ .id = try n(p, 3), .name = &a };
        var copy = c;
        copy.id = try n(p, 4);
        copy.name = &b;
        a[try n(p, 5)] = @intCast(try n(p, 6));
        c.id ^= 0xffffffff;
        try out.print("{d}|", .{c.id});
        try hex(out, c.name);
        try out.print("|{d}|", .{copy.id});
        try hex(out, copy.name);
    } else if (p[0][0] == 'N') {
        var h = png.ChunkHeader{ .length = try n(p, 1), .type = try n(p, 2) };
        var copy = h;
        const borrowed = h.name();
        copy.length = try n(p, 3);
        copy.type = try n(p, 4);
        h.type ^= 0xffffffff;
        try out.print("{d},{d}|", .{ h.length, h.type });
        try hex(out, borrowed);
        try out.print("|{d},{d}|", .{ copy.length, copy.type });
        try hex(out, copy.name());
    } else if (p[0][0] == 'O') {
        var original: EncoderOptions = .{};
        try options(out, original);
        try out.writeByte('|');
        original.interlaced = try n(p, 1) != 0;
        original.filter_choice = choice(try n(p, 2));
        var copy = original;
        copy.interlaced = !copy.interlaced;
        copy.filter_choice = choice(try n(p, 3));
        try options(out, original);
        try out.writeByte('|');
        try options(out, copy);
    } else {
        const original: filtering.FilterChoice = .{ .specified = @enumFromInt(try n(p, 1)) };
        var copy = original;
        copy.specified = @enumFromInt(try n(p, 2));
        try out.print("{d},{d}", .{ @intFromEnum(original.specified), @intFromEnum(copy.specified) });
    }
    try out.writeByte('\n');
}
pub fn main() !void {
    const a = std.heap.page_allocator;
    const args = try std.process.argsAlloc(a);
    const input = try std.fs.cwd().readFileAlloc(a, args[1], 64 * 1024 * 1024);
    var buffer: [65536]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&buffer);
    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| {
        var tokens = std.mem.splitScalar(u8, line, '|');
        var parts: [12][]const u8 = undefined;
        var len: usize = 0;
        while (tokens.next()) |part| {
            parts[len] = part;
            len += 1;
        }
        try record(&stdout.interface, parts[0..len]);
    }
    try stdout.interface.flush();
}
