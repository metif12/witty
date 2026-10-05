const simd = @import("src/simd.zig");
pub fn main() void {
    _ = simd.floatToInt(f32, [4]f32{ 1, 2, 3, 4 }, 4);
}
