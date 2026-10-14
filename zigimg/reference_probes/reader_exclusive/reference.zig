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
fn number(text: []const u8) !usize {
    return std.fmt.parseInt(usize, text, 10);
}
fn hex(out: *W, data: []const u8) !void {
    for (data) |byte| try out.print("{x:0>2}", .{byte});
}
fn state(out: *W, reader: *io.ReadStream, buffer: []const u8, output: []const u8) !void {
    try out.print("{d}:{d}:{d}|", .{ try reader.getEndPos(), c.witty_reader_delimiter_valid(), c.witty_reader_delimiter_refs() });
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
fn read(reader: *io.ReadStream, output: *[]const u8, api: usize, delimiter: u8) ![]const u8 {
    const value = if (api == 0) reader.reader().peekDelimiterExclusive(delimiter) catch |err| return @errorName(err) else reader.reader().takeDelimiterExclusive(delimiter) catch |err| return @errorName(err);
    output.* = try a.dupe(u8, value);
    return "ok";
}

fn record(out: *W, line: []const u8, path: [:0]const u8) !void {
    var split = std.mem.splitScalar(u8, line, '|');
    var f: [11][]const u8 = undefined;
    for (&f) |*value| value.* = split.next().?;
    const fd = c.witty_reader_delimiter_setup(path.ptr);
    if (fd < 0) return error.Setup;
    defer {
        if (c.witty_reader_delimiter_cleanup() != 0) @panic("Delimiter cleanup failed");
    }
    const buffer = try a.alloc(u8, try number(f[1]));
    @memset(buffer, 165);
    var output: []const u8 = &.{};
    var reader = io.ReadStream.initFile(.{ .handle = fd }, buffer);
    observed_reader = &reader;
    observed_buffer = buffer;
    observed_output = output;
    try reader.seekTo(try number(f[2]));
    _ = try reader.reader().peek(buffer.len);
    reader.reader().toss(try number(f[3]));
    try snapshot(out, &reader, buffer, output);
    try out.writeByte('~');
    if (c.witty_reader_delimiter_replace(0) != 0) return error.Replace;
    if (c.witty_reader_delimiter_seed(0, try number(f[5])) != 0) return error.Seed;
    if (std.mem.eql(u8, f[6], "1") and c.witty_reader_delimiter_shutdown() != 0) return error.Shutdown;
    try out.writeAll("rebound|");
    try snapshot(out, &reader, buffer, output);
    try out.writeByte('~');
    if (std.mem.eql(u8, f[9], "1")) {
        observed_status = "ok";
        _ = reader.reader().peek(buffer.len) catch |err| blk: {
            observed_status = @errorName(err);
            break :blk &.{};
        };
        if (std.mem.eql(u8, f[10], "1")) reader.reader().toss(reader.reader().bufferedLen());
        try out.print("primed-{s}|", .{observed_status});
    } else try out.writeAll("primed-skip|");
    try snapshot(out, &reader, buffer, output);
    try out.writeByte('~');
    observed_status = try read(&reader, &output, try number(f[0]), @intCast(try number(f[4])));
    observed_output = output;
    try out.print("{s}|", .{observed_status});
    try snapshot(out, &reader, buffer, output);
    try out.writeByte('~');
    observed_status = "ok";
    reader.seekBy(try std.fmt.parseInt(i64, f[8], 10)) catch |err| {
        observed_status = @errorName(err);
    };
    observed_output = output;
    try out.print("{s}|", .{observed_status});
    try snapshot(out, &reader, buffer, output);
    try out.writeByte('~');
    if (std.mem.eql(u8, f[6], "0") and try number(f[7]) > 0) {
        if (c.witty_reader_delimiter_seed(try number(f[5]), try number(f[7])) != 0) return error.Seed;
    }
    observed_status = try read(&reader, &output, try number(f[0]), @intCast(try number(f[4])));
    observed_output = output;
    try out.print("{s}|", .{observed_status});
    try snapshot(out, &reader, buffer, output);
    try out.writeByte('~');
    var wire: W.Allocating = .init(a);
    var drain: isize = -3;
    while (true) {
        var bytes: [4096]u8 = undefined;
        drain = c.witty_reader_delimiter_drain(&bytes, bytes.len);
        if (drain <= 0) break;
        try wire.writer.writeAll(bytes[0..@intCast(drain)]);
    }
    try out.print("{d}:", .{drain});
    try hex(out, wire.written());
}
fn simpleSnapshot(out: *W, reader: *io.ReadStream, buffer: []const u8, output: []const u8) !void {
    try out.print("{d}:", .{reader.getPos()});
    if (reader.getEndPos()) |size| try out.print("{d}|", .{size}) else |err| try out.print("{s}|", .{@errorName(err)});
    try hex(out, buffer);
    try out.writeByte('|');
    try hex(out, output);
    try out.writeByte('|');
    try hex(out, reader.reader().buffered());
}
fn simpleRecord(out: *W, line: []const u8, path: [:0]const u8) !void {
    var split = std.mem.splitScalar(u8, line, '|');
    var f: [7][]const u8 = undefined;
    for (&f) |*value| value.* = split.next().?;
    const data = try a.alloc(u8, f[6].len / 2);
    _ = try std.fmt.hexToBytes(data, f[6]);
    var buffer = try a.alloc(u8, try number(f[2]));
    @memset(buffer, 165);
    const kind = try number(f[0]);
    var reader = io.ReadStream.initMemory(data);
    if (kind != 0) {
        const fd = c.witty_reader_exclusive_payload(path.ptr, data.ptr, data.len);
        if (fd < 0) return error.Setup;
        reader = if (kind == 1) io.ReadStream.initFile(.{ .handle = fd }, buffer) else .{ .file = std.fs.File.Reader.initStreaming(.{ .handle = fd }, buffer) };
    } else buffer = data;
    defer {
        if (kind != 0 and c.witty_reader_delimiter_cleanup() != 0) @panic("Exclusive payload cleanup failed");
    }
    var output: []const u8 = &.{};
    var status: []const u8 = "ok";
    if (try number(f[3]) > 0) reader.seekTo(try number(f[3])) catch |err| {
        status = @errorName(err);
    };
    try out.print("{s}|", .{status});
    try simpleSnapshot(out, &reader, buffer, output);
    try out.writeByte('~');
    for (0..3) |attempt| {
        status = try read(&reader, &output, try number(f[1]), @intCast(try number(f[4])));
        try out.print("{s}|", .{status});
        try simpleSnapshot(out, &reader, buffer, output);
        try out.writeByte('~');
        if (attempt == 0) {
            status = "ok";
            reader.seekBy(try std.fmt.parseInt(i64, f[5], 10)) catch |err| {
                status = @errorName(err);
            };
            try out.print("{s}|", .{status});
            try simpleSnapshot(out, &reader, buffer, output);
            try out.writeByte('~');
        }
    }
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    var out: W.Allocating = .init(a);
    if (std.mem.eql(u8, args[1], "--simple")) {
        const data = try std.fs.cwd().readFileAlloc(a, args[2], 10485760);
        var it = std.mem.tokenizeScalar(u8, data, '\n');
        var i: usize = 0;
        while (it.next()) |line| : (i += 1) {
            const path = try std.fmt.allocPrintSentinel(a, "{s}.{d}.owned", .{ args[2], i }, 0);
            try simpleRecord(&out.writer, line, path);
            try out.writer.writeByte('\n');
        }
    } else if (std.mem.eql(u8, args[1], "--trap")) {
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
