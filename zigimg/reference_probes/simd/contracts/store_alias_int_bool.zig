const s = @import("src/simd.zig");
const Input = u16;
const Output = bool;
pub fn main() void {
    var d: [4]Output = .{ false, false, false, false };
    s.store(Output, &d, [4]Input{ 1, 2, 3, 4 }, 0);
}
