const std = @import("std");
const p = @import("src/formats/iff.zig");
const io = @import("src/io.zig");
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_reader: ?*const io.ReadStream = null;
var observed_source: []const u8 = &.{};
var observed_output: []const u8 = &.{};
var observed_backing: []const u8 = &.{};

fn state(out: *W) !void {
    try out.print("{d}|{x}|{x}|{x}", .{observed_reader.?.getPos(), observed_source, observed_output, observed_backing});
}
fn observe(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var bytes: [4096]u8 = undefined;
            var writer = file.writer(&bytes);
            state(&writer.interface) catch {};
            writer.interface.flush() catch {};
        } else |_| {}
    }
    std.debug.defaultPanic(message, address);
}
fn num(f: [14][]const u8, index: usize) !usize {
    return std.fmt.parseInt(usize, f[index], 10);
}
fn decode(text: []const u8) ![]u8 {
    const bytes = try a.alloc(u8, text.len / 2);
    _ = try std.fmt.hexToBytes(bytes, text);
    return bytes;
}
fn lineCase(line: []const u8, out: *W) !void {
    var parts = std.mem.splitScalar(u8, line, '|');
    var f: [14][]const u8 = undefined;
    for (&f) |*field| field.* = parts.next().?;
    const source_owned = try decode(f[9]);
    defer a.free(source_owned);
    const output_owned = try decode(f[10]);
    defer a.free(output_owned);
    const backing = if (std.mem.eql(u8, f[11], "-")) try a.alloc(u8, 0) else try decode(f[11]);
    defer a.free(backing);
    var source = source_owned;
    var output = output_owned;
    if (!std.mem.eql(u8, f[11], "-")) {
        const source_offset = try num(f, 12);
        const output_offset = try num(f, 13);
        source = backing[source_offset..][0..source.len];
        output = backing[output_offset..][0..output.len];
    }
    var codec = p.IFF{
        .format_id = @enumFromInt(try num(f, 2)),
        .header = if ((try num(f, 1)) == 0) .{.bmhd = .{
            .width = @intCast(try num(f, 3)), .height = @intCast(try num(f, 4)),
            .planes = @intCast(try num(f, 5)), .compression_type = @enumFromInt(try num(f, 6)),
        }} else .{.dgbl = .{.width = @intCast(try num(f, 3)), .height = @intCast(try num(f, 4))}},
        .pitch = @intCast(try num(f, 7)),
    };
    var reader = io.ReadStream.initMemory(source);
    const start = try num(f, 8);
    if (start > 0) _ = try reader.reader().take(start);
    observed_reader = &reader;
    observed_source = source;
    observed_output = output;
    observed_backing = backing;
    const result = if ((try num(f, 0)) == 0) codec.planarToChunky(source, output) else codec.decodeByteRun2(&reader, output, a);
    result catch |err| {
        try out.print("{s}|", .{@errorName(err)});
        try state(out);
        try out.writeByte('\n');
        return;
    };
    try out.writeAll("ok|");
    try state(out);
    try out.writeByte('\n');
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args);
    var bytes: [8192]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&bytes);
    const out = &writer.interface;
    if (std.mem.eql(u8, args[1], "--corpus")) {
        const text = try std.fs.cwd().readFileAlloc(a, args[2], 1073741824);
        defer a.free(text);
        var lines = std.mem.splitScalar(u8, text, '\n');
        while (lines.next()) |line| {
            if (line.len > 0) try lineCase(line, out);
        }
    } else {
        observed_path = args[2];
        try lineCase(args[3], out);
    }
    try out.flush();
}
