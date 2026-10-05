const simd = @import("src/simd.zig");
const Input = f32;
const Output = u16;
pub fn main() void {
    var dst: [4]Output = .{ 0, 0, 0, 0 };
    simd.store(Output, &dst, [4]Input{ 1, 2, 3, 4 }, 0);
}
