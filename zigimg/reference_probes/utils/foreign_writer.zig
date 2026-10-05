const std = @import("std");
const utils = @import("src/utils.zig");
pub fn main() !void {
    var output = std.Io.Writer.Allocating.init(std.heap.page_allocator);
    defer output.deinit();
    try utils.writeStructForeign(&output.writer, extern struct { value: u32 }{ .value = 1 });
}
