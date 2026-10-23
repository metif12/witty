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
var observed_api: usize = 0;
var observed_length: usize = 0;
var observed_tag: usize = 0;
var observed_options: std.fmt.Options = .{};
var observed_depth: usize = 0;
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
    if (observed_options.precision) |option_value| {
        try out.print("{d}", .{option_value});
    } else try out.writeByte('-');
    try out.writeByte(':');
    if (observed_options.width) |option_value| {
        try out.print("{d}", .{option_value});
    } else try out.writeByte('-');
    try out.print(":{d}:{d}:{d}:{d}:{d}:{d}", .{ @intFromEnum(observed_options.alignment), observed_options.fill, observed_api, observed_tag, observed_length, observed_depth });
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
fn typed(comptime T: type, writer: *io.WriteStream, raw: usize, op: usize, count: usize, options: std.fmt.Options, depth: usize) []const u8 {
    switch (op) {
        1 => {
            const p: ?*T = if (raw == 0) null else @ptrFromInt(raw);
            writer.writer().printValue("*", options, p, depth) catch |err| return @errorName(err);
        },
        2, 5 => {
            const p: [*]allowzero align(1) T = @ptrFromInt(raw);
            const bytes = p[0..count];
            writer.writer().printValue("*", options, bytes, depth) catch |err| return @errorName(err);
        },
        6 => {
            const p: *allowzero align(1) *T = @ptrFromInt(raw);
            writer.writer().printValue("*", options, p, depth) catch |err| return @errorName(err);
        },
        7 => {
            const p: ?**T = if (raw == 0) null else @ptrFromInt(raw);
            writer.writer().printValue("*", options, p, depth) catch |err| return @errorName(err);
        },
        else => {
            const p: *allowzero align(1) T = @ptrFromInt(raw);
            writer.writer().printValue("*", options, p, depth) catch |err| return @errorName(err);
        },
    }
    return "ok";
}
fn operate(writer: *io.WriteStream, raw: u64, tag: usize, op: usize, count: usize, options: std.fmt.Options, depth: usize) []const u8 {
    if (op == 8) {
        const p: *allowzero anyopaque = @ptrFromInt(raw);
        writer.writer().printValue("*", options, p, depth) catch |err| return @errorName(err);
        return "ok";
    }
    return switch (tag) {
        0 => typed(u8, writer, raw, op, count, options, depth),
        1 => typed(u16, writer, raw, op, count, options, depth),
        2 => typed(u32, writer, raw, op, count, options, depth),
        3 => typed(u64, writer, raw, op, count, options, depth),
        4 => typed(usize, writer, raw, op, count, options, depth),
        5 => typed(i8, writer, raw, op, count, options, depth),
        6 => typed(i16, writer, raw, op, count, options, depth),
        7 => typed(i32, writer, raw, op, count, options, depth),
        8 => typed(i64, writer, raw, op, count, options, depth),
        9 => typed(isize, writer, raw, op, count, options, depth),
        10 => typed(f32, writer, raw, op, count, options, depth),
        11 => typed(f64, writer, raw, op, count, options, depth),
        12 => typed(bool, writer, raw, op, count, options, depth),
        else => unreachable,
    };
}
fn record(out: *W, line: []const u8, path: [:0]const u8) !void {
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
    const raw: u64 = try number(f[8]);
    const payload = try a.alloc(u8, 8);
    for (payload, 0..) |*byte, i| byte.* = @truncate(raw >> @as(u6, @intCast(i * 8)));
    observed_tag = try number(f[9]);
    observed_api = try number(f[6]);
    observed_length = try number(f[10]);
    observed_options = .{ .alignment = @enumFromInt(try number(f[11])), .fill = @intCast(try number(f[7])), .width = if (std.mem.eql(u8, f[13], "1")) try number(f[12]) else null, .precision = if (std.mem.eql(u8, f[14], "-")) null else try number(f[14]) };
    observed_depth = try number(f[15]);
    observed_payload = payload;
    observed_vectors = try a.dupe([]const u8, &.{payload});
    observed_status = "setup";
    writer.seekTo(start) catch {};
    const prefix = try a.alloc(u8, try number(f[3]));
    for (prefix, 0..) |*b, i| b.* = @truncate(i * 31 + 7);
    try writer.writer().writeAll(prefix);
    if (kind > 0) {
        if (std.mem.eql(u8, f[4], "1") and c.witty_writer_seek_replace(1) != 0) return error.Replace;
        if (std.mem.eql(u8, f[4], "2") and c.witty_writer_seek_close() != 0) return error.Close;
    }
    try snapshot(out, "setup", &writer, buffer);
    const api = try number(f[6]);
    try snapshot(out, "ready", &writer, buffer);
    observed_status = "write";
    var status: []const u8 = "skip";
    status = operate(&writer, raw, try number(f[9]), api, try number(f[10]), observed_options, observed_depth);
    if (std.mem.eql(u8, status, "skip")) status = "ok";
    try snapshot(out, status, &writer, buffer);
    change(buffer, 1, @intCast(try number(f[7])));
    try snapshot(out, "caller", &writer, buffer);
    status = "skip";
    if (std.mem.eql(u8, f[5], "1")) {
        status = "ok";
        writer.flush() catch |err| {
            status = @errorName(err);
        };
    }
    try snapshot(out, status, &writer, buffer);
    var drain: isize = -3;
    var wire: std.array_list.Managed(u8) = .init(a);
    if (kind > 0 and std.mem.eql(u8, f[4], "1")) {
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
