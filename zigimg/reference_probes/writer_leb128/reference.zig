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
fn number(text: []const u8) !usize {
    return std.fmt.parseInt(usize, text, 10);
}
fn hex(out: *W, data: []const u8) !void {
    for (data) |byte| try out.print("{x:0>2}", .{byte});
}
fn snapshot(out: *W, writer: *io.WriteStream, buffer: []const u8) !void {
    var contents: [4096]u8 = undefined;
    const n = if (observed_file) c.witty_writer_seek_view(&contents, contents.len) else 0;
    if (n < 0) return error.Observer;
    try out.print("{d}:{d}:{d}|", .{ writer.getPos(), if (observed_file) c.witty_writer_seek_valid() else 0, if (observed_file) c.witty_writer_seek_refs() else 0 });
    try hex(out, buffer);
    try out.writeByte('|');
    try hex(out, writer.writer().buffered());
    try out.writeByte('|');
    try hex(out, contents[0..@intCast(n)]);
}
fn observe(message: []const u8, first_trace: ?usize) noreturn {
    if (observed_path) |path| {
        var out: W.Allocating = .init(a);
        out.writer.print("{s}|", .{observed_status}) catch @trap();
        snapshot(&out.writer, observed_writer.?, observed_buffer) catch @trap();
        std.fs.cwd().writeFile(.{ .sub_path = path, .data = out.written() }) catch @trap();
        _ = c.witty_writer_seek_cleanup();
    }
    std.debug.defaultPanic(message, first_trace);
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

fn typedWrite(comptime T: type, writer: *io.WriteStream, raw: u64, op: usize) []const u8 {
    const U = std.meta.Int(.unsigned, @bitSizeOf(T));
    const value: T = @bitCast(@as(U, @truncate(raw)));
    switch (op) {
        0 => writer.writer().writeLeb128(value) catch |err| return @errorName(err),
        1 => writer.writer().writeUleb128(value) catch |err| return @errorName(err),
        else => writer.writer().writeSleb128(value) catch |err| return @errorName(err),
    }
    return "ok";
}
fn operate(writer: *io.WriteStream, raw: u64, tag: usize, op: usize) []const u8 {
    return switch (tag) {
        0 => typedWrite(u8, writer, raw, op),
        1 => typedWrite(u16, writer, raw, op),
        2 => typedWrite(u32, writer, raw, op),
        3 => typedWrite(u64, writer, raw, op),
        4 => typedWrite(usize, writer, raw, op),
        5 => typedWrite(i8, writer, raw, op),
        6 => typedWrite(i16, writer, raw, op),
        7 => typedWrite(i32, writer, raw, op),
        8 => typedWrite(i64, writer, raw, op),
        9 => typedWrite(isize, writer, raw, op),
        10 => typedWrite(Alias0, writer, raw, op),
        11 => typedWrite(Alias1, writer, raw, op),
        12 => typedWrite(Alias2, writer, raw, op),
        13 => typedWrite(Alias3, writer, raw, op),
        14 => typedWrite(Alias4, writer, raw, op),
        15 => typedWrite(Alias5, writer, raw, op),
        16 => typedWrite(Alias6, writer, raw, op),
        17 => typedWrite(Alias7, writer, raw, op),
        18 => typedWrite(Alias8, writer, raw, op),
        19 => typedWrite(Alias9, writer, raw, op),
        else => unreachable,
    };
}
fn record(out: *W, line: []const u8, path: [:0]const u8) !void {
    var split = std.mem.splitScalar(u8, line, '|');
    var f: [9][]const u8 = undefined;
    for (&f) |*item| item.* = split.next().?;
    const kind = try number(f[0]);
    const capacity = try number(f[1]);
    const start = try number(f[2]);
    const prefix = try a.alloc(u8, f[3].len / 2);
    _ = try std.fmt.hexToBytes(prefix, f[3]);
    const buffer = try a.alloc(u8, capacity);
    @memset(buffer, 165);
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
    observed_status = "setup";
    var status: []const u8 = "ok";
    writer.seekTo(start) catch |err| {
        status = @errorName(err);
    };
    try out.print("{s}|", .{status});
    try snapshot(out, &writer, buffer);
    try out.writeByte('~');
    status = "ok";
    writer.writer().writeAll(prefix) catch |err| {
        status = @errorName(err);
    };
    if (kind > 0) {
        if (std.mem.eql(u8, f[7], "1") and c.witty_writer_seek_replace(1) != 0) return error.Replace;
        if (std.mem.eql(u8, f[7], "2") and c.witty_writer_seek_close() != 0) return error.Close;
    }
    try out.print("{s}|", .{status});
    try snapshot(out, &writer, buffer);
    try out.writeByte('~');
    for (0..3) |attempt| {
        observed_status = "calling";
        status = operate(&writer, try std.fmt.parseInt(u64, f[6], 10), try number(f[4]), try number(f[5]));
        observed_status = status;
        try out.print("{s}|", .{status});
        try snapshot(out, &writer, buffer);
        try out.writeByte('~');
        status = "ok";
        if (attempt == 0) {
            writer.seekTo(try number(f[8])) catch |err| {
                status = @errorName(err);
            };
        } else {
            writer.flush() catch |err| {
                status = @errorName(err);
            };
        }
        try out.print("{s}|", .{status});
        try snapshot(out, &writer, buffer);
        try out.writeByte('~');
    }
    var wire: std.array_list.Managed(u8) = .init(a);
    var drain: isize = -3;
    if (kind > 0 and std.mem.eql(u8, f[7], "1")) {
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
