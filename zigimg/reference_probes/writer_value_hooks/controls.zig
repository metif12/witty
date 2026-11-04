const std = @import("std");
const W = std.Io.Writer;
const Num = struct {
    pub fn formatNumber(_: @This(), w: *W, _: std.fmt.Number) W.Error!void {
        try w.writeAll("N");
    }
};
const BytesHook = struct {
    pub fn formatByteSize(_: @This(), w: *W, _: W.ByteSizeUnits) W.Error!void {
        try w.writeAll("B");
    }
};
const DurationHook = struct {
    pub fn formatDuration(_: @This(), w: *W) W.Error!void {
        try w.writeAll("D");
    }
};
const Args = struct { value: Num };
const Empty = struct {};
const Nonfallible = struct {
    pub fn formatNumber(_: @This(), _: *W, _: std.fmt.Number) void {}
    pub fn formatByteSize(_: @This(), _: *W, _: W.ByteSizeUnits) void {}
    pub fn formatDuration(_: @This(), _: *W) void {}
};
const WrongNumber = struct {
    pub fn formatNumber(_: @This(), _: *W, _: std.fmt.Options) W.Error!void {}
};
const WrongBytes = struct {
    pub fn formatByteSize(_: @This(), _: *W, _: bool) W.Error!void {}
};
const WrongDuration = struct {
    pub fn formatDuration(_: @This(), _: *W, _: bool) W.Error!void {}
};
const Named = enum {
    zero,
    one,
    pub fn formatNumber(_: @This(), w: *W, _: std.fmt.Number) W.Error!void {
        try w.writeAll("unexpected");
    }
};
pub fn main() !void {
    var backing: [128]u8 = @splat(0xa5);
    var w: W = .fixed(&backing);
    _ = &w;
    // BODY
}
