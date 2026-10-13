const std = @import("std");
const io = @import("src/io.zig");
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var observed_reader: ?*io.ReadStream = null;
var observed_writer: ?*io.WriteStream = null;
var observed_buffer: []const u8 = &.{};
var observed_path: ?[]const u8 = null;
var observed_op: usize = 0;
fn snapshot(out: *W, reader: *io.ReadStream, writer: *io.WriteStream, buffer: []const u8, op: usize) !void {
    if (op == 3) {
        try out.print("{x}|{x}", .{ writer.writer().buffered(), buffer });
        return;
    }
    try out.print("{d}|", .{reader.getPos()});
    if (op == 1) try out.writeByte('-') else try out.print("{d}", .{reader.reader().bufferedLen()});
    try out.print("|{x}", .{buffer});
}
fn observe(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var buffer: [8192]u8 = undefined;
            var writer = file.writer(&buffer);
            snapshot(&writer.interface, observed_reader.?, observed_writer.?, observed_buffer, observed_op) catch {};
            writer.interface.flush() catch {};
        } else |_| {}
    }
    std.debug.defaultPanic(message, address);
}
fn record(out: *W, line: []const u8, path: []const u8, allocator: std.mem.Allocator) !void {
    var it = std.mem.splitScalar(u8, line, '|');
    var f: [6][]const u8 = undefined;
    for (&f) |*field| field.* = it.next().?;
    const op = try std.fmt.parseInt(usize, f[0], 10);
    const capacity = try std.fmt.parseInt(i32, f[1], 10);
    const prefill = try std.fmt.parseInt(usize, f[2], 10);
    const consumed = try std.fmt.parseInt(usize, f[3], 10);
    const data = try allocator.alloc(u8, f[5].len / 2);
    _ = try std.fmt.hexToBytes(data, f[5]);
    const buffer = if (capacity < 0) try allocator.dupe(u8, data) else try allocator.alloc(u8, @intCast(capacity));
    if (capacity >= 0) @memset(buffer, 165);
    var reader = io.ReadStream.initMemory(buffer);
    var writer = io.WriteStream.initMemory(buffer);
    var file: ?std.fs.File = null;
    if (capacity >= 0) {
        if (op == 3) {
            file = try std.fs.cwd().createFile(path, .{});
            writer = io.WriteStream.initFile(file.?, buffer);
        } else {
            try std.fs.cwd().writeFile(.{ .sub_path = path, .data = data });
            file = try std.fs.cwd().openFile(path, .{});
            reader = io.ReadStream.initFile(file.?, buffer);
        }
    }
    defer if (file) |value| value.close();
    if (observed_path != null) {
        observed_reader = &reader;
        observed_writer = &writer;
        observed_buffer = buffer;
        observed_op = op;
    }
    if (op == 3) {
        try writer.seekTo(try std.fmt.parseInt(u64, f[4], 10));
        try writer.writer().writeAll(data[0..prefill]);
        try out.print("ok:{d}|", .{writer.getPos()});
    } else {
        if (prefill > 0) _ = reader.reader().peek(prefill) catch |err| {
            try out.print("E{s}|", .{@errorName(err)});
            try snapshot(out, &reader, &writer, buffer, op);
            return;
        };
        _ = reader.reader().take(consumed) catch |err| {
            try out.print("E{s}|", .{@errorName(err)});
            try snapshot(out, &reader, &writer, buffer, op);
            return;
        };
        switch (op) {
            0 => {
                const value = reader.reader().peek(try std.fmt.parseInt(usize, f[4], 10)) catch |err| {
                    try out.print("E{s}|", .{@errorName(err)});
                    try snapshot(out, &reader, &writer, buffer, op);
                    return;
                };
                try out.print("ok:{x}|", .{value});
            },
            1 => {
                reader.reader().toss(try std.fmt.parseInt(usize, f[4], 10));
                try out.writeAll("ok|");
            },
            2 => {
                reader.seekBy(try std.fmt.parseInt(i64, f[4], 10)) catch |err| {
                    try out.print("E{s}|", .{@errorName(err)});
                    try snapshot(out, &reader, &writer, buffer, op);
                    return;
                };
                try out.writeAll("ok|");
            },
            else => unreachable,
        }
    }
    try snapshot(out, &reader, &writer, buffer, op);
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    var buffer: [8192]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&buffer);
    const out = &stdout.interface;
    if (args.len == 4 and std.mem.eql(u8, args[1], "--trap")) {
        observed_path = args[2];
        try record(out, args[3], try std.fmt.allocPrint(a, "{s}.bin", .{args[2]}), a);
        try out.writeByte('\n');
        try out.flush();
        return;
    }
    const input = try std.fs.cwd().readFileAlloc(a, args[1], 64 * 1024 * 1024);
    var lines = std.mem.splitScalar(u8, input, '\n');
    const path = try std.fmt.allocPrint(a, "{s}.zig.bin", .{args[1]});
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var arena = std.heap.ArenaAllocator.init(a);
        defer arena.deinit();
        try record(out, line, path, arena.allocator());
        try out.writeByte('\n');
    }
    try out.flush();
}
