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
fn vectors(payload: []const u8, profile: usize) ![]const []const u8 {
    const selected: []const []const u8 = switch (profile) {
        0 => &.{},
        1 => &.{payload[0..0]},
        2 => &.{payload[0..1]},
        3 => &.{payload[0..3]},
        4 => &.{ payload[0..2], payload[4..4], payload[6..9] },
        5 => &.{ payload[0..1], payload[0..1], payload[0..1] },
        6 => &.{ payload[2..6], payload[0..3], payload[3..8], payload[2..2] },
        7 => &.{ payload[0..1], payload[3..5], payload[6..9], payload[9..10], payload[12..14], payload[15..18], payload[18..19], payload[21..23], payload[24..27], payload[27..28], payload[30..32], payload[33..36], payload[36..37], payload[39..41], payload[42..45] },
        8 => &.{ payload[0..1], payload[3..5], payload[6..9], payload[9..10], payload[12..14], payload[15..18], payload[18..19], payload[21..23], payload[24..27], payload[27..28], payload[30..32], payload[33..36], payload[36..37], payload[39..41], payload[42..45], payload[45..46] },
        9 => &.{ payload[0..1], payload[3..5], payload[6..9], payload[9..10], payload[12..14], payload[15..18], payload[18..19], payload[21..23], payload[24..27], payload[27..28], payload[30..32], payload[33..36], payload[36..37], payload[39..41], payload[42..45], payload[45..46], payload[48..50] },
        10 => &.{ payload[0..1], payload[3..5], payload[6..9], payload[9..10], payload[12..14], payload[15..18], payload[18..19], payload[21..23], payload[24..27], payload[27..28], payload[30..32], payload[33..36], payload[36..37], payload[39..41], payload[42..45], payload[45..46], payload[48..50], payload[51..54], payload[54..55], payload[57..59], payload[60..63], payload[63..64], payload[66..68], payload[69..72], payload[72..73], payload[75..77], payload[78..81], payload[81..82], payload[84..86], payload[87..90], payload[90..91], payload[93..95] },
        11 => &.{ payload[0..1], payload[3..5], payload[6..9], payload[9..10], payload[12..14], payload[15..18], payload[18..19], payload[21..23], payload[24..27], payload[27..28], payload[30..32], payload[33..36], payload[36..37], payload[39..41], payload[42..45], payload[45..46], payload[48..50], payload[51..54], payload[54..55], payload[57..59], payload[60..63], payload[63..64], payload[66..68], payload[69..72], payload[72..73], payload[75..77], payload[78..81], payload[81..82], payload[84..86], payload[87..90], payload[90..91], payload[93..95], payload[96..99] },
        12 => &.{ payload[0..0], payload[1..4], payload[2..2], payload[3..6], payload[4..4], payload[5..8], payload[6..6], payload[7..10], payload[8..8], payload[9..12], payload[10..10], payload[11..14], payload[12..12], payload[13..16], payload[14..14], payload[15..18] },
        13 => &.{ payload[0..0], payload[1..4], payload[2..2], payload[3..6], payload[4..4], payload[5..8], payload[6..6], payload[7..10], payload[8..8], payload[9..12], payload[10..10], payload[11..14], payload[12..12], payload[13..16], payload[14..14], payload[15..18], payload[16..16] },
        14 => &.{ payload[0..0], payload[1..4], payload[2..2], payload[3..6], payload[4..4], payload[5..8], payload[6..6], payload[7..10], payload[8..8], payload[9..12], payload[10..10], payload[11..14], payload[12..12], payload[13..16], payload[14..14], payload[15..18], payload[16..16], payload[17..20], payload[18..18], payload[19..22], payload[20..20], payload[21..24], payload[22..22], payload[23..26], payload[24..24], payload[25..28], payload[26..26], payload[27..30], payload[28..28], payload[29..32], payload[30..30], payload[31..34], payload[32..32] },
        15 => &.{ payload[0..0], payload[1..1], payload[2..2] },
        16 => &.{ payload[4..5], payload[0..1] },
        17 => &.{ payload[4..5], payload[0..2] },
        18 => &.{ payload[4..4], payload[0..1] },
        19 => &.{ payload[0..32], payload[32..96], payload[16..144] },
        20 => &.{ payload[0..0], payload[0..0], payload[0..0] },
        21 => &.{payload[0..255]},
        else => unreachable,
    };
    return try a.dupe([]const u8, selected);
}
fn record(out: *W, line: []const u8, path: [:0]const u8) !void {
    var split = std.mem.splitScalar(u8, line, '|');
    var f: [10][]const u8 = undefined;
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
    const payload = try a.alloc(u8, 256);
    for (payload, 0..) |*b, i| b.* = @truncate(i * 23 + try number(f[9]));
    const data = try vectors(payload, try number(f[4]));
    observed_payload = payload;
    observed_vectors = data;
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
    const api = try number(f[8]);
    var status: []const u8 = "skip";
    if (api != 1) {
        observed_status = "count";
        const count = W.countSplat(data, try number(f[5]));
        status = try std.fmt.allocPrint(a, "count={d}", .{count});
    }
    try snapshot(out, status, &writer, buffer);
    status = "skip";
    if (api != 0) {
        observed_status = "write";
        const count = writer.writer().writeVec(data) catch |err| blk: {
            status = @errorName(err);
            break :blk 0;
        };
        if (std.mem.eql(u8, status, "skip")) status = try std.fmt.allocPrint(a, "write={d}", .{count});
    }
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
