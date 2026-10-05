const s = @import("src/simd.zig");
pub fn main() void {
    _ = s.floatToInt(*const u16, &.{ @as(f32, 1), 2, 3, 4 }, 4);
}
