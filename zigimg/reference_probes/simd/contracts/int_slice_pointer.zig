const s = @import("src/simd.zig");
pub fn main() void {
    const slice: []const u16 = &.{ 1, 2, 3, 4 };
    _ = s.intToFloat(f32, &slice, 4);
}
