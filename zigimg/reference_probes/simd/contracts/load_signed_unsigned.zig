const simd = @import("src/simd.zig");
pub fn main() void {
    _ = simd.load(i8, &.{ 1, 2, 3, 4 }, [4]u16, 0);
}
