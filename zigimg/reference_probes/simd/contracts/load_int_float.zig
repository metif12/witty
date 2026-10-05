const simd = @import("src/simd.zig");
pub fn main() void {
    _ = simd.load(u16, &.{ 1, 2, 3, 4 }, [4]f32, 0);
}
