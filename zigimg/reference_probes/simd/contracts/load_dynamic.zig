const simd = @import("src/simd.zig");
pub fn main() void {
    _ = simd.load(u8, &.{ 1, 2, 3, 4 }, []u8, 0);
}
