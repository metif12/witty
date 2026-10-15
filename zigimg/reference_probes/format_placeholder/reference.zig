const std = @import("std");
const cases = @import("cases.zig");
const W = std.Io.Writer;
fn hex(out: *W, bytes: []const u8) !void {
    for (bytes) |byte| try out.print("{x:0>2}", .{byte});
}
fn spec(out: *W, value: std.fmt.Specifier) !void {
    switch (value) {
        .none => try out.writeByte('-'),
        .number => |n| try out.print("n:{d}", .{n}),
        .named => |s| {
            try out.writeAll("s:");
            try hex(out, s);
        },
    }
}
fn state(out: *W, value: std.fmt.Placeholder) !void {
    try hex(out, value.specifier_arg);
    try out.print("|{d}:{d}|", .{ value.fill, @intFromEnum(value.alignment) });
    try spec(out, value.arg);
    try out.writeByte('|');
    try spec(out, value.width);
    try out.writeByte('|');
    try spec(out, value.precision);
}
pub fn main() !void {
    const a = std.heap.page_allocator;
    var out: W.Allocating = .init(a);
    for (cases.inputs, cases.values) |input, value| {
        const data = try a.dupe(u8, input);
        try hex(&out.writer, data);
        try out.writer.writeByte('|');
        try state(&out.writer, value);
        for (data) |*byte| byte.* ^= 0x5a;
        try out.writer.writeByte('~');
        try hex(&out.writer, data);
        try out.writer.writeByte('|');
        try state(&out.writer, value);
        try out.writer.writeByte('\n');
    }
    var stdout = std.fs.File.stdout().writer(&.{});
    try stdout.interface.writeAll(out.written());
}
