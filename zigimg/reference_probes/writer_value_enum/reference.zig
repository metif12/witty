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
var observed_file = false;
var observed_status: []const u8 = "";
var observed_payload: []const u8 = &.{};
var observed_options: std.fmt.Options = .{};
var observed_base: u8 = 0;
var observed_case: usize = 0;
var observed_tag: usize = 0;
var observed_length: usize = 0;
var observed_elements: []const u8 = &.{};
var observed_shape: []const u8 = "";
var observed_vectors: []const []const u8 = &.{};
fn number(text: []const u8) !usize {
    return std.fmt.parseInt(usize, text, 10);
}
fn hex(out: *W, data: []const u8) !void {
    for (data) |byte| try out.print("{x:0>2}", .{byte});
}
fn state(out: *W, writer: *io.WriteStream, buffer: []const u8) !void {
    var contents: [4096]u8 = undefined;
    const n = if (observed_file) c.witty_writer_seek_view(&contents, contents.len) else 0;
    if (n < 0) return error.Observer;
    const unused = writer.writer().unusedCapacitySlice();
    const offset = if (buffer.len == 0) 0 else @intFromPtr(unused.ptr) - @intFromPtr(buffer.ptr);
    try out.print("{d}:{d}:{d}:{d}:{d}:{d}|", .{ writer.getPos(), writer.writer().unusedCapacityLen(), writer.writer().buffered().len, offset, if (observed_file) c.witty_writer_seek_valid() else 0, if (observed_file) c.witty_writer_seek_refs() else 0 });
    try hex(out, buffer);
    try out.writeByte('|');
    try hex(out, writer.writer().buffered());
    try out.writeByte('|');
    try hex(out, unused);
    try out.writeByte('|');
    try hex(out, observed_payload);
    try out.writeByte('#');
    for (observed_vectors, 0..) |bytes, i| {
        if (i != 0) try out.writeByte(';');
        try out.print("{d},{d}", .{ @intFromPtr(bytes.ptr) - @intFromPtr(observed_payload.ptr), bytes.len });
    }
    try out.writeByte('#');
    if (observed_options.precision) |value| {
        try out.print("{d}", .{value});
    } else try out.writeByte('-');
    try out.writeByte(':');
    if (observed_options.width) |value| {
        try out.print("{d}", .{value});
    } else try out.writeByte('-');
    try out.print(":{d}:{d}:{d}:{d}:{d}:{d}", .{ @intFromEnum(observed_options.alignment), observed_options.fill, observed_base, observed_case, observed_tag, observed_length });
    try out.writeByte('#');
    try hex(out, observed_elements);
    try out.print("#{s}", .{observed_shape});
    try out.writeByte('|');
    try hex(out, contents[0..@intCast(n)]);
}
fn observe(message: []const u8, first_trace: ?usize) noreturn {
    if (observed_path) |path| {
        var out: W.Allocating = .init(a);
        out.writer.print("{s}|", .{observed_status}) catch @trap();
        state(&out.writer, observed_writer.?, observed_buffer) catch @trap();
        std.fs.cwd().writeFile(.{ .sub_path = path, .data = out.written() }) catch @trap();
        if (observed_file) _ = c.witty_writer_seek_cleanup();
    }
    std.debug.defaultPanic(message, first_trace);
}
fn change(bytes: []u8, mode: usize, mask: u8) void {
    if (mode == 0 or bytes.len == 0) return;
    const index = if (mode == 1) 0 else bytes.len - 1;
    bytes[index] ^= mask;
}
fn snapshot(out: *W, status: []const u8, writer: *io.WriteStream, buffer: []const u8) !void {
    try out.print("{s}|", .{status});
    try state(out, writer, buffer);
    try out.writeByte('~');
}
const Closed0 = enum(u8) { first = 0, second = 2, third = 131, long_tag = 255 };

const Closed1 = enum(u16) { first = 0, second = 2, third = 32771, long_tag = 65535 };

const Closed2 = enum(u32) { first = 0, second = 2, third = 2147483651, long_tag = 4294967295 };

const Closed3 = enum(u64) { first = 0, second = 2, third = 9223372036854775811, long_tag = 18446744073709551615 };

const Closed4 = enum(i8) { first = -128, second = -3, third = 0, long_tag = 126 };

const Closed5 = enum(i16) { first = -32768, second = -3, third = 0, long_tag = 32766 };

const Closed6 = enum(i32) { first = -2147483648, second = -3, third = 0, long_tag = 2147483646 };

