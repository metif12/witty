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
const Alias0 = u8;
const Alias1 = u16;
const Alias2 = u32;
const Alias3 = u64;
const Alias4 = usize;
const Alias5 = i8;
const Alias6 = i16;
const Alias7 = i32;
const Alias8 = i64;
const Alias9 = isize;
const Alias10 = f32;
const Alias11 = f64;
const Alias12 = bool;
fn element(comptime T: type, raw: u64) T {
    if (T == bool) return raw & 1 != 0;
    return @bitCast(@as(std.meta.Int(.unsigned, @bitSizeOf(T)), @truncate(raw)));
}
fn formatBytes(comptime T: type, writer: *io.WriteStream, value: T, format: usize, options: std.fmt.Options, depth: usize) []const u8 {
    switch (format) {
        1 => writer.writer().printValue("s", options, value, depth) catch |err| return @errorName(err),
        2 => writer.writer().printValue("x", options, value, depth) catch |err| return @errorName(err),
        3 => writer.writer().printValue("X", options, value, depth) catch |err| return @errorName(err),
        4 => writer.writer().printValue("b64", options, value, depth) catch |err| return @errorName(err),
        else => unreachable,
    }
    return "ok";
}
fn operate(comptime T: type, writer: *io.WriteStream, values: [3]T, shape: usize, format: usize, options: std.fmt.Options, depth: usize) []const u8 {
    if (T == u8) {
        if (format > 0) {
            if (shape == 3) return formatBytes([1]T, writer, .{values[0]}, format, options, depth);
            return formatBytes([3]T, writer, values, format, options, depth);
        }
    }
    const nested: [2][3]T = .{ values, values };
    const triple: [2][2][3]T = .{ nested, nested };
    switch (shape) {
        0 => writer.writer().printValue("any", options, values, depth) catch |err| return @errorName(err),
        1 => writer.writer().printValue("any", options, nested, depth) catch |err| return @errorName(err),
        2 => writer.writer().printValue("any", options, triple, depth) catch |err| return @errorName(err),
        3 => writer.writer().printValue("any", options, [1]T{values[0]}, depth) catch |err| return @errorName(err),
        4 => writer.writer().printValue("any", options, @as([]const [3]T, &nested), depth) catch |err| return @errorName(err),
        5 => writer.writer().printValue("any", options, [2][]const T{ values[0..1], values[1..] }, depth) catch |err| return @errorName(err),
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

    var values: [3]T = undefined;
    for (&values, 0..) |*v, i| v.* = element(T, raw +% (@as(u64, @intCast(i)) *% 0x9e3779b97f4a7c15));
    observed_elements = std.mem.sliceAsBytes(&values);
    observed_shape = "3;2,3;2,2,3;1;dynamic,2,3;fixed,1,2";
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
    status = operate(T, &writer, values, try number(f[4]), try number(f[8]), options, try number(f[15]));
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
        0 => try typedRecord(u8, out, line, path),
        1 => try typedRecord(u16, out, line, path),
        2 => try typedRecord(u32, out, line, path),
        3 => try typedRecord(u64, out, line, path),
        4 => try typedRecord(usize, out, line, path),
        5 => try typedRecord(i8, out, line, path),
        6 => try typedRecord(i16, out, line, path),
        7 => try typedRecord(i32, out, line, path),
        8 => try typedRecord(i64, out, line, path),
        9 => try typedRecord(isize, out, line, path),
        10 => try typedRecord(f32, out, line, path),
        11 => try typedRecord(f64, out, line, path),
        12 => try typedRecord(bool, out, line, path),
        13 => try typedRecord(Alias0, out, line, path),
        14 => try typedRecord(Alias1, out, line, path),
        15 => try typedRecord(Alias2, out, line, path),
        16 => try typedRecord(Alias3, out, line, path),
        17 => try typedRecord(Alias4, out, line, path),
        18 => try typedRecord(Alias5, out, line, path),
        19 => try typedRecord(Alias6, out, line, path),
        20 => try typedRecord(Alias7, out, line, path),
        21 => try typedRecord(Alias8, out, line, path),
        22 => try typedRecord(Alias9, out, line, path),
        23 => try typedRecord(Alias10, out, line, path),
        24 => try typedRecord(Alias11, out, line, path),
        25 => try typedRecord(Alias12, out, line, path),
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
