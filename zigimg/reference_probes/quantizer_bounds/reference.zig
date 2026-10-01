const std = @import("std");
const color = @import("src/color.zig");
const Quantizer = @import("src/OctTreeQuantizer.zig");

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    std.debug.assert(args.len == 2);
    var quantizer = Quantizer.init(std.heap.page_allocator);
    var storage: [1]color.Rgba32 = undefined;
    if (std.mem.eql(u8, args[1], "palette_capacity")) {
        try quantizer.addColor(color.Rgb24.from.rgb(255, 0, 0));
        try quantizer.addColor(color.Rgb24.from.rgb(0, 255, 0));
        _ = quantizer.makePalette(2, &storage);
    } else if (std.mem.eql(u8, args[1], "repeated_reduction")) {
        try quantizer.addColor(color.Rgb24.from.rgb(10, 20, 30));
        try quantizer.addColor(color.Rgb24.from.rgb(11, 21, 31));
        _ = quantizer.makePalette(1, &storage);
        _ = quantizer.makePalette(0, &storage);
    } else if (std.mem.eql(u8, args[1], "component_overflow")) {
        quantizer.root_node.red = 0xffffffff;
        try quantizer.root_node.addColor(color.Rgb24.from.rgb(1, 0, 0), 8, &quantizer);
    } else if (std.mem.eql(u8, args[1], "reference_overflow")) {
        quantizer.root_node.reference_count = 0xffffffff;
        try quantizer.root_node.addColor(color.Rgb24.from.rgb(0, 0, 0), 8, &quantizer);
    } else if (std.mem.eql(u8, args[1], "average_cast")) {
        quantizer.root_node.red = 256;
        quantizer.root_node.reference_count = 1;
        _ = quantizer.root_node.getColor();
    } else if (std.mem.eql(u8, args[1], "color_level")) {
        _ = try quantizer.root_node.getPaletteIndex(color.Rgb24.from.rgb(0, 0, 0), 8);
    } else @panic("unknown case");
    std.debug.print("UNEXPECTED: quantizer returned\n", .{});
}
