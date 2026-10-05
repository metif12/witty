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
    } else if (std.mem.eql(u8, args[1], "green_overflow")) {
        quantizer.root_node.green = 0xffffffff;
        try quantizer.root_node.addColor(color.Rgb24.from.rgb(0, 1, 0), 8, &quantizer);
    } else if (std.mem.eql(u8, args[1], "blue_overflow")) {
        quantizer.root_node.blue = 0xffffffff;
        try quantizer.root_node.addColor(color.Rgb24.from.rgb(0, 0, 1), 8, &quantizer);
    } else if (std.mem.eql(u8, args[1], "reference_overflow")) {
        quantizer.root_node.reference_count = 0xffffffff;
        try quantizer.root_node.addColor(color.Rgb24.from.rgb(0, 0, 0), 8, &quantizer);
    } else if (std.mem.eql(u8, args[1], "average_cast")) {
        quantizer.root_node.red = 256;
        quantizer.root_node.reference_count = 1;
        _ = quantizer.root_node.getColor();
    } else if (std.mem.eql(u8, args[1], "green_average_cast")) {
        quantizer.root_node.green = 256;
        quantizer.root_node.reference_count = 1;
        _ = quantizer.root_node.getColor();
    } else if (std.mem.eql(u8, args[1], "blue_average_cast")) {
        quantizer.root_node.blue = 256;
        quantizer.root_node.reference_count = 1;
        _ = quantizer.root_node.getColor();
    } else if (std.mem.eql(u8, args[1], "zero_average")) {
        _ = quantizer.root_node.getColor();
    } else if (std.mem.eql(u8, args[1], "color_level")) {
        _ = quantizer.root_node.getPaletteIndex(color.Rgb24.from.rgb(0, 0, 0), 8) catch |err| {
            std.debug.print("UNEXPECTED: returned error {s}\n", .{@errorName(err)});
            return;
        };
    } else if (std.mem.eql(u8, args[1], "negative_color_level")) {
        _ = quantizer.root_node.getPaletteIndex(color.Rgb24.from.rgb(0, 0, 0), -1) catch |err| {
            std.debug.print("UNEXPECTED: returned error {s}\n", .{@errorName(err)});
            return;
        };
    } else if (std.mem.eql(u8, args[1], "negative_level")) {
        const node = try quantizer.allocateNode();
        quantizer.addLevelNode(-1, node);
    } else if (std.mem.eql(u8, args[1], "high_level")) {
        const node = try quantizer.allocateNode();
        quantizer.addLevelNode(8, node);
    } else if (std.mem.eql(u8, args[1], "leaf_count_underflow")) {
        const node = try quantizer.allocateNode();
        node.* = .{};
        node.children[0] = try quantizer.allocateNode();
        node.children[0].?.* = .{};
        node.children[1] = try quantizer.allocateNode();
        node.children[1].?.* = .{};
        quantizer.levels[7] = node;
        _ = quantizer.makePalette(0, &storage);
    } else if (std.mem.eql(u8, args[1], "palette_context_capacity")) {
        const Node = @TypeOf(quantizer.root_node);
        const ContextPtr = @typeInfo(@TypeOf(Node.makePalette)).@"fn".params[1].type.?;
        const Context = @typeInfo(ContextPtr).pointer.child;
        quantizer.root_node.reference_count = 1;
        var context = Context{ .palette = &storage, .palette_index = 1, .color_count = 2 };
        quantizer.root_node.makePalette(&context);
    } else @panic("unknown case");
    std.debug.print("UNEXPECTED: quantizer returned\n", .{});
}
