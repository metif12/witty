const std = @import("std");
const io = @import("src/io.zig");
const c = @cImport({
    @cDefine("WITTY_READER_DELIMITER_DECLARATIONS", "1");
    @cInclude("fixture_shims.h");
});
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_status: []const u8 = "";
var observed_reader: ?*io.ReadStream = null;
var observed_buffer: []const u8 = &.{};
var observed_output: []const u8 = &.{};
var observed_file = false;
fn number(text: []const u8) !usize {
    return std.fmt.parseInt(usize, text, 10);
}
fn hex(out: *W, data: []const u8) !void {
    for (data) |byte| try out.print("{x:0>2}", .{byte});
}
fn state(out: *W, reader: *io.ReadStream, buffer: []const u8, output: []const u8) !void {
    if (reader.getEndPos()) |size| try out.print("{d}", .{size}) else |err| try out.print("{s}", .{@errorName(err)});
    try out.print(":{d}:{d}|", .{ if (observed_file) c.witty_reader_delimiter_valid() else 0, if (observed_file) c.witty_reader_delimiter_refs() else 0 });
    try hex(out, buffer);
    try out.writeByte('|');
    try hex(out, output);
    try out.writeByte('|');
    try hex(out, reader.reader().buffered());
}
fn snapshot(out: *W, reader: *io.ReadStream, buffer: []const u8, output: []const u8) !void {
    try out.print("{d}:", .{reader.getPos()});
    try state(out, reader, buffer, output);
}
fn observe(message: []const u8, first_trace: ?usize) noreturn {
    if (observed_path) |path| {
        var out: W.Allocating = .init(a);
        out.writer.print("{s}|", .{observed_status}) catch @trap();
        state(&out.writer, observed_reader.?, observed_buffer, observed_output) catch @trap();
        std.fs.cwd().writeFile(.{ .sub_path = path, .data = out.written() }) catch @trap();
        _ = c.witty_reader_delimiter_cleanup();
    }
    std.debug.defaultPanic(message, first_trace);
}
fn arrayView(reader: *io.ReadStream, api: usize, tag: usize) ![]u8 {
    const r = reader.reader();
    return switch (tag) {
        0 => if (api == 0) (try r.peekArray(1))[0..] else (try r.takeArray(1))[0..],
        1 => if (api == 0) (try r.peekArray(2))[0..] else (try r.takeArray(2))[0..],
        2 => if (api == 0) (try r.peekArray(4))[0..] else (try r.takeArray(4))[0..],
        3 => if (api == 0) (try r.peekArray(8))[0..] else (try r.takeArray(8))[0..],
        4 => if (api == 0) (try r.peekArray(16))[0..] else (try r.takeArray(16))[0..],
        5 => if (api == 0) (try r.peekArray(32))[0..] else (try r.takeArray(32))[0..],
        6 => if (api == 0) (try r.peekArray(1))[0..] else (try r.takeArray(1))[0..],
        7 => if (api == 0) (try r.peekArray(2))[0..] else (try r.takeArray(2))[0..],
        8 => if (api == 0) (try r.peekArray(4))[0..] else (try r.takeArray(4))[0..],
        9 => if (api == 0) (try r.peekArray(8))[0..] else (try r.takeArray(8))[0..],
        10 => if (api == 0) (try r.peekArray(16))[0..] else (try r.takeArray(16))[0..],
        11 => if (api == 0) (try r.peekArray(32))[0..] else (try r.takeArray(32))[0..],
        12 => if (api == 0) (try r.peekArray(2))[0..] else (try r.takeArray(2))[0..],
        else => unreachable,
    };
}
fn operate(reader: *io.ReadStream, output: *[]const u8, api: usize, tag: usize) ![]const u8 {
    const value = arrayView(reader, api, tag) catch |err| return @errorName(err);
    output.* = try a.dupe(u8, value);
    return "ok";
}
fn record(out: *W, line: []const u8, path: [:0]const u8, borrow: bool) !void {
    var split = std.mem.splitScalar(u8, line, '|');
    var f: [11][]const u8 = undefined;
    for (&f) |*value| value.* = split.next().?;
    const kind = try number(f[0]);
    const api = try number(f[1]);
    const capacity = try number(f[2]);
    const start = try number(f[3]);
    const count = try number(f[4]);
    const data = try a.alloc(u8, f[5].len / 2);
    _ = try std.fmt.hexToBytes(data, f[5]);
    const replacement = try number(f[6]);
    const consumed = try number(f[7]);
    const seed = try number(f[8]);
    const prime = try number(f[9]);
    const delta = try std.fmt.parseInt(i64, f[10], 10);
    var buffer = try a.alloc(u8, capacity);
    @memset(buffer, 165);
    var reader = io.ReadStream.initMemory(data);
    if (kind == 0) buffer = data else {
        const fd = c.witty_reader_exclusive_payload(path.ptr, data.ptr, data.len);
        if (fd < 0) return error.ReaderSetup;
        reader = if (kind == 1) io.ReadStream.initFile(.{ .handle = fd }, buffer) else .{ .file = std.fs.File.Reader.initStreaming(.{ .handle = fd }, buffer) };
    }
    defer {
        if (kind > 0 and c.witty_reader_delimiter_cleanup() != 0) @panic("Reader cleanup failed");
    }
    var output: []const u8 = &.{};
    observed_reader = &reader;
    observed_buffer = buffer;
    observed_output = output;
    observed_file = kind > 0;
    observed_status = "ok";
    var status: []const u8 = "ok";
    if (start > 0) reader.seekTo(start) catch |err| {
        status = @errorName(err);
    };
    if (replacement > 0) {
        _ = try reader.reader().peek(capacity);
        reader.reader().toss(consumed);
    }
    try out.print("{s}|", .{status});
    try snapshot(out, &reader, buffer, output);
    try out.writeByte('~');
    if (borrow) {
        const alias = try arrayView(&reader, api, count);
        const offset = @intFromPtr(alias.ptr) - @intFromPtr(buffer.ptr);
        if (offset + alias.len > buffer.len) @panic("Array pointer escaped backing storage");
        output = try a.dupe(u8, alias);
        try out.writeAll("borrow|");
        try snapshot(out, &reader, buffer, output);
        try out.writeByte('|');
        try hex(out, alias);
        try out.print("|{d}", .{offset});
        try out.writeByte('~');
        for (buffer) |*byte| byte.* ^= 128;
        try out.writeAll("caller|");
        try snapshot(out, &reader, buffer, output);
        try out.writeByte('|');
        try hex(out, alias);
        try out.print("|{d}", .{offset});
        try out.writeByte('~');
        if (alias.len > 0) alias[0] ^= 64;
        try out.writeAll("alias|");
        try snapshot(out, &reader, buffer, output);
        try out.writeByte('|');
        try hex(out, alias);
        try out.print("|{d}", .{offset});
        try out.writeByte('~');
        reader.reader().tossBuffered();
        try out.writeAll("toss|");
        try snapshot(out, &reader, buffer, output);
        try out.writeByte('|');
        try hex(out, alias);
        try out.print("|{d}", .{offset});
        return;
    }
    if (replacement > 0) {
        if (c.witty_reader_delimiter_replace(0) != 0 or c.witty_reader_delimiter_seed(0, seed) != 0) return error.ReaderReplace;
        if (replacement == 2 and c.witty_reader_delimiter_shutdown() != 0) return error.ReaderShutdown;
    }
    status = "skip";
    if (prime > 0) {
        status = "ok";
        _ = reader.reader().peek(capacity) catch |err| blk: {
            status = @errorName(err);
            break :blk &.{};
        };
        if (prime == 2) reader.reader().tossBuffered();
    }
    try out.print("{s}|", .{status});
    try snapshot(out, &reader, buffer, output);
    try out.writeByte('~');
    for (0..3) |attempt| {
        observed_status = "calling";
        status = try operate(&reader, &output, api, count);
        observed_status = status;
        observed_output = output;
        try out.print("{s}|", .{status});
        try snapshot(out, &reader, buffer, output);
        try out.writeByte('~');
        if (attempt == 0) {
            status = "ok";
            reader.seekBy(delta) catch |err| {
                status = @errorName(err);
            };
            try out.print("{s}|", .{status});
            try snapshot(out, &reader, buffer, output);
            try out.writeByte('~');
        }
    }
    var wire: W.Allocating = .init(a);
    var drain: isize = -3;
    if (replacement > 0) {
        while (true) {
            var bytes: [4096]u8 = undefined;
            drain = c.witty_reader_delimiter_drain(&bytes, bytes.len);
            if (drain <= 0) break;
            try wire.writer.writeAll(bytes[0..@intCast(drain)]);
        }
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
        try record(&out.writer, args[3], path, false);
        observed_path = null;
        try out.writer.writeByte('\n');
    } else {
        const borrow = std.mem.eql(u8, args[1], "--borrow");
        const path = args[if (borrow) @as(usize, 2) else 1];
        const data = try std.fs.cwd().readFileAlloc(a, path, 10485760);
        var it = std.mem.tokenizeScalar(u8, data, '\n');
        var i: usize = 0;
        while (it.next()) |line| : (i += 1) {
            const owned = try std.fmt.allocPrintSentinel(a, "{s}.{d}.owned", .{ path, i }, 0);
            try record(&out.writer, line, owned, borrow);
            try out.writer.writeByte('\n');
        }
    }
    var stdout = std.fs.File.stdout().writer(&.{});
    try stdout.interface.writeAll(out.written());
}