const Closed7 = enum(i64) { first = -9223372036854775808, second = -3, third = 0, long_tag = 9223372036854775806 };

const Open0 = enum(u8) { first = 0, second = 2, third = 131, long_tag = 255, _ };

const Open1 = enum(u16) { first = 0, second = 2, third = 32771, long_tag = 65535, _ };

const Open2 = enum(u32) { first = 0, second = 2, third = 2147483651, long_tag = 4294967295, _ };

const Open3 = enum(u64) { first = 0, second = 2, third = 9223372036854775811, long_tag = 18446744073709551615, _ };

const Open4 = enum(i8) { first = -128, second = -3, third = 0, long_tag = 126, _ };

const Open5 = enum(i16) { first = -32768, second = -3, third = 0, long_tag = 32766, _ };

const Open6 = enum(i32) { first = -2147483648, second = -3, third = 0, long_tag = 2147483646, _ };

const Open7 = enum(i64) { first = -9223372036854775808, second = -3, third = 0, long_tag = 9223372036854775806, _ };
const AliasClosed0 = Closed0;
const AliasClosed1 = Closed1;
const AliasClosed2 = Closed2;
const AliasClosed3 = Closed3;
const AliasClosed4 = Closed4;
const AliasClosed5 = Closed5;
const AliasClosed6 = Closed6;
const AliasClosed7 = Closed7;
const AliasOpen0 = Open0;
const AliasOpen1 = Open1;
const AliasOpen2 = Open2;
const AliasOpen3 = Open3;
const AliasOpen4 = Open4;
const AliasOpen5 = Open5;
const AliasOpen6 = Open6;
const AliasOpen7 = Open7;

