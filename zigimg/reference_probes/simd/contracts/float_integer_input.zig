const simd = @import("src/simd.zig");
pub fn main() void {
    _ = simd.floatToInt(u8, [4]u16{ 1, 2, 3, 4 }, 4);
}
