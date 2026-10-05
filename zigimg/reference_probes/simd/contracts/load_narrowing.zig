const simd = @import("src/simd.zig");
pub fn main() void {
    _ = simd.load(u16, &.{ 1, 2, 3, 4 }, @Vector(4, u8), 0);
}
