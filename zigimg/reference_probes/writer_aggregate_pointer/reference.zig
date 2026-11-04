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
const Record = struct { value: i64, flag: bool };
const Choice = enum(u8) { zero = 0, high = 255 };
const Sum = union(enum) { Record: Record, bool: bool };
const Outer = union(enum) { Sum: Sum, u64: u64 };
const Empty = struct {};
const Node = struct { value: i64, next: ?*const Node = null };
fn recordSeen(value: Record) ![]const u8 {
    return std.fmt.allocPrint(a, "{d}:{d}", .{ @as(u64, @bitCast(value.value)), @intFromBool(value.flag) });
}
fn sumSeen(value: Sum) ![]const u8 {
    return switch (value) {
        .Record => |v| std.fmt.allocPrint(a, "R{s}", .{try recordSeen(v)}),
        .bool => |v| std.fmt.allocPrint(a, "B{d}", .{@intFromBool(v)}),
    };
}
fn outerSeen(value: Outer) ![]const u8 {
    return switch (value) {
        .Sum => |v| std.fmt.allocPrint(a, "S{s}", .{try sumSeen(v)}),
        .u64 => |v| std.fmt.allocPrint(a, "U{d}", .{v}),
    };
}
fn capture(value: anytype) ![]const u8 {
    const T = @TypeOf(value);
    if (T == Record) return recordSeen(value);
    if (T == Choice) return std.fmt.allocPrint(a, "{d}", .{@intFromEnum(value)});
    if (T == Sum) return sumSeen(value);
    if (T == Outer) return outerSeen(value);
    if (T == Empty) return "empty";
    if (T == Node) return std.fmt.allocPrint(a, "N{d}:{d}", .{ @as(u64, @bitCast(value.value)), @intFromBool(value.next != null) });
    @compileError("invalid capture");
}
fn typed(writer: *W, comptime fmt: []const u8, value: anytype, comptime op: usize, options: std.fmt.Options, depth: usize) !void {
    seen = try capture(value);
    defer {
        seen = capture(value) catch @panic("capture failed");
    }
    const T = @TypeOf(value);
    switch (op) {
        0, 1, 2 => try writer.printValue(fmt, options, &value, depth),
        3, 5 => try writer.printValue(fmt, options, @as(?*const T, &value), depth),
        4, 6 => try writer.printValue(fmt, options, @as(?*const T, null), depth),
        else => unreachable,
    }
}
fn operate(writer: *W, f: []const []const u8) !void {
    const format = try unhex(f[1]);
    const tag = try number(f[0]);
    const raw = try number(f[8]);
    const op = try number(f[12]);
    const depth = try number(f[13]);
    const options: std.fmt.Options = .{ .width = if (std.mem.eql(u8, f[10], "-")) null else try number(f[10]), .precision = if (std.mem.eql(u8, f[11], "-")) null else try number(f[11]), .alignment = @enumFromInt(try number(f[14])), .fill = @intCast(try number(f[15])) };
    const record_value: Record = .{ .value = @bitCast(raw), .flag = raw & 1 != 0 };
    const choice: Choice = if (raw & 1 != 0) .high else .zero;
    const sum: Sum = if (raw & 2 != 0) .{ .bool = raw & 4 != 0 } else .{ .Record = record_value };
    const outer: Outer = if (raw & 1 != 0) .{ .u64 = raw } else .{ .Sum = sum };
    var node: Node = .{ .value = @bitCast(raw) };
    if (raw & 1 != 0) node.next = &node;
    switch (op) {
        inline 0...6 => |form| {
            const formats = if (form >= 3) .{ "any", "?", "?any" } else .{ "", "any" };
            inline for (formats) |fmt| {
                if (std.mem.eql(u8, fmt, format)) return switch (tag) {
                    0 => typed(writer, fmt, record_value, form, options, depth),
                    1 => typed(writer, fmt, choice, form, options, depth),
                    2 => typed(writer, fmt, sum, form, options, depth),
                    3 => typed(writer, fmt, outer, form, options, depth),
                    4 => typed(writer, fmt, Empty{}, form, options, depth),
                    5 => typed(writer, fmt, node, form, options, depth),
                    else => unreachable,
                };
            }
        },
        else => unreachable,
    }
    return error.UnknownFormat;
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
