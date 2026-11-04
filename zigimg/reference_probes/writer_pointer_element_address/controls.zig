const std = @import("std");
const W = std.Io.Writer;
pub fn main() !void {
    var backing: [4096]u8 = @splat(0xa5);
    var w: W = .fixed(&backing);
    _ = &w;
    // BODY
}
