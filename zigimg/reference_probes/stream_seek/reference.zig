const std = @import("std");
const io = @import("src/io.zig");
const c = @cImport({
    @cDefine("WITTY_STREAM_SEEK_DECLARATIONS", "1");
    @cInclude("fixture_shims.h");
});
const allocator = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_reader: ?*io.ReadStream = null;
var observed_buffer: []const u8 = &.{};
var observed_output: []const u8 = &.{};
fn number(text: []const u8) !usize {
    return std.fmt.parseInt(usize, text, 10);
}
fn hex(out: *W, data: []const u8) !void {
    for (data) |byte| try out.print("{x:0>2}", .{byte});
}
fn snapshot(out: *W, reader: *io.ReadStream, buffer: []const u8, output: []const u8) !void {
    try out.print("{d}:{d}:{d}:{d}|", .{ reader.getPos(), try reader.getEndPos(), c.witty_stream_seek_valid(), c.witty_stream_seek_refs() });
    try hex(out, buffer);
    try out.writeByte('|');
    try hex(out, output);
    try out.writeByte('|');
    try hex(out, reader.reader().buffered());
}
fn observe(message: []const u8, first_trace: ?usize) noreturn {
    if (observed_path) |path| {
        var out: W.Allocating = .init(allocator);
        snapshot(&out.writer, observed_reader.?, observed_buffer, observed_output) catch @trap();
        std.fs.cwd().writeFile(.{ .sub_path = path, .data = out.written() }) catch @trap();
        _ = c.witty_stream_seek_cleanup();
    }
    std.debug.defaultPanic(message, first_trace);
}
fn read(out: *W, reader: *io.ReadStream, buffer: []const u8, output: []u8, op: usize) !void {
    var status: []const u8 = "ok";
    if (op == 0) reader.reader().readSliceAll(output) catch |err| {
        status = @errorName(err);
    } else {
        const value = reader.reader().take(output.len) catch |err| blk: {
            status = @errorName(err);
            break :blk &.{};
        };
        if (std.mem.eql(u8, status, "ok")) @memcpy(output, value);
    }
    try out.print("{s}|", .{status});
    try snapshot(out, reader, buffer, output);
    try out.writeByte('~');
}
fn record(out: *W, line: []const u8, path: [:0]const u8) !void {
    var split = std.mem.splitScalar(u8, line, '|');
    var f: [9][]const u8 = undefined;
    for (&f) |*value| value.* = split.next().?;
    const fd = c.witty_stream_seek_setup(path.ptr);
    if (fd < 0) return error.Setup;
    defer {
        if (c.witty_stream_seek_cleanup() != 0) @panic("Seek cleanup failed");
    }
    const buffer = try allocator.alloc(u8, try number(f[1]));
    @memset(buffer, 165);
    const output = try allocator.alloc(u8, try number(f[3]));
    @memset(output, 182);
    var reader = io.ReadStream.initFile(.{ .handle = fd }, buffer);
    observed_reader = &reader;
    observed_buffer = buffer;
    observed_output = output;
    try reader.seekTo(try number(f[2]));
    if (c.witty_stream_seek_replace(0) != 0) return error.Replace;
    if (c.witty_stream_seek_seed(0, try number(f[4])) != 0) return error.Seed;
    if (std.mem.eql(u8, f[5], "1") and c.witty_stream_seek_shutdown() != 0) return error.Shutdown;
    try snapshot(out, &reader, buffer, output);
    try out.writeByte('~');
    for (0..2) |attempt| {
        if (attempt == 1 and std.mem.eql(u8, f[5], "0") and try number(f[6]) > 0) {
            if (c.witty_stream_seek_seed(try number(f[4]), try number(f[6])) != 0) return error.Reseed;
        }
        if (attempt == 0) try read(out, &reader, buffer, output, try number(f[0]));
        if (attempt == 0 and std.mem.eql(u8, f[8], "1") and c.witty_stream_seek_close() != 0) return error.Close;
        var status: []const u8 = "ok";
        reader.seekTo(try number(f[7])) catch |err| {
            status = @errorName(err);
        };
        try out.print("{s}|", .{status});
        try snapshot(out, &reader, buffer, output);
        try out.writeByte('~');
        try read(out, &reader, buffer, output, try number(f[0]));
    }
    var wire: W.Allocating = .init(allocator);
    var drain: isize = -3;
    while (true) {
        var bytes: [4096]u8 = undefined;
        drain = c.witty_stream_seek_drain(&bytes, bytes.len);
        if (drain <= 0) break;
        try wire.writer.writeAll(bytes[0..@intCast(drain)]);
    }
    try out.print("{d}:", .{drain});
    try hex(out, wire.written());
}
pub fn main() !void {
    const args = try std.process.argsAlloc(allocator);
    var out: W.Allocating = .init(allocator);
    if (std.mem.eql(u8, args[1], "--trap")) {
        observed_path = args[2];
        const path = try std.fmt.allocPrintSentinel(allocator, "{s}.owned", .{args[2]}, 0);
        try record(&out.writer, args[3], path);
        observed_path = null;
        try out.writer.writeByte('\n');
    } else {
        const data = try std.fs.cwd().readFileAlloc(allocator, args[1], 10485760);
        var it = std.mem.tokenizeScalar(u8, data, '\n');
        var i: usize = 0;
        while (it.next()) |line| : (i += 1) {
            const path = try std.fmt.allocPrintSentinel(allocator, "{s}.{d}.owned", .{ args[1], i }, 0);
            try record(&out.writer, line, path);
            try out.writer.writeByte('\n');
        }
    }
    var stdout = std.fs.File.stdout().writer(&.{});
    try stdout.interface.writeAll(out.written());
}
