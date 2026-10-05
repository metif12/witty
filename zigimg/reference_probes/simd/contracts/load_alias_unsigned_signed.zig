const simd = @import("src/simd.zig");
const Input = u16;
const Output = i16;
pub fn main() void {
    _ = simd.load(Input, &.{ 1, 2, 3, 4 }, [4]Output, 0);
}
