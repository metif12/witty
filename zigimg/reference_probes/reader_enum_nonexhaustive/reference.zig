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
    try out.writeAll(output);
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
const OpenU8 = enum(u8) { first = 0, second = 2, third = 131, fourth = 255, _ };
const OpenU16 = enum(u16) { first = 0, second = 2, third = 32771, fourth = 65535, _ };
const OpenU32 = enum(u32) { first = 0, second = 2, third = 2147483651, fourth = 4294967295, _ };
const OpenU64 = enum(u64) { first = 0, second = 2, third = 9223372036854775811, fourth = 18446744073709551615, _ };
const OpenI8 = enum(i8) { first = -128, second = -3, third = 0, fourth = 126, _ };
const OpenI16 = enum(i16) { first = -32768, second = -3, third = 0, fourth = 32766, _ };
const OpenI32 = enum(i32) { first = -2147483648, second = -3, third = 0, fourth = 2147483646, _ };
const OpenI64 = enum(i64) { first = -9223372036854775808, second = -3, third = 0, fourth = 9223372036854775806, _ };
const AliasOpenU8 = OpenU8;
const AliasOpenU16 = OpenU16;
const AliasOpenU32 = OpenU32;
const AliasOpenU64 = OpenU64;
const AliasOpenI8 = OpenI8;
const AliasOpenI16 = OpenI16;
const AliasOpenI32 = OpenI32;
const AliasOpenI64 = OpenI64;
const PngCompression = @import("src/formats/png.zig").CompressionMethod;
const PngFilter = @import("src/formats/png.zig").FilterMethod;
const AliasCompression = PngCompression;
const AliasFilter = PngFilter;

fn enumRead(comptime T: type, reader: *io.ReadStream, output: *[]const u8, endian: std.builtin.Endian) ![]const u8 {
    const value = reader.reader().takeEnumNonexhaustive(T, endian) catch |err| return @errorName(err);
    const Tag = @typeInfo(T).@"enum".tag_type;
    const U = std.meta.Int(.unsigned, @bitSizeOf(Tag));
    output.* = try std.fmt.allocPrint(a, "{d}:{d}", .{ @intFromEnum(value), @as(U, @bitCast(@intFromEnum(value))) });
    return "ok";
}
fn operate(reader: *io.ReadStream, output: *[]const u8, tag: usize, order: usize) ![]const u8 {
    const endian: std.builtin.Endian = if (order % 2 == 0) .big else .little;
    return switch (tag) {
        8 => enumRead(OpenU8, reader, output, endian),
        9 => enumRead(OpenU16, reader, output, endian),
        10 => enumRead(OpenU32, reader, output, endian),
        11 => enumRead(OpenU64, reader, output, endian),
        12 => enumRead(OpenI8, reader, output, endian),
        13 => enumRead(OpenI16, reader, output, endian),
        14 => enumRead(OpenI32, reader, output, endian),
        15 => enumRead(OpenI64, reader, output, endian),
        24 => enumRead(AliasOpenU8, reader, output, endian),
        25 => enumRead(AliasOpenU16, reader, output, endian),
        26 => enumRead(AliasOpenU32, reader, output, endian),
        27 => enumRead(AliasOpenU64, reader, output, endian),
        28 => enumRead(AliasOpenI8, reader, output, endian),
        29 => enumRead(AliasOpenI16, reader, output, endian),
        30 => enumRead(AliasOpenI32, reader, output, endian),
        31 => enumRead(AliasOpenI64, reader, output, endian),
        32 => enumRead(PngCompression, reader, output, endian),
        33 => enumRead(PngFilter, reader, output, endian),
        34 => enumRead(AliasCompression, reader, output, endian),
        35 => enumRead(AliasFilter, reader, output, endian),
        else => unreachable,
    };
}

fn record(out: *W, line: []const u8, path: [:0]const u8) !void {
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
        status = try operate(&reader, &output, try number(f[12]), try number(f[13]));
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
