const std = @import("std");
const p = @import("src/formats/gif.zig");
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var observed_codec: ?*const p.GIF = null;
var observed_path: ?[]const u8 = null;

fn infoText(out: *W, info: p.ApplicationExtension) !void {
    try out.print("{x}{x}:{x}", .{ info.application_identifier, info.authentification_code, info.data });
}
fn snapshot(out: *W, codec: *const p.GIF) !void {
    try out.print("{d}|", .{codec.application_infos.items.len});
    for (codec.application_infos.items) |info| {
        try infoText(out, info);
        try out.writeByte(';');
    }
}
fn observe(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var buffer: [8192]u8 = undefined;
            var writer = file.writer(&buffer);
            snapshot(&writer.interface, observed_codec.?) catch {};
            writer.interface.flush() catch {};
        } else |_| {}
    }
    std.debug.defaultPanic(message, address);
}
fn record(line: []const u8, out: *W) !void {
    var fields = std.mem.splitScalar(u8, line, '|');
    const op = try std.fmt.parseInt(u8, fields.next().?, 10);
    const index = try std.fmt.parseInt(usize, fields.next().?, 10);
    var codec = p.GIF.init(a);
    defer codec.deinit();
    defer {
        for (codec.application_infos.items) |info| a.free(info.data);
        codec.application_infos.deinit(a);
    }
    var infos = std.mem.splitScalar(u8, fields.next().?, ';');
    while (infos.next()) |text| {
        if (text.len == 0) continue;
        const raw = try a.alloc(u8, text.len / 2);
        defer a.free(raw);
        _ = try std.fmt.hexToBytes(raw, text);
        try codec.application_infos.append(a, .{
            .application_identifier = raw[0..8].*,
            .authentification_code = raw[8..11].*,
            .data = try a.dupe(u8, raw[11..]),
        });
    }
    observed_codec = &codec;
    try out.print("{d}|", .{codec.loopCount()});
    if (op == 1) {
        const data = codec.application_infos.items[index].data;
        data[0] ^= 85;
        try out.print("{d}|", .{codec.loopCount()});
        data[1] ^= 51;
        data[2] ^= 119;
        try out.print("{d}|", .{codec.loopCount()});
    } else if (op == 2) {
        var copy = codec.application_infos.items[index];
        copy.application_identifier[0] ^= 85;
        copy.authentification_code[0] ^= 51;
        copy.data[1] ^= 51;
        try out.print("{d}|", .{codec.loopCount()});
        try infoText(out, copy);
        try out.writeByte('|');
    }
    try snapshot(out, &codec);
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args);
    var buffer: [8192]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&buffer);
    const out = &writer.interface;
    if (std.mem.eql(u8, args[1], "--trap")) {
        observed_path = args[2];
        try record(args[3], out);
        try out.writeByte('\n');
    } else {
        const text = try std.fs.cwd().readFileAlloc(a, args[1], 1073741824);
        defer a.free(text);
        var lines = std.mem.splitScalar(u8, text, '\n');
        while (lines.next()) |line| {
            if (line.len == 0) continue;
            try record(line, out);
            try out.writeByte('\n');
        }
    }
    try out.flush();
}
