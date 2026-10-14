const std = @import("std");
const io = @import("src/io.zig");
const c = @cImport({
    @cDefine("WITTY_READER_PREFILL_DECLARATIONS", "1");
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
    try out.print("{d}:{d}:{d}|", .{ try reader.getEndPos(), c.witty_reader_prefill_valid(), c.witty_reader_prefill_refs() });
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
        _ = c.witty_reader_prefill_cleanup();
    }
    std.debug.defaultPanic(message, first_trace);
}
fn read(reader: *io.ReadStream, output: []u8, api: usize) []const u8 {
    if (api == 0) {
        reader.reader().readSliceAll(output) catch |err| return @errorName(err);
    } else {
        const value = if (api == 1) reader.reader().take(output.len) catch |err| return @errorName(err) else reader.reader().peek(output.len) catch |err| return @errorName(err);
        @memcpy(output, value);
    }
    return "ok";
}
fn record(out: *W, line: []const u8, path: [:0]const u8) !void {
    var split = std.mem.splitScalar(u8, line, '|');
    var f: [9][]const u8 = undefined;
    for (&f) |*value| value.* = split.next().?;
    const fd = c.witty_reader_prefill_setup(path.ptr);
    if (fd < 0) return error.Setup;
    defer {
        if (c.witty_reader_prefill_cleanup() != 0) @panic("Prefill cleanup failed");
    }
    const buffer = try a.alloc(u8, try number(f[1]));
    @memset(buffer, 165);
    const output = try a.alloc(u8, try number(f[4]));
    @memset(output, 182);
    var reader = io.ReadStream.initFile(.{ .handle = fd }, buffer);
    observed_reader = &reader;
    observed_buffer = buffer;
    observed_output = output;
    try reader.seekTo(try number(f[2]));
    _ = try reader.reader().peek(buffer.len);
    reader.reader().toss(try number(f[3]));
    try snapshot(out, &reader, buffer, output);
    try out.writeByte('~');
    if (c.witty_reader_prefill_replace(0) != 0) return error.Replace;
    if (c.witty_reader_prefill_seed(0, try number(f[5])) != 0) return error.Seed;
    if (std.mem.eql(u8, f[6], "1") and c.witty_reader_prefill_shutdown() != 0) return error.Shutdown;
    try out.writeAll("rebound|");
    try snapshot(out, &reader, buffer, output);
    try out.writeByte('~');
    observed_status = read(&reader, output, try number(f[0]));
    try out.print("{s}|", .{observed_status});
    try snapshot(out, &reader, buffer, output);
    try out.writeByte('~');
    observed_status = "ok";
    reader.seekBy(try std.fmt.parseInt(i64, f[8], 10)) catch |err| {
        observed_status = @errorName(err);
    };
    try out.print("{s}|", .{observed_status});
    try snapshot(out, &reader, buffer, output);
    try out.writeByte('~');
    if (std.mem.eql(u8, f[6], "0") and try number(f[7]) > 0) {
        if (c.witty_reader_prefill_seed(try number(f[5]), try number(f[7])) != 0) return error.Seed;
    }
    observed_status = read(&reader, output, try number(f[0]));
    try out.print("{s}|", .{observed_status});
    try snapshot(out, &reader, buffer, output);
    try out.writeByte('~');
    var wire: W.Allocating = .init(a);
    var drain: isize = -3;
    while (true) {
        var bytes: [4096]u8 = undefined;
        drain = c.witty_reader_prefill_drain(&bytes, bytes.len);
        if (drain <= 0) break;
        try wire.writer.writeAll(bytes[0..@intCast(drain)]);
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
