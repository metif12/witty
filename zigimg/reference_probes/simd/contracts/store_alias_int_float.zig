const simd = @import("src/simd.zig");
const Input = u16;
const Output = f32;
pub fn main() void {
    var dst: [4]Output = .{ 0, 0, 0, 0 };
    simd.store(Output, &dst, [4]Input{ 1, 2, 3, 4 }, 0);
}
