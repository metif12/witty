const s = @import("src/simd.zig");
pub fn main() void {
    _ = s.load(u16, &.{ 1, 2, 3, 4 }, [4]*const u16, 0);
}