fn operate(comptime T: type, writer: *io.WriteStream, value: T, values: []const T, nested: []const []const T, shape: usize, options: std.fmt.Options, depth: usize, format: usize) []const u8 {
    switch (shape) {
        0 => switch (format) {
            0 => writer.writer().printValue("", options, value, depth) catch |err| return @errorName(err),
            1 => writer.writer().printValue("any", options, value, depth) catch |err| return @errorName(err),
            2 => writer.writer().printValue("d", options, value, depth) catch |err| return @errorName(err),
            3 => writer.writer().printValue("b", options, value, depth) catch |err| return @errorName(err),
            4 => writer.writer().printValue("o", options, value, depth) catch |err| return @errorName(err),
            5 => writer.writer().printValue("x", options, value, depth) catch |err| return @errorName(err),
            6 => writer.writer().printValue("X", options, value, depth) catch |err| return @errorName(err),
            7 => writer.writer().printValue("t", options, value, depth) catch |err| return @errorName(err),
            else => unreachable,
        },
        1 => writer.writer().printValue("any", options, values, depth) catch |err| return @errorName(err),
        2 => writer.writer().printValue("any", options, nested, depth) catch |err| return @errorName(err),
        else => unreachable,
    }
    return "ok";
}
fn typedRecord(comptime T: type, out: *W, line: []const u8, path: [:0]const u8) !void {
    var split = std.mem.splitScalar(u8, line, '|');
    var f: [16][]const u8 = undefined;
    for (&f) |*item| item.* = split.next().?;
    const kind = try number(f[0]);
    const cap = try number(f[1]);
    const start = try number(f[2]);
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
        if (kind > 0 and c.witty_writer_seek_cleanup() != 0) @panic("Writer cleanup failed");
    }
    observed_writer = &writer;
    observed_buffer = buffer;
    observed_file = kind > 0;
    const raw: u64 = try number(f[13]);
    const payload = try a.alloc(u8, 264);
    for (payload[0..8], 0..) |*b, i| b.* = @truncate(raw >> @as(u6, @intCast(i * 8)));
    for (payload[8..], 0..) |*b, i| b.* = @truncate(i * 23 + try number(f[9]));
    observed_length = try number(f[8]);
    const data = payload[0..8];
    observed_base = @intCast(try number(f[4]));
    observed_case = try number(f[15]);
    observed_tag = try number(f[14]);
    const options: std.fmt.Options = .{ .precision = if (std.mem.eql(u8, f[12], "-")) null else try number(f[12]), .width = if (std.mem.eql(u8, f[11], "1")) try number(f[5]) else null, .alignment = @enumFromInt(try number(f[10])), .fill = @intCast(try number(f[9])) };
    observed_options = options;
    observed_payload = payload;
    observed_vectors = try a.dupe([]const u8, &.{ data, payload[10 .. 10 + observed_length] });

    const Int = @typeInfo(T).@"enum".tag_type;
    const Bits = std.meta.Int(.unsigned, @bitSizeOf(Int));
    const value: T = @enumFromInt(@as(Int, @bitCast(@as(Bits, @truncate(raw)))));
    const values = try a.alloc(T, if (observed_length == 0) 1 else 3);
    @memset(values, value);
    const nested = try a.dupe([]const T, &.{ values[0..1], values[1..], &.{} });
    observed_elements = std.mem.sliceAsBytes(values);
    observed_shape = switch (observed_length) {
        0 => "scalar",
        1 => "slice:3",
        2 => "nested:1,2,0",
        else => unreachable,
    };
    observed_status = "setup";
    writer.seekTo(start) catch {};
    const prefix = try a.alloc(u8, try number(f[3]));
    for (prefix, 0..) |*b, i| b.* = @truncate(i * 31 + 7);
    try writer.writer().writeAll(prefix);
    if (kind > 0) {
        if (std.mem.eql(u8, f[6], "1") and c.witty_writer_seek_replace(1) != 0) return error.Replace;
        if (std.mem.eql(u8, f[6], "2") and c.witty_writer_seek_close() != 0) return error.Close;
    }
    try snapshot(out, "setup", &writer, buffer);
    try snapshot(out, "ready", &writer, buffer);
    observed_status = "write";
    var status: []const u8 = "skip";
    status = operate(T, &writer, value, values, nested, observed_length, options, try number(f[15]), try number(f[4]));
    if (std.mem.eql(u8, status, "skip")) status = "ok";
    try snapshot(out, status, &writer, buffer);
    change(buffer, 1, @intCast(try number(f[9])));
    try snapshot(out, "caller", &writer, buffer);
    status = "skip";
    if (std.mem.eql(u8, f[7], "1")) {
        status = "ok";
        writer.flush() catch |err| {
            status = @errorName(err);
        };
    }
    try snapshot(out, status, &writer, buffer);
    var drain: isize = -3;
    var wire: std.array_list.Managed(u8) = .init(a);
    if (kind > 0 and std.mem.eql(u8, f[6], "1")) {
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
fn record(out: *W, line: []const u8, path: [:0]const u8) !void {
    var split = std.mem.splitScalar(u8, line, '|');
    for (0..14) |_| _ = split.next().?;
    switch (try number(split.next().?)) {
        0 => try typedRecord(Closed0, out, line, path),
        1 => try typedRecord(Closed1, out, line, path),
        2 => try typedRecord(Closed2, out, line, path),
        3 => try typedRecord(Closed3, out, line, path),
        4 => try typedRecord(Closed4, out, line, path),
        5 => try typedRecord(Closed5, out, line, path),
        6 => try typedRecord(Closed6, out, line, path),
        7 => try typedRecord(Closed7, out, line, path),
        8 => try typedRecord(Open0, out, line, path),
        9 => try typedRecord(Open1, out, line, path),
        10 => try typedRecord(Open2, out, line, path),
        11 => try typedRecord(Open3, out, line, path),
        12 => try typedRecord(Open4, out, line, path),
        13 => try typedRecord(Open5, out, line, path),
        14 => try typedRecord(Open6, out, line, path),
        15 => try typedRecord(Open7, out, line, path),
        16 => try typedRecord(AliasClosed0, out, line, path),
        17 => try typedRecord(AliasClosed1, out, line, path),
        18 => try typedRecord(AliasClosed2, out, line, path),
        19 => try typedRecord(AliasClosed3, out, line, path),
        20 => try typedRecord(AliasClosed4, out, line, path),
        21 => try typedRecord(AliasClosed5, out, line, path),
        22 => try typedRecord(AliasClosed6, out, line, path),
        23 => try typedRecord(AliasClosed7, out, line, path),
        24 => try typedRecord(AliasOpen0, out, line, path),
        25 => try typedRecord(AliasOpen1, out, line, path),
        26 => try typedRecord(AliasOpen2, out, line, path),
        27 => try typedRecord(AliasOpen3, out, line, path),
        28 => try typedRecord(AliasOpen4, out, line, path),
        29 => try typedRecord(AliasOpen5, out, line, path),
        30 => try typedRecord(AliasOpen6, out, line, path),
        31 => try typedRecord(AliasOpen7, out, line, path),
        else => unreachable,
    }
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
