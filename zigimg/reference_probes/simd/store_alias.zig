const std = @import("std");
const s = @import("src/simd.zig");
extern "c" fn printf([*:0]const u8, ...) c_int;
pub fn main() !void {
    var storage: [6]u16 = .{ 1, 2, 3, 4, 5, 6 };
    const argv = try std.process.argsAlloc(std.heap.page_allocator);
    switch (argv[1][0]) {
        'a' => s.store(u16, storage[1..5], storage[0..4].*, 0),
        'v' => s.store(u16, storage[1..5], @as(@Vector(4, u16), storage[0..4].*), 0),
        'l' => {
            const lanes: [4]u16 = storage[0..4].*;
            s.store(u16, storage[1..5], lanes, 0);
        },
        'w' => {
            const lanes: @Vector(4, u16) = storage[0..4].*;
            s.store(u16, storage[1..5], lanes, 0);
        },
        else => unreachable,
    }
    for (storage) |n| {
        _ = printf("%u,", @as(c_uint, n));
    }
    _ = printf("\n");
}
