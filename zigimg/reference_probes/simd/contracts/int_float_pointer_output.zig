const s = @import("src/simd.zig");
pub fn main() void {
    _ = s.intToFloat(*const u16, &.{ @as(u16, 1), 2, 3, 4 }, 4);
}
