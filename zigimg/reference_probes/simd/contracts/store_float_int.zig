const simd = @import("src/simd.zig");
pub fn main() void {
    var dst: [4]u16 = .{ 0, 0, 0, 0 };
    simd.store(u16, &dst, [4]f32{ 1, 2, 3, 4 }, 0);
}
