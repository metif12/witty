const std = @import("std");
const L = std.Io.Limit;
const W = std.Io.Writer;
const a = std.heap.page_allocator;
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_status: []const u8 = "";
var observed_scalar: []const u8 = "";
var observed_buffer: []const u8 = &.{};
var observed_payload: []const u8 = &.{};
var observed_vectors: []const []const u8 = &.{};
fn number(text: []const u8) !usize {
    return std.fmt.parseInt(usize, text, 10);
}
fn hex(out: *W, bytes: []const u8) !void {
    for (bytes) |byte| try out.print("{x:0>2}", .{byte});
}
fn state(out: *W) !void {
    try out.print("{s}|", .{observed_scalar});
    try hex(out, observed_buffer);
    try out.writeByte('|');
    try hex(out, observed_payload);
    try out.writeByte('#');
    for (observed_vectors, 0..) |bytes, i| {
        if (i != 0) try out.writeByte(';');
        try out.print("{d},{d}", .{ @intFromPtr(bytes.ptr) - @intFromPtr(observed_payload.ptr), bytes.len });
    }
}
fn observe(message: []const u8, trace: ?usize) noreturn {
    if (observed_path) |path| {
        var out: W.Allocating = .init(a);
        out.writer.print("{s}|", .{observed_status}) catch @trap();
        state(&out.writer) catch @trap();
        std.fs.cwd().writeFile(.{ .sub_path = path, .data = out.written() }) catch @trap();
    }
    std.debug.defaultPanic(message, trace);
}
fn vectors(payload: []const u8, profile: usize) ![]const []const u8 {
    const selected: []const []const u8 = switch (profile) {
        0 => &.{},
        1 => &.{payload[0..0]},
        2 => &.{ payload[0..3], payload[6..6], payload[1..8] },
        3 => &.{ payload[0..255], payload[32..64], payload[255..256] },
        4 => &([_][]const u8{payload[0..1]} ** 33),
        else => unreachable,
    };
    return a.dupe([]const u8, selected);
}
fn optional(value: ?usize) ![]const u8 {
    return if (value) |n| try std.fmt.allocPrint(a, "{d}", .{n}) else "none";
}
fn view(out: *W, bytes: []const u8, buffer: []const u8) !void {
    const offset = if (buffer.len == 0) 0 else @intFromPtr(bytes.ptr) - @intFromPtr(buffer.ptr);
    try out.print("{d}:{d}:", .{ bytes.len, offset });
    try hex(out, bytes);
}
fn snapshot(out: *W, status: []const u8, prefix: []const u8, constant: []const u8, one: []const u8, buffer: []const u8, has_one: bool) !void {
    try out.print("{s}|", .{status});
    try view(out, prefix, buffer);
    try out.writeByte(';');
    try view(out, constant, buffer);
    try out.writeByte(';');
    if (has_one) try view(out, one, buffer) else try out.writeByte('-');
    try out.writeByte('|');
    try state(out);
}
fn record(out: *W, line: []const u8) !void {
    var split = std.mem.splitScalar(u8, line, '|');
    var f: [7][]const u8 = undefined;
    for (&f) |*item| item.* = split.next().?;
    const x = try number(f[0]);
    const y = try number(f[1]);
    const n = try std.fmt.parseInt(u64, f[2], 10);
    const limit: L = .limited(x);
    const buffer = try a.alloc(u8, try number(f[3]));
    for (buffer, 0..) |*byte, i| byte.* = @truncate(i * 17 + 165);
    const payload = try a.alloc(u8, 256);
    for (payload, 0..) |*byte, i| byte.* = @truncate(i * 23 + try number(f[5]));
    const data = try vectors(payload, try number(f[4]));
    const sub = if (limit.subtract(y)) |v| @as(?usize, @intFromEnum(v)) else null;
    observed_scalar = try std.fmt.allocPrint(a, "{d}|{d}|{d}|{d}|{d}|{d}|{d}|{d}|{s}|{s}|{}|{d}|{d}", .{ x, y, n, @intFromEnum(L.limited64(n)), @intFromEnum(limit.min(.limited(y))), limit.minInt(y), limit.minInt64(n), @intFromEnum(L.countVec(data)), try optional(limit.toInt()), try optional(sub), limit.nonzero(), @intFromEnum(L.nothing), @intFromEnum(L.unlimited) });
    observed_buffer = buffer;
    observed_payload = payload;
    observed_vectors = data;
    try out.writeAll("setup|");
    try state(out);
    try out.writeByte('~');
    const prefix = limit.slice(buffer);
    const constant = limit.sliceConst(buffer);
    const has_one = buffer.len > 0 or std.mem.eql(u8, f[6], "1");
    observed_status = "slice1";
    const one = if (has_one) limit.slice1(buffer) else buffer[0..0];
    try snapshot(out, "views", prefix, constant, one, buffer, has_one);
    try out.writeByte('~');
    if (buffer.len > 0) buffer[0] ^= @intCast(try number(f[5]));
    try snapshot(out, "caller", prefix, constant, one, buffer, has_one);
    try out.writeByte('~');
    if (prefix.len > 0) prefix[prefix.len - 1] ^= 0x33;
    if (one.len > 0) one[one.len - 1] ^= 0x55;
    try snapshot(out, "borrow", prefix, constant, one, buffer, has_one);
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    var out: W.Allocating = .init(a);
    if (std.mem.eql(u8, args[1], "--trap")) {
        observed_path = args[2];
        try record(&out.writer, args[3]);
        observed_path = null;
        try out.writer.writeByte('\n');
    } else {
        const input = try std.fs.cwd().readFileAlloc(a, args[1], 10485760);
        var lines = std.mem.tokenizeScalar(u8, input, '\n');
        while (lines.next()) |line| {
            try record(&out.writer, line);
            try out.writer.writeByte('\n');
        }
    }
    try std.fs.File.stdout().writeAll(out.written());
}
