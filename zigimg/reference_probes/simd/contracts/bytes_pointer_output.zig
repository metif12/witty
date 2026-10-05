const s = @import("src/simd.zig");
pub fn main() void {
    _ = s.loadBytes(&([_]u8{0} ** 32), [4]*const u16, 0);
}
