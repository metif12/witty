const std = @import("std");
const io = @import("src/io.zig");
const c = @cImport({
    @cDefine("WITTY_WRITER_SEEK_DECLARATIONS", "1");
    @cInclude("fixture_shims.h");
});
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_writer: ?*io.WriteStream = null;
var observed_buffer: []const u8 = &.{};
fn number(text: []const u8) !usize {
    return std.fmt.parseInt(usize, text, 10);
}
fn hex(out: *W, data: []const u8) !void {
    for (data) |byte| try out.print("{x:0>2}", .{byte});
}
fn snapshot(out: *W, writer: *io.WriteStream, buffer: []const u8) !void {
    var contents: [4096]u8 = undefined;
    const n = c.witty_writer_seek_view(&contents, contents.len);
    if (n < 0) return error.Observer;
    try out.print("{d}:{d}:{d}|", .{ writer.getPos(), c.witty_writer_seek_valid(), c.witty_writer_seek_refs() });
    try hex(out, buffer);
    try out.writeByte('|');
    try hex(out, writer.writer().buffered());
    try out.writeByte('|');
    try hex(out, contents[0..@intCast(n)]);
}
fn observe(message: []const u8, first_trace: ?usize) noreturn {
    if (observed_path) |path| {
        var out: W.Allocating = .init(a);
        snapshot(&out.writer, observed_writer.?, observed_buffer) catch @trap();
        std.fs.cwd().writeFile(.{ .sub_path = path, .data = out.written() }) catch @trap();
        _ = c.witty_writer_seek_cleanup();
    }
    std.debug.defaultPanic(message, first_trace);
}
fn write(out: *W, writer: *io.WriteStream, bytes: []const u8, api: usize) !void {
    if (api == 1) {
        writer.writer().writeAll(bytes) catch |err| {
            try out.writeAll(@errorName(err));
            return;
        };
        try out.writeAll("ok");
    } else {
        const n = writer.writer().write(bytes) catch |err| {
            try out.writeAll(@errorName(err));
            return;
        };
        try out.print("{d}", .{n});
    }
}
fn restore(path: [:0]const u8) !void {
    const restored = try std.fmt.allocPrintSentinel(a, "{s}.restored", .{path}, 0);
    if (c.witty_writer_seek_restore(restored, 32) != 0) return error.Restore;
}
fn record(out: *W, line: []const u8, path: [:0]const u8) !void {
    var split = std.mem.splitScalar(u8, line, '|');
    var f: [9][]const u8 = undefined;
    for (&f) |*value| value.* = split.next().?;
    const fd = c.witty_writer_seek_setup(path.ptr);
    if (fd < 0) return error.Setup;
    defer {
        if (c.witty_writer_seek_cleanup() != 0) @panic("Writer cleanup failed");
    }
    const buffer = try a.alloc(u8, try number(f[2]));
    @memset(buffer, 165);
    var writer: io.WriteStream = if (std.mem.eql(u8, f[1], "1")) .{ .file = std.fs.File.Writer.initStreaming(.{ .handle = fd }, buffer) } else io.WriteStream.initFile(.{ .handle = fd }, buffer);
    observed_writer = &writer;
    observed_buffer = buffer;
    try writer.seekTo(try number(f[3]));
    if (c.witty_writer_seek_replace(1) != 0) return error.Replace;
    try snapshot(out, &writer, buffer);
    try out.writeByte('~');
    const bytes = try a.alloc(u8, try number(f[4]));
    for (bytes, 0..) |*byte, i| byte.* = @truncate(i * 31 + 7);
    try write(out, &writer, bytes, try number(f[0]));
    try out.writeByte('|');
    try snapshot(out, &writer, buffer);
    try out.writeByte('~');
    if (std.mem.eql(u8, f[8], "1")) {
        if (c.witty_writer_seek_close() != 0) return error.Close;
    } else if (std.mem.eql(u8, f[7], "1")) try restore(path);
    try out.writeAll("rebound|");
    try snapshot(out, &writer, buffer);
    try out.writeByte('~');
    var status: []const u8 = "ok";
    writer.seekTo(try number(f[5])) catch |err| {
        status = @errorName(err);
    };
    try out.print("{s}|", .{status});
    try snapshot(out, &writer, buffer);
    try out.writeByte('~');
    if (std.mem.eql(u8, f[8], "2")) {
        if (c.witty_writer_seek_close() != 0) return error.Close;
    } else if (std.mem.eql(u8, f[7], "2")) try restore(path);
    try out.writeAll("rebound|");
    try snapshot(out, &writer, buffer);
    try out.writeByte('~');
    try write(out, &writer, &.{ 209, 210, 211 }, try number(f[0]));
    try out.writeByte('|');
    try snapshot(out, &writer, buffer);
    try out.writeByte('~');
    status = "ok";
    writer.seekTo(try number(f[6])) catch |err| {
        status = @errorName(err);
    };
    try out.print("{s}|", .{status});
    try snapshot(out, &writer, buffer);
    try out.writeByte('~');
    status = "ok";
    writer.flush() catch |err| {
        status = @errorName(err);
    };
    try out.print("{s}|", .{status});
    try snapshot(out, &writer, buffer);
    try out.writeByte('~');
    var wire: W.Allocating = .init(a);
    var drain: isize = -3;
    while (true) {
        var bytes_out: [4096]u8 = undefined;
        drain = c.witty_writer_seek_drain(&bytes_out, bytes_out.len);
        if (drain <= 0) break;
        try wire.writer.writeAll(bytes_out[0..@intCast(drain)]);
    }
    try out.print("{d}:", .{drain});
    try hex(out, wire.written());
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    var out: W.Allocating = .init(a);
    if (std.mem.eql(u8, args[1], "--trap")) {
        observed_path = args[2];
        const path = try std.fmt.allocPrintSentinel(a, "{s}.owned", .{args[2]}, 0);
        try record(&out.writer, args[3], path);
        observed_path = null;
        try out.writer.writeByte('\n');
    } else {
        const data = try std.fs.cwd().readFileAlloc(a, args[1], 10485760);
        var it = std.mem.tokenizeScalar(u8, data, '\n');
        var i: usize = 0;
        while (it.next()) |line| : (i += 1) {
            const path = try std.fmt.allocPrintSentinel(a, "{s}.{d}.owned", .{ args[1], i }, 0);
            try record(&out.writer, line, path);
            try out.writer.writeByte('\n');
        }
    }
    var stdout = std.fs.File.stdout().writer(&.{});
    try stdout.interface.writeAll(out.written());
}
