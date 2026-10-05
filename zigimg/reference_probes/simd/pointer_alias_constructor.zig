const simd = @import("src/simd.zig");
const Words = [4]u16;
const Pointer = *const Words;
pub fn main() void {
    const words: Words = .{ 1, 2, 3, 4 };
    const aliased_pointer: Pointer = &words;
    const converted = simd.intToFloat(f32, aliased_pointer, 4);
    if (converted[3] != 4) @panic("UNEXPECTED");
}
