const simd = @import("src/simd.zig");
pub fn main() void {
    var dst: [4]f32 = .{ 0, 0, 0, 0 };
    simd.store(f32, &dst, [4]u16{ 1, 2, 3, 4 }, 0);
}
