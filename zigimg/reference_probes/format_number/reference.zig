const std = @import("std");
const Number = std.fmt.Number;
const Options = std.fmt.Options;
fn optional(text: []const u8) !?usize {
    return if (std.mem.eql(u8, text, "-")) null else try std.fmt.parseInt(usize, text, 10);
}
fn emitOptional(w: *std.Io.Writer, value: ?usize) !void {
    if (value) |n| try w.print("{d}", .{n}) else try w.writeByte('-');
}
fn emitNumber(w: *std.Io.Writer, n: Number) !void {
    try w.print("{d},{d},", .{ @intFromEnum(n.mode), @intFromEnum(n.case) });
    try emitOptional(w, n.precision);
    try w.writeByte(',');
    try emitOptional(w, n.width);
    try w.print(",{d},{d},", .{ @intFromEnum(n.alignment), n.fill });
    if (n.mode.base()) |base| try w.print("{d}", .{base}) else try w.writeByte('-');
    try w.writeByte(';');
}
fn emitOptions(w: *std.Io.Writer, o: Options) !void {
    try emitOptional(w, o.precision);
    try w.writeByte(',');
    try emitOptional(w, o.width);
    try w.print(",{d},{d};", .{ @intFromEnum(o.alignment), o.fill });
}
fn changed(n: Number, field: u8, seed: usize) Number {
    var result = n;
    switch (field) {
        0 => result.mode = @enumFromInt(seed % 5),
        1 => result.case = @enumFromInt(seed % 2),
        2 => result.precision = if (seed % 3 == 0) null else seed,
        3 => result.width = if (seed % 4 == 0) null else std.math.maxInt(usize) - seed,
        4 => result.alignment = @enumFromInt(seed % 3),
        5 => result.fill = @truncate(seed),
        else => unreachable,
    }
    return result;
}
fn changedOptions(o: Options, field: u8, seed: usize) Options {
    var result = o;
    switch (field % 4) {
        0 => result.precision = if (seed % 3 == 0) null else seed,
        1 => result.width = if (seed % 4 == 0) null else std.math.maxInt(usize) - seed,
        2 => result.alignment = @enumFromInt(seed % 3),
        3 => result.fill = @truncate(seed),
        else => unreachable,
    }
    return result;
}
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const argv = try std.process.argsAlloc(allocator);
    const contents = try std.fs.cwd().readFileAlloc(allocator, argv[1], 16 * 1024 * 1024);
    var lines = std.mem.tokenizeScalar(u8, contents, '\n');
    var buffer: [64 * 1024]u8 = undefined;
    var output = std.fs.File.stdout().writer(&buffer);
    const w = &output.interface;
    while (lines.next()) |line| {
        var parts = std.mem.splitScalar(u8, line, '|');
        const form = try std.fmt.parseInt(u8, parts.next().?, 10);
        const operation = try std.fmt.parseInt(u8, parts.next().?, 10);
        const field = try std.fmt.parseInt(u8, parts.next().?, 10);
        const mode: Number.Mode = @enumFromInt(try std.fmt.parseInt(u8, parts.next().?, 10));
        const case: std.fmt.Case = @enumFromInt(try std.fmt.parseInt(u8, parts.next().?, 10));
        var args: Options = .{ .precision = try optional(parts.next().?), .width = try optional(parts.next().?), .alignment = @enumFromInt(try std.fmt.parseInt(u8, parts.next().?, 10)), .fill = try std.fmt.parseInt(u8, parts.next().?, 10) };
        const seed = try std.fmt.parseInt(usize, parts.next().?, 10);
        var original: Number = switch (form) {
            0 => .{},
            1 => .{ .mode = mode, .case = case },
            2 => .{ .mode = mode, .case = case, .precision = args.precision, .width = args.width, .alignment = args.alignment, .fill = args.fill },
            3 => args.toNumber(mode, case),
            4 => .{ .precision = args.precision, .width = args.width },
            else => unreachable,
        };
        var copy = original;
        var returned = original;
        try emitNumber(w, original);
        try emitOptions(w, args);
        switch (operation) {
            0 => {},
            1 => copy = changed(copy, field, seed),
            2 => original = changed(original, field, seed),
            3 => args = changedOptions(args, field, seed),
            4 => {
                copy = changed(copy, field, seed);
                returned = changed(copy, (field + 1) % 6, seed + 1);
            },
            5 => original = .{},
            6 => {
                args = changedOptions(args, field, seed);
                original = args.toNumber(@enumFromInt(seed % 5), @enumFromInt(seed % 2));
            },
            else => unreachable,
        }
        try emitNumber(w, original);
        try emitNumber(w, copy);
        try emitNumber(w, returned);
        try emitOptions(w, args);
        try w.writeByte('\n');
    }
    try w.flush();
}
