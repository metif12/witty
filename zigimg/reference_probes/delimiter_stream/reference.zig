const std = @import("std");
const io = @import("src/io.zig");
const c = @cImport({
    @cDefine("WITTY_READER_DELIMITER_DECLARATIONS", "1");
    @cDefine("WITTY_WRITER_SEEK_DECLARATIONS", "1");
    @cInclude("fixture_shims.h");
});
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_status: []const u8 = "";
var observed_reader: ?*io.ReadStream = null;
var observed_writer: ?*io.WriteStream = null;
var observed_input: []const u8 = &.{};
var observed_output: []const u8 = &.{};
var observed_count: []const u8 = "-";
var observed_read_file = false;
var observed_write_file = false;
fn number(text: []const u8) !usize {
    return std.fmt.parseInt(usize, text, 10);
}
fn hex(out: *W, data: []const u8) !void {
    for (data) |byte| try out.print("{x:0>2}", .{byte});
}
fn state(out: *W, reader: *io.ReadStream, writer: *io.WriteStream, input: []const u8, output: []const u8) !void {
    if (reader.getEndPos()) |size| try out.print("{d}", .{size}) else |err| try out.print("{s}", .{@errorName(err)});
    try out.print(":{d}:{d}|", .{ if (observed_read_file) c.witty_reader_delimiter_valid() else 0, if (observed_read_file) c.witty_reader_delimiter_refs() else 0 });
    try hex(out, input);
    try out.writeByte('|');
    try hex(out, reader.reader().buffered());
    try out.print("|{d}:{d}:{d}|", .{ writer.getPos(), if (observed_write_file) c.witty_writer_seek_valid() else 0, if (observed_write_file) c.witty_writer_seek_refs() else 0 });
    try hex(out, output);
    try out.writeByte('|');
    try hex(out, writer.writer().buffered());
    try out.writeByte('|');
    if (observed_write_file) {
        var actual: [4096]u8 = undefined;
        const n = c.witty_writer_seek_view(&actual, actual.len);
        if (n < 0) return error.WriterView;
        try hex(out, actual[0..@intCast(n)]);
    }
    try out.print("|{s}", .{observed_count});
}
fn snapshot(out: *W, reader: *io.ReadStream, writer: *io.WriteStream, input: []const u8, output: []const u8) !void {
    try out.print("{d}:", .{reader.getPos()});
    try state(out, reader, writer, input, output);
}
fn observe(message: []const u8, first_trace: ?usize) noreturn {
    if (observed_path) |path| {
        var out: W.Allocating = .init(a);
        out.writer.print("{s}|", .{observed_status}) catch @trap();
        state(&out.writer, observed_reader.?, observed_writer.?, observed_input, observed_output) catch @trap();
        std.fs.cwd().writeFile(.{ .sub_path = path, .data = out.written() }) catch @trap();
        _ = c.witty_reader_delimiter_cleanup();
        _ = c.witty_writer_seek_cleanup();
    }
    std.debug.defaultPanic(message, first_trace);
}
fn read(reader: *io.ReadStream, writer: *io.WriteStream, api: usize, delimiter: u8, limit: usize) ![]const u8 {
    const count = switch (api) {
        0 => reader.reader().streamDelimiter(writer.writer(), delimiter) catch |err| return @errorName(err),
        1 => reader.reader().streamDelimiterEnding(writer.writer(), delimiter) catch |err| return @errorName(err),
        else => reader.reader().streamDelimiterLimit(writer.writer(), delimiter, .limited(limit)) catch |err| return @errorName(err),
    };
    observed_count = try std.fmt.allocPrint(a, "{d}", .{count});
    return "ok";
}
fn drain(out: *W, writing: bool, filled: isize) !void {
    var wire: W.Allocating = .init(a);
    var prefix = filled;
    var status: isize = -3;
    while (true) {
        var bytes: [4096]u8 = undefined;
        status = if (writing) c.witty_writer_seek_drain(&bytes, bytes.len) else c.witty_reader_delimiter_drain(&bytes, bytes.len);
        if (status <= 0) break;
        for (bytes[0..@intCast(status)]) |byte| {
            if (prefix > 0) {
                if (byte != 211) return error.FullPipePrefix;
                prefix -= 1;
            } else try wire.writer.writeByte(byte);
        }
    }
    if (prefix != 0) return error.FullPipePrefixMissing;
    try out.print("{d}:", .{status});
    try hex(out, wire.written());
}
fn record(out: *W, line: []const u8, path: [:0]const u8) !void {
    var split = std.mem.splitScalar(u8, line, '|');
    var f: [15][]const u8 = undefined;
    for (&f) |*value| value.* = split.next().?;
    const rkind = try number(f[0]);
    const api = try number(f[1]);
    const rcap = try number(f[2]);
    const wkind = try number(f[3]);
    const wcap = try number(f[4]);
    const prefill = try number(f[5]);
    const start = try number(f[6]);
    const delimiter: u8 = @intCast(try number(f[7]));
    const limit = try number(f[8]);
    const data = try a.alloc(u8, f[9].len / 2);
    _ = try std.fmt.hexToBytes(data, f[9]);
    const replace = try number(f[10]);
    const consumed = try number(f[11]);
    const seed = try number(f[12]);
    const prime = try number(f[13]);
    const delta = try std.fmt.parseInt(i64, f[14], 10);
    var input = try a.alloc(u8, rcap);
    @memset(input, 165);
    var reader = io.ReadStream.initMemory(data);
    if (rkind == 0) input = data else {
        const fd = c.witty_reader_exclusive_payload(path.ptr, data.ptr, data.len);
        if (fd < 0) return error.ReaderSetup;
        reader = if (rkind == 1) io.ReadStream.initFile(.{ .handle = fd }, input) else .{ .file = std.fs.File.Reader.initStreaming(.{ .handle = fd }, input) };
    }
    const output = try a.alloc(u8, wcap);
    @memset(output, 90);
    var writer = io.WriteStream.initMemory(output);
    var filled: isize = 0;
    if (wkind > 0) {
        const writer_path = try std.fmt.allocPrintSentinel(a, "{s}.writer", .{path}, 0);
        const fd = c.witty_delimiter_stream_writer(writer_path.ptr);
        if (fd < 0) return error.WriterSetup;
        writer = if (wkind == 2 or wkind == 4 or wkind == 6) .{ .file = std.fs.File.Writer.initStreaming(.{ .handle = fd }, output) } else io.WriteStream.initFile(.{ .handle = fd }, output);
        if (wkind >= 3 and c.witty_writer_seek_replace(1) != 0) return error.WriterReplace;
        if (wkind >= 5) {
            filled = c.witty_delimiter_stream_fill();
            if (filled <= 0) return error.WriterFill;
        }
    }
    defer {
        if (rkind > 0 and c.witty_reader_delimiter_cleanup() != 0) @panic("Reader cleanup failed");
        if (wkind > 0 and c.witty_writer_seek_cleanup() != 0) @panic("Writer cleanup failed");
    }
    const prefix = try a.alloc(u8, prefill);
    for (prefix, 0..) |*byte, index| byte.* = @truncate(225 + index);
    try writer.writer().writeAll(prefix);
    observed_reader = &reader;
    observed_writer = &writer;
    observed_input = input;
    observed_output = output;
    observed_count = "-";
    observed_status = "ok";
    observed_read_file = rkind > 0;
    observed_write_file = wkind > 0;
    var status: []const u8 = "ok";
    if (start > 0) reader.seekTo(start) catch |err| {
        status = @errorName(err);
    };
    if (replace > 0) {
        _ = try reader.reader().peek(rcap);
        reader.reader().toss(consumed);
    }
    try out.print("{s}|", .{status});
    try snapshot(out, &reader, &writer, input, output);
    try out.writeByte('~');
    if (replace > 0) {
        if (c.witty_reader_delimiter_replace(0) != 0 or c.witty_reader_delimiter_seed(0, seed) != 0) return error.ReaderReplace;
        if (replace == 2 and c.witty_reader_delimiter_shutdown() != 0) return error.ReaderShutdown;
    }
    status = "skip";
    if (prime > 0) {
        status = "ok";
        _ = reader.reader().peek(rcap) catch |err| blk: {
            status = @errorName(err);
            break :blk &.{};
        };
        if (prime == 2) reader.reader().toss(reader.reader().bufferedLen());
    }
    try out.print("{s}|", .{status});
    try snapshot(out, &reader, &writer, input, output);
    try out.writeByte('~');
    for (0..3) |attempt| {
        observed_status = "calling";
        status = try read(&reader, &writer, api, delimiter, limit);
        observed_status = status;
        try out.print("{s}|", .{status});
        try snapshot(out, &reader, &writer, input, output);
        try out.writeByte('~');
        if (attempt == 0) {
            status = "ok";
            reader.seekBy(delta) catch |err| {
                status = @errorName(err);
            };
            try out.print("{s}|", .{status});
            try snapshot(out, &reader, &writer, input, output);
            try out.writeByte('~');
        }
        if (attempt == 1) {
            status = "ok";
            writer.flush() catch |err| {
                status = @errorName(err);
            };
            try out.print("{s}|", .{status});
            try snapshot(out, &reader, &writer, input, output);
            try out.writeByte('~');
        }
    }
    if (replace > 0) try drain(out, false, 0) else try out.writeAll("skip");
    try out.writeByte('/');
    if (wkind > 0) try drain(out, true, filled) else try out.writeAll("skip");
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
