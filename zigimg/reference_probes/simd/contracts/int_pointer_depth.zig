const s = @import("src/simd.zig");
pub fn main() void {
    const n: u16 = 1;
    const p: *const u16 = &n;
    _ = s.intToFloat(f32, &p, 4);
}
