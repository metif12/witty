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
fn record(out: *W, line: []const u8, path: [:0]const u8) !void {
    var split = std.mem.splitScalar(u8, line, '|');
    for (0..11) |_| _ = split.next().?;
    const tag = try number(split.next().?);
    return switch (tag % 10) {
        0 => recordTyped(u8, out, line, path),
        1 => recordTyped(u16, out, line, path),
        2 => recordTyped(u32, out, line, path),
        3 => recordTyped(u64, out, line, path),
        4 => recordTyped(i8, out, line, path),
        5 => recordTyped(i16, out, line, path),
        6 => recordTyped(i32, out, line, path),
        7 => recordTyped(i64, out, line, path),
        8 => recordTyped(usize, out, line, path),
        9 => recordTyped(isize, out, line, path),
        else => unreachable,
    };
}
fn recordTyped(comptime T: type, out: *W, line: []const u8, path: [:0]const u8) !void {
    var split = std.mem.splitScalar(u8, line, '|');
    var f: [15][]const u8 = undefined;
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
    const n = try number(f[13]);
    const offset = try number(f[14]);
    const allocation = try a.alloc(T, n + 2);
    const output = std.mem.sliceAsBytes(allocation);
    for (output, 0..) |*byte, i| byte.* = @truncate(195 + i * 11);
    const destination = allocation[offset..][0..n];
    observed_reader = &reader;
    observed_buffer = buffer;
    observed_output = output;
    observed_file = kind > 0;
    observed_status = "ok";
    var status: []const u8 = "ok";
    if (start > 0) reader.seekTo(start) catch |err| {
        status = @errorName(err);
    };
    if (replacement > 0 and api == 1) {
        _ = try reader.reader().peek(capacity);
        reader.reader().toss(consumed);
    }
    try out.print("{s}|", .{status});
    try snapshot(out, &reader, buffer, output);
    try out.writeByte('~');
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
        status = "ok";
        reader.reader().readSliceEndian(T, destination, if (try number(f[12]) % 2 == 0) .big else .little) catch |err| {
            status = @errorName(err);
        };
        observed_status = status;
        observed_output = output;
        try out.print("{s}|", .{status});
        try snapshot(out, &reader, buffer, output);
        try out.writeByte('~');
        const available = reader.reader().bufferedLen();
        const consume = switch (count) {
            1 => available,
            2 => @min(1, available),
            3 => (available + 1) / 2,
            else => 0,
        };
        reader.reader().toss(consume);
        try out.print("consumed-{d}|", .{consume});
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
            if (api == 2 and replacement == 1 and c.witty_reader_delimiter_seed(0, consumed) != 0) return error.ReaderReseed;
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
        try record(&out.writer, args[3], path);
        observed_path = null;
        try out.writer.writeByte('\n');
    } else {
        const path = args[1];
        const data = try std.fs.cwd().readFileAlloc(a, path, 10485760);
        var it = std.mem.tokenizeScalar(u8, data, '\n');
        var i: usize = 0;
        while (it.next()) |line| : (i += 1) {
            const owned = try std.fmt.allocPrintSentinel(a, "{s}.{d}.owned", .{ path, i }, 0);
            try record(&out.writer, line, owned);
            try out.writer.writeByte('\n');
        }
    }
    var stdout = std.fs.File.stdout().writer(&.{});
    try stdout.interface.writeAll(out.written());
}
