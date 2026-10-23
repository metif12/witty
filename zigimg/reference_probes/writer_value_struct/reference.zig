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
const Empty = struct {};
const Numbers = struct { n: i64, u: u64, truth: bool };
const Sequences = struct { bytes: []const u8, fixed: [2]i16 };
const Nested = struct { child: Numbers, empty: Empty, items: []const Empty };
const Tag = enum(i32) { zero, high };
const Tagged = struct { tag: Tag, n: i32 };
const Custom = struct {
    n: i32,
    pub fn format(value: @This(), writer: *W) !void {
        try writer.printInt(value.n, 10, .lower, .{});
    }
};
const AliasEmpty = Empty;
const AliasNumbers = Numbers;
const AliasSequences = Sequences;
const AliasNested = Nested;
const AliasTagged = Tagged;
const AliasCustom = Custom;
fn numbers(raw: u64) Numbers {
    return .{ .n = @bitCast(raw), .u = raw, .truth = raw & 1 != 0 };
}
fn make(comptime T: type, raw: u64, payload: []const u8) T {
    if (T == Empty) return .{};
    if (T == Numbers) return numbers(raw);
    if (T == Sequences) return .{ .bytes = payload[8..11], .fixed = .{ @bitCast(@as(u16, @truncate(raw))), @bitCast(@as(u16, @truncate(raw >> 16))) } };
    if (T == Nested) return .{ .child = numbers(raw), .empty = .{}, .items = &.{ .{}, .{} } };
    if (T == Tagged) return .{ .tag = @enumFromInt(raw & 1), .n = @bitCast(@as(u32, @truncate(raw))) };
    if (T == Custom) return .{ .n = @bitCast(@as(u32, @truncate(raw))) };
    unreachable;
}
fn leaves(comptime T: type, value: T, out: *W) !void {
    switch (@typeInfo(T)) {
        .@"struct" => |info| inline for (info.fields) |field| {
            try leaves(field.type, @field(value, field.name), out);
        },
        .array => |info| for (value) |item| {
            try leaves(info.child, item, out);
        },
        .pointer => |info| for (value) |item| {
            try leaves(info.child, item, out);
        },
        else => try out.writeAll(std.mem.asBytes(&value)),
    }
}
fn operate(comptime T: type, writer: *io.WriteStream, value: T, values: []const T, nested: []const []const T, shape: usize, options: std.fmt.Options, depth: usize, format: usize) []const u8 {
    switch (shape) {
        0 => switch (format) {
            0 => if (T == Custom) unreachable else writer.writer().printValue("", options, value, depth) catch |err| return @errorName(err),
            1 => writer.writer().printValue("any", options, value, depth) catch |err| return @errorName(err),
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

    const value: T = make(T, raw, payload);
    const values = try a.alloc(T, if (observed_length == 0) 1 else 3);
    @memset(values, value);
    const nested = try a.dupe([]const T, &.{ values[0..1], values[1..], &.{} });
    var leaf_output: W.Allocating = .init(a);
    try leaves([]const T, values, &leaf_output.writer);
    observed_elements = leaf_output.written();
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
        0 => try typedRecord(Empty, out, line, path),
        1 => try typedRecord(Numbers, out, line, path),
        2 => try typedRecord(Sequences, out, line, path),
        3 => try typedRecord(Nested, out, line, path),
        4 => try typedRecord(Tagged, out, line, path),
        5 => try typedRecord(Custom, out, line, path),
        6 => try typedRecord(AliasEmpty, out, line, path),
        7 => try typedRecord(AliasNumbers, out, line, path),
        8 => try typedRecord(AliasSequences, out, line, path),
        9 => try typedRecord(AliasNested, out, line, path),
        10 => try typedRecord(AliasTagged, out, line, path),
        11 => try typedRecord(AliasCustom, out, line, path),
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
