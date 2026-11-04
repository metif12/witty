const std = @import("std");
const io = @import("src/io.zig");
const templates = @import("templates.zig");
const c = @cImport({
    @cDefine("WITTY_WRITER_SEEK_DECLARATIONS", "1");
    @cInclude("fixture_shims.h");
});
const a = std.heap.page_allocator;
const W = std.Io.Writer;
var calls: usize = 0;
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
const Pair = struct { value: i64, text: []const u8 };
const Sized = struct { value: i64, text: []const u8, width: usize, precision: ?usize };
const Custom = struct {
    value: i64,
    stop: usize,
    pub fn format(value: @This(), writer: *W) W.Error!void {
        calls += 1;
        if (value.stop == 1) return error.WriteFailed;
        try writer.writeAll("<");
        if (value.stop == 2) return error.WriteFailed;
        try writer.printValue("d", .{}, value.value, 0);
        try writer.writeAll(">");
    }
};
const Customized = struct { value: Custom, text: []const u8, width: usize, precision: ?usize };
fn operate(writer: *W, f: []const []const u8) !void {
    const format = try unhex(f[1]);
    const value = try std.fmt.parseInt(i64, f[8], 10);
    const text = try unhex(f[9]);
    const width = try number(f[10]);
    const precision: ?usize = if (std.mem.eql(u8, f[11], "-")) null else try number(f[11]);
    switch (try number(f[0])) {
        0 => inline for (templates.literal) |fmt| {
            if (std.mem.eql(u8, fmt, format)) return writer.print(fmt, .{});
        },
        1 => inline for (templates.pair) |fmt| {
            if (std.mem.eql(u8, fmt, format)) return writer.print(fmt, Pair{ .value = value, .text = text });
        },
        2 => inline for (templates.sized) |fmt| {
            if (std.mem.eql(u8, fmt, format)) return writer.print(fmt, Sized{ .value = value, .text = text, .width = width, .precision = precision });
        },
        3 => inline for (templates.custom) |fmt| {
            if (std.mem.eql(u8, fmt, format)) return writer.print(fmt, Customized{ .value = .{ .value = value, .stop = try number(f[12]) }, .text = text, .width = width, .precision = precision });
        },
        else => unreachable,
    }
    return error.UnknownTemplate;
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
    try out.print("|{d}|", .{calls});
    try hex(out, contents[0..@intCast(n)]);
    try out.writeByte('~');
}
fn record(out: *W, line: []const u8, path: [:0]const u8) !void {
    var fields: [13][]const u8 = undefined;
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
    calls = 0;
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
