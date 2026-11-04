const std = @import("std");
const W = std.Io.Writer;
const Custom = struct {
    value: i32,
    stop: bool = false,
    pub fn format(value: @This(), writer: *W) W.Error!void {
        try writer.writeAll("custom:");
        if (value.stop) return error.WriteFailed;
        try writer.printInt(value.value, 10, .lower, .{});
    }
};
const Enum = enum {
    zero,
    high,
    pub fn format(value: @This(), writer: *W) W.Error!void {
        try writer.writeAll(@tagName(value));
    }
};
const Sum = union(enum) {
    custom: Custom,
    boolean: bool,
    pub fn format(value: @This(), writer: *W) W.Error!void {
        switch (value) {
            .custom => |v| try v.format(writer),
            .boolean => |v| try writer.writeAll(if (v) "true" else "false"),
        }
    }
};
const Missing = struct {};
const Plain = struct {
    pub fn format(value: @This(), writer: *W) void {
        _ = value;
        writer.writeAll("plain") catch unreachable;
    }
};
pub fn main() !void {
    var backing: [1024]u8 = undefined;
    var w: W = .fixed(&backing);
    _ = &w;
    // BODY
}
