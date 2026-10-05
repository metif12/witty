const simd = @import("src/simd.zig");
const Input = i8;
const Output = u16;
pub fn main() void {
    _ = simd.load(Input, &.{ 1, 2, 3, 4 }, [4]Output, 0);
}
