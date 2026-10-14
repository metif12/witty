const std = @import("std");
const io = @import("src/io.zig");
const c = @cImport({
    @cDefine("WITTY_STREAM_TRANSITION_DECLARATIONS", "1");
    @cInclude("fixture_shims.h");
});
const allocator = std.heap.page_allocator;
const W = std.Io.Writer;
fn number(text: []const u8) !usize {
    return std.fmt.parseInt(usize, text, 10);
}
fn hex(out: *W, data: []const u8) !void {
    for (data) |byte| try out.print("{x:0>2}", .{byte});
}
fn snapshot(out: *W, reader: *io.ReadStream, writer: *io.WriteStream, buffer: []const u8, output: []const u8, writing: bool) !void {
    try out.print("{d}:", .{if (writing) writer.getPos() else reader.getPos()});
    if (writing) try out.writeByte('-') else try out.print("{d}", .{try reader.getEndPos()});
    try out.print(":{d}:{d}|", .{ c.witty_stream_transition_valid(), c.witty_stream_transition_refs() });
    try hex(out, buffer);
    try out.writeByte('|');
    try hex(out, output);
    try out.writeByte('|');
    try hex(out, if (writing) writer.writer().buffered() else reader.reader().buffered());
}
fn record(out: *W, line: []const u8, path: [:0]const u8) !void {
    var split = std.mem.splitScalar(u8, line, '|');
    var f: [8][]const u8 = undefined;
    for (&f) |*value| value.* = split.next().?;
    const op = try number(f[0]);
    const writing = op >= 2;
    const fd = c.witty_stream_transition_setup(path.ptr);
    if (fd < 0) return error.Setup;
    defer {
        if (c.witty_stream_transition_cleanup() != 0) @panic("Transition cleanup failed");
    }
    const file: std.fs.File = .{ .handle = fd };
    const buffer = try allocator.alloc(u8, try number(f[1]));
    @memset(buffer, 165);
    const output = try allocator.alloc(u8, try number(f[3]));
    @memset(output, 182);
    var reader = io.ReadStream.initFile(file, buffer);
    var writer = io.WriteStream.initFile(file, buffer);
    if (writing) try writer.seekTo(try number(f[2])) else try reader.seekTo(try number(f[2]));
    if (c.witty_stream_transition_replace(@intFromBool(writing)) != 0) return error.Replace;
    if (!writing and c.witty_stream_transition_seed(0, try number(f[4])) != 0) return error.Seed;
    if (std.mem.eql(u8, f[5], "1") and c.witty_stream_transition_shutdown() != 0) return error.Shutdown;
    try snapshot(out, &reader, &writer, buffer, output, writing);
    try out.writeByte('~');
    const payload = try allocator.alloc(u8, output.len);
    for (payload, 0..) |*byte, i| byte.* = @truncate(i * 17 + 11);
    for (0..2) |attempt| {
        if (attempt == 1 and !writing and std.mem.eql(u8, f[5], "0") and try number(f[6]) > 0) {
            if (c.witty_stream_transition_seed(try number(f[4]), try number(f[6])) != 0) return error.Reseed;
        }
        var status: []const u8 = "ok";
        var result: []const u8 = "-";
        if (op == 0) {
            reader.reader().readSliceAll(output) catch |err| {
                status = @errorName(err);
            };
        } else if (op == 1) {
            const value = reader.reader().take(output.len) catch |err| blk: {
                status = @errorName(err);
                break :blk &.{};
            };
            if (std.mem.eql(u8, status, "ok")) @memcpy(output, value);
        } else if (op == 2) {
            const n = writer.writer().write(payload) catch |err| blk: {
                status = @errorName(err);
                break :blk @as(usize, 0);
            };
            if (std.mem.eql(u8, status, "ok")) result = try std.fmt.allocPrint(allocator, "{d}", .{n});
        } else {
            writer.writer().writeAll(payload) catch |err| {
                status = @errorName(err);
            };
        }
        if (writing and std.mem.eql(u8, f[7], "1")) writer.flush() catch |err| {
            status = try std.fmt.allocPrint(allocator, "{s}:flush-{s}", .{ status, @errorName(err) });
        };
        try out.print("{s}:{s}|", .{ status, result });
        try snapshot(out, &reader, &writer, buffer, output, writing);
        try out.writeByte('~');
    }
    var wire: W.Allocating = .init(allocator);
    var drain: isize = -3;
    while (true) {
        var bytes: [4096]u8 = undefined;
        drain = c.witty_stream_transition_drain(&bytes, bytes.len);
        if (drain <= 0) break;
        try wire.writer.writeAll(bytes[0..@intCast(drain)]);
    }
    try out.print("{d}:", .{drain});
    try hex(out, wire.written());
}
pub fn main() !void {
    const args = try std.process.argsAlloc(allocator);
    const data = try std.fs.cwd().readFileAlloc(allocator, args[1], 10485760);
    var out: W.Allocating = .init(allocator);
    var it = std.mem.tokenizeScalar(u8, data, '\n');
    var i: usize = 0;
    while (it.next()) |line| : (i += 1) {
        const path = try std.fmt.allocPrintSentinel(allocator, "{s}.{d}.owned", .{ args[1], i }, 0);
        try record(&out.writer, line, path);
        try out.writer.writeByte('\n');
    }
    var stdout = std.fs.File.stdout().writer(&.{});
    try stdout.interface.writeAll(out.written());
}
