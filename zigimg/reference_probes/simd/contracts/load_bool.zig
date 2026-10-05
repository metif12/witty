const simd = @import("src/simd.zig");
pub fn main() void {
    _ = simd.load(bool, &.{ true, false, true, false }, @Vector(4, bool), 0);
}
