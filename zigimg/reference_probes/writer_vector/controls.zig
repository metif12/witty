const std = @import("std");
const W = std.Io.Writer;
const Empty = struct {};
pub fn main() !void {
    var backing: [256]u8 = @splat(0xa5);
    var w: W = .fixed(&backing);
    _ = &w;
    // BODY
}
