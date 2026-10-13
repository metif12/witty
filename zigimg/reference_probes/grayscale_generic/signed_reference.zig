const std = @import("std");
const c = @import("src/color.zig");
pub fn main() !void {
    var buffer: [4096]u8 = undefined;
    var output = std.fs.File.stdout().writer(&buffer);
    inline for (.{ i8, i16, i32, i64, isize }) |T| {
        const x = c.GrayscaleAlpha(T){ .value = -1 };
        var copy = x;
        copy.alpha = -1;
        try output.interface.print("{d},{d};{d},{d}\n", .{ x.value, x.alpha, copy.value, copy.alpha });
    }
    try output.interface.flush();
}
