const std = @import("std");
const simd = @import("src/simd.zig");
extern "c" fn printf([*:0]const u8, ...) c_int;
extern "c" fn fflush(?*anyopaque) c_int;
var destination = [_]u16{ 9, 9, 9, 9 };
pub const panic = std.debug.FullPanic(observe);
fn observe(message: []const u8, address: ?usize) noreturn {
    _ = printf("TRACE:%04x,%04x,%04x,%04x\n", @as(c_uint, destination[0]), @as(c_uint, destination[1]), @as(c_uint, destination[2]), @as(c_uint, destination[3]));
    _ = fflush(null);
    std.debug.defaultPanic(message, address);
}
pub fn main() void {
    simd.store(u16, destination[0..2], @Vector(4, u16){ 1, 2, 3, 4 }, 0);
    _ = printf("UNEXPECTED: store returned\n");
}
