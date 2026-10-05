const simd = @import("src/simd.zig");
pub fn main() void {
    var dst = [_]u8{ 0, 0, 0, 0 };
    simd.store(u8, &dst, @Vector(4, u16){ 1, 2, 3, 4 }, 0);
}
