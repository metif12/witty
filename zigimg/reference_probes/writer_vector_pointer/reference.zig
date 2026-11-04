const std = @import("std");
const io = @import("src/io.zig");
const c = @cImport({
    @cDefine("WITTY_WRITER_SEEK_DECLARATIONS", "1");
    @cInclude("fixture_shims.h");
});
const a = std.heap.page_allocator;
const W = std.Io.Writer;
var seen: []const u8 = "-";
fn number(text: []const u8) !usize {
    return std.fmt.parseInt(usize, text, 10);
}
fn hex(out: *W, data: []const u8) !void {
    for (data) |byte| try out.print("{x:0>2}", .{byte});
}
fn unhex(text: []const u8) ![]u8 {
    const b = try a.alloc(u8, text.len / 2);
    return std.fmt.hexToBytes(b, text);
}
fn typed(comptime T: type, comptime optional: bool, comptime length: usize, writer: *W, comptime fmt: []const u8, raw: usize, options: std.fmt.Options, depth: usize) !void {
    const P = if (optional) ?*T else *allowzero align(1) T;
    var lanes: [length]P = undefined;
    inline for (0..length) |i| {
        const bits = raw +% @as(usize, i) *% 0x9e3779b97f4a7c15;
        lanes[i] = if (optional) (if (i % 3 == 1) null else @ptrFromInt((bits & ~@as(usize, 7)) | 8)) else @ptrFromInt(bits);
    }
    var out: W.Allocating = .init(a);
    for (lanes, 0..) |lane, i| {
        if (i != 0) try out.writer.writeByte(',');
        try out.writer.print("{d}", .{@intFromPtr(lane)});
    }
    seen = out.written();
    const vector: @Vector(length, P) = lanes;
    try writer.printVector(fmt, options, vector, depth);
}
fn operate(writer: *W, f: []const []const u8) !void {
    const format = try unhex(f[1]);
    const raw = try number(f[8]);
    const tag = try number(f[0]);
    const length = try number(f[12]);
    const depth = try number(f[13]);
    const options: std.fmt.Options = .{ .width = if (std.mem.eql(u8, f[10], "-")) null else try number(f[10]), .precision = if (std.mem.eql(u8, f[11], "-")) null else try number(f[11]), .alignment = @enumFromInt(try number(f[14])), .fill = @intCast(try number(f[15])) };
    inline for (.{ u8, u16, u32, u64, usize, i8, i16, i32, i64, isize, f32, f64, bool, anyopaque, i32, bool, u8, f64, bool }, 0..) |T, index| {
        if (tag == index) switch (length) {
            inline 1, 3, 8 => |n| {
                const optional = index >= 16;
                const formats = if (optional) .{ "any", "?", "?any", "*", "?*" } else .{ "", "any", "*" };
                inline for (formats) |fmt| {
                    if (std.mem.eql(u8, format, fmt)) return typed(T, optional, n, writer, fmt, raw, options, depth);
                }
                return error.UnknownFormat;
            },
            else => unreachable,
        };
    }
    return error.UnknownType;
}
fn snapshot(out: *W, status: []const u8, writer: *io.WriteStream, buffer: []const u8, file: bool) !void {
    var contents: [4096]u8 = undefined;
    const n = if (file) c.witty_writer_seek_view(&contents, contents.len) else 0;
    if (n < 0) return error.Observer;
    const w = writer.writer();
    const unused = w.unusedCapacitySlice();
    const offset = if (buffer.len == 0) 0 else @intFromPtr(unused.ptr) - @intFromPtr(buffer.ptr);
    try out.print("{s}|{d}:{d}:{d}:{d}:{d}|", .{ status, writer.getPos(), w.unusedCapacityLen(), w.buffered().len, offset, if (file) c.witty_writer_seek_valid() else 0 });
    try hex(out, buffer);
    try out.writeByte('|');
    try hex(out, w.buffered());
    try out.writeByte('|');
    try hex(out, unused);
    try out.print("|{s}|", .{seen});
    try hex(out, contents[0..@intCast(n)]);
    try out.writeByte('~');
}
fn record(out: *W, line: []const u8, path: [:0]const u8) !void {
    var fields: [16][]const u8 = undefined;
    var split = std.mem.splitScalar(u8, line, '|');
    for (&fields) |*f| f.* = split.next().?;
    const kind = try number(fields[2]);
    const cap = try number(fields[3]);
    const start = try number(fields[4]);
    const binding = try number(fields[6]);
    const buffer = try a.alloc(u8, cap);
    for (buffer, 0..) |*b, i| b.* = @truncate(i * 17 + 165);
    var writer = io.WriteStream.initMemory(buffer);
    if (kind > 0) {
        const fd = c.witty_writer_seek_setup(path.ptr);
        const restored = try std.fmt.allocPrintSentinel(a, "{s}.restored", .{path}, 0);
        if (fd < 0 or c.witty_writer_seek_restore(restored, 32) != 0) return error.Setup;
        writer = if (kind == 1) io.WriteStream.initFile(.{ .handle = fd }, buffer) else .{ .file = std.fs.File.Writer.initStreaming(.{ .handle = fd }, buffer) };
    }
    defer {
        if (kind > 0 and c.witty_writer_seek_cleanup() != 0) @panic("cleanup failed");
    }
    writer.seekTo(start) catch {};
    const prefix = try a.alloc(u8, try number(fields[5]));
    for (prefix, 0..) |*b, i| b.* = @truncate(i * 31 + 7);
    try writer.writer().writeAll(prefix);
    if (kind > 0) {
        if (binding == 1 and c.witty_writer_seek_replace(1) != 0) return error.Replace;
        if (binding == 2 and c.witty_writer_seek_close() != 0) return error.Close;
    }
    seen = "-";
    try snapshot(out, "ready", &writer, buffer, kind > 0);
    const status = blk: {
        operate(writer.writer(), &fields) catch |err| break :blk @errorName(err);
        break :blk "ok";
    };
    try snapshot(out, status, &writer, buffer, kind > 0);
    if (cap > 0) buffer[0] ^= 0x5a;
    try snapshot(out, "caller", &writer, buffer, kind > 0);
    var finish: []const u8 = "skip";
    if (std.mem.eql(u8, fields[7], "1")) {
        finish = "ok";
        writer.flush() catch |err| {
            finish = @errorName(err);
        };
    }
    try snapshot(out, finish, &writer, buffer, kind > 0);
    var drain: isize = -3;
    var wire: std.array_list.Managed(u8) = .init(a);
    if (kind > 0 and binding == 1) {
        while (true) {
            var bytes: [4096]u8 = undefined;
            drain = c.witty_writer_seek_drain(&bytes, bytes.len);
            if (drain <= 0) break;
            try wire.appendSlice(bytes[0..@intCast(drain)]);
        }
    }
    try out.print("{d}:", .{drain});
    try hex(out, wire.items);
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    const data = try std.fs.cwd().readFileAlloc(a, args[1], 10485760);
    var out: W.Allocating = .init(a);
    var it = std.mem.tokenizeScalar(u8, data, '\n');
    var i: usize = 0;
    while (it.next()) |line| : (i += 1) {
        const path = try std.fmt.allocPrintSentinel(a, "{s}.{d}.owned", .{ args[1], i }, 0);
        try record(&out.writer, line, path);
        try out.writer.writeByte('\n');
    }
    var stdout = std.fs.File.stdout().writer(&.{});
    try stdout.interface.writeAll(out.written());
}
