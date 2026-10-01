const std = @import("std");
const color = @import("src/color.zig");
const Quantizer = @import("src/OctTreeQuantizer.zig");
const allocator = std.heap.page_allocator;

pub fn main() !void {
    try verifyBasic();
    try verifyMerging();
    try verifyColorNormalization();
    try verifyNodes();
    try verifyHash();
    try verifyNormalizationHash();
    std.debug.print("PASS: unchanged locked octree quantizer\n", .{});
}

fn verifyBasic() !void {
    var quantizer = Quantizer.init(allocator);
    defer quantizer.deinit();
    try std.testing.expectError(error.ColorNotFound, quantizer.getPaletteIndex(color.Rgb24.from.rgb(0, 0, 0)));
    const colors = [_]color.Rgb24{ color.Rgb24.from.rgb(255, 0, 0), color.Rgb24.from.rgb(0, 255, 0), color.Rgb24.from.rgb(0, 0, 255) };
    for (colors) |c| try quantizer.addColor(c);
    try std.testing.expectEqual(@as(usize, 3), quantizer.root_node.countLeafNodes());
    var storage: [256]color.Rgba32 = @splat(color.Rgba32.from.rgb(17, 18, 19));
    const palette = quantizer.makePalette(256, &storage);
    try std.testing.expectEqual(@as(usize, 3), palette.len);
    try std.testing.expectEqualSlices(color.Rgba32, &.{ color.Rgba32.from.rgb(0, 0, 255), color.Rgba32.from.rgb(0, 255, 0), color.Rgba32.from.rgb(255, 0, 0) }, palette);
    for (colors, 0..) |c, i| try std.testing.expectEqual(@as(usize, 2 - i), try quantizer.getPaletteIndex(c));
    try std.testing.expectEqual(@as(usize, 0), try quantizer.getPaletteIndex(color.Rgb24.from.rgb(0, 0, 0)));
    try std.testing.expectEqual(color.Rgba32.from.rgb(17, 18, 19), storage[3]);
    palette[0].r = 11;
    try std.testing.expectEqual(@as(u8, 11), storage[0].r);
}

fn verifyMerging() !void {
    // Reduction weights duplicate additions and rounds the average down.
    var quantizer = Quantizer.init(allocator);
    defer quantizer.deinit();
    try quantizer.addColor(color.Rgb24.from.rgb(10, 20, 30));
    try quantizer.addColor(color.Rgb24.from.rgb(11, 21, 31));
    try quantizer.addColor(color.Rgb24.from.rgb(11, 21, 31));
    var storage: [256]color.Rgba32 = undefined;
    const palette = quantizer.makePalette(1, &storage);
    try std.testing.expectEqualSlices(color.Rgba32, &.{color.Rgba32.from.rgb(10, 20, 30)}, palette);
    try std.testing.expectEqual(@as(usize, 0), try quantizer.getPaletteIndex(color.Rgb24.from.rgb(11, 21, 31)));
    var zero = Quantizer.init(allocator);
    defer zero.deinit();
    try zero.addColor(color.Rgb24.from.rgb(128, 64, 32));
    try std.testing.expectEqual(@as(usize, 0), zero.makePalette(0, &storage).len);
    try std.testing.expectEqual(@as(usize, 0), try zero.getPaletteIndex(color.Rgb24.from.rgb(128, 64, 32)));
    var empty = Quantizer.init(allocator);
    defer empty.deinit();
    try std.testing.expectEqual(@as(usize, 0), empty.makePalette(256, &storage).len);
}

fn normalized(c: anytype, expected: color.Rgba32) !void {
    var quantizer = Quantizer.init(allocator);
    defer quantizer.deinit();
    try quantizer.addColor(c);
    var storage: [256]color.Rgba32 = undefined;
    try std.testing.expectEqualSlices(color.Rgba32, &.{expected}, quantizer.makePalette(256, &storage));
    try std.testing.expectEqual(@as(usize, 0), try quantizer.getPaletteIndex(c));
}

fn verifyColorNormalization() !void {
    try normalized(color.Rgba32.from.rgba(101, 151, 201, 128), color.Rgba32.from.rgb(51, 76, 101));
    try normalized(color.Bgra32.from.rgba(101, 151, 201, 128), color.Rgba32.from.rgb(51, 76, 101));
    try normalized(color.Rgba64.from.rgba(32768, 12345, 65535, 32768), color.Rgba32.from.rgb(64, 24, 128));
    try normalized(color.Colorf32.from.rgba(0.5, 0.25, 2, 0.5), color.Rgba32.from.rgb(64, 32, 255));
    try normalized(color.Colorf32.from.rgba(-2, std.math.nan(f32), std.math.inf(f32), 1), color.Rgba32.from.rgb(0, 255, 255));
    try normalized(color.Rgb332.from.rgb(5, 3, 2), color.Rgba32.from.rgb(182, 109, 170));
    try normalized(color.Rgb555.from.rgb(17, 9, 3), color.Rgba32.from.rgb(140, 74, 25));
    try normalized(color.Bgr555.from.rgb(17, 9, 3), color.Rgba32.from.rgb(140, 74, 25));
    try normalized(color.Rgb565.from.rgb(17, 33, 3), color.Rgba32.from.rgb(140, 134, 25));
    try normalized(color.Rgb48.from.rgb(0x1234, 0x5678, 0x9abc), color.Rgba32.from.rgb(0x12, 0x56, 0x9a));
    try normalized(color.Bgr24.from.rgb(1, 2, 3), color.Rgba32.from.rgb(1, 2, 3));
}

fn verifyNodes() !void {
    var quantizer = Quantizer.init(allocator);
    defer quantizer.deinit();
    const first = try quantizer.allocateNode();
    first.init(2, &quantizer);
    const second = try quantizer.allocateNode();
    second.init(2, &quantizer);
    try std.testing.expect(quantizer.levels[2].? == second and second.level_next.? == first);
    const Node = @TypeOf(quantizer.root_node);
    var node = Node{ .red = 0xffffffff, .green = 3, .blue = 5, .reference_count = 1 };
    var low = Node{ .red = 2, .green = 10, .blue = 20, .reference_count = 1 };
    var high = Node{ .red = 3, .green = 20, .blue = 30, .reference_count = 1 };
    node.children[0] = &low;
    node.children[7] = &high;
    try std.testing.expectEqual(@as(i32, 1), node.removeLeaves());
    try std.testing.expectEqual(@as(u32, 4), node.red);
    try std.testing.expectEqual(@as(u32, 33), node.green);
    try std.testing.expectEqual(@as(u32, 55), node.blue);
    try std.testing.expectEqual(@as(u32, 3), node.reference_count);
    try std.testing.expect(node.isLeaf());
    try std.testing.expectEqual(@as(usize, 1), node.countLeafNodes());
    try std.testing.expectEqual(color.Rgba32.from.rgb(1, 11, 18), node.getColor());
    for (node.children) |child| try std.testing.expect(child == null);
    try std.testing.expectEqual(@as(i32, -1), node.removeLeaves());
    const ContextPtr = @typeInfo(@TypeOf(Node.makePalette)).@"fn".params[1].type.?;
    const Context = @typeInfo(ContextPtr).pointer.child;
    var storage: [2]color.Rgba32 = undefined;
    var context = Context{ .palette = &storage, .color_count = 2, .palette_index = 1 };
    node.makePalette(&context);
    try std.testing.expectEqual(@as(u32, 2), context.palette_index);
    try std.testing.expectEqual(@as(u32, 1), node.palette_index);
    try std.testing.expectEqual(color.Rgba32.from.rgb(1, 11, 18), storage[1]);
    try std.testing.expectEqual(@as(usize, 1), try node.getPaletteIndex(color.Rgb24.from.rgb(200, 0, 0), 100));
}

fn hashWord(hash: *u64, value: u64) void {
    var word = value;
    for (0..8) |_| {
        hash.* ^= @as(u8, @truncate(word));
        hash.* *%= 1099511628211;
        word >>= 8;
    }
}

fn hashColor(hash: *u64, c: color.Rgba32) void {
    for ([_]u8{ c.r, c.g, c.b, c.a }) |byte| {
        hash.* ^= byte;
        hash.* *%= 1099511628211;
    }
}

fn verifyHash() !void {
    var hash: u64 = 14695981039346656037;
    var cases: usize = 0;
    for (0..6) |kind| for (0..4) |pattern| for ([_]u32{ 0, 1, 2, 4, 8, 16, 32, 64, 255, 256 }) |count| for ([_]usize{ 0, 1, 2, 3, 8, 17, 63, 129, 257 }) |length| {
        var quantizer = Quantizer.init(allocator);
        defer quantizer.deinit();
        for (0..length) |i| try addCaseColor(&quantizer, kind, pattern, i);
        hashWord(&hash, quantizer.root_node.countLeafNodes());
        var storage: [256]color.Rgba32 = @splat(color.Rgba32.from.rgb(17, 18, 19));
        const palette = quantizer.makePalette(count, &storage);
        hashWord(&hash, palette.len);
        for (palette) |c| hashColor(&hash, c);
        hashWord(&hash, quantizer.root_node.countLeafNodes());
        for (0..length) |i| hashWord(&hash, try findCaseColor(&quantizer, kind, pattern, i));
        if (length > 0) {
            hashWord(&hash, try quantizer.getPaletteIndex(color.Rgb24.from.rgb(31, 63, 95)));
            hashWord(&hash, try quantizer.getPaletteIndex(color.Rgba32.from.rgba(200, 100, 50, 17)));
        }
        cases += 1;
    };
    std.debug.print("Octree: {} cases, hash {x}\n", .{ cases, hash });
    try std.testing.expectEqual(@as(usize, 2160), cases);
    try std.testing.expectEqual(@as(u64, 0xfb25faff7d5b5837), hash);
}

fn sample(pattern: usize, i: usize) color.Rgba32 {
    const value: u32 = switch (pattern) {
        0 => 7,
        1 => @intCast(i),
        2 => @intCast(i * 13),
        3 => @intCast(i / 7 * 17),
        else => unreachable,
    };
    return color.Rgba32.from.rgba(@as(u8, @truncate(value)), @as(u8, @truncate(value * 7)), @as(u8, @truncate(value * 13)), @as(u8, @truncate(i * 31)));
}

fn addCaseColor(q: *Quantizer, kind: usize, pattern: usize, i: usize) !void {
    const c = sample(pattern, i);
    switch (kind) {
        0 => try q.addColor(color.Rgb24.from.rgb(c.r, c.g, c.b)),
        1 => try q.addColor(c),
        2 => try q.addColor(color.Bgra32.from.color(c)),
        3 => try q.addColor(color.Rgba64.from.rgba(@as(u16, c.r) * 257 +| 13, @as(u16, c.g) * 257 +| 17, @as(u16, c.b) * 257 +| 19, @as(u16, c.a) * 257 +| 23)),
        4 => try q.addColor(color.Colorf32.from.rgba(@as(f32, @floatFromInt(c.r)) / 255, @as(f32, @floatFromInt(c.g)) / 255, @as(f32, @floatFromInt(c.b)) / 255, @as(f32, @floatFromInt(c.a)) / 255)),
        5 => try q.addColor(color.Rgb565.from.rgb(@as(u5, @truncate(c.r)), @as(u6, @truncate(c.g)), @as(u5, @truncate(c.b)))),
        else => unreachable,
    }
}

fn findCaseColor(q: *Quantizer, kind: usize, pattern: usize, i: usize) !usize {
    const c = sample(pattern, i);
    return switch (kind) {
        0 => q.getPaletteIndex(color.Rgb24.from.rgb(c.r, c.g, c.b)),
        1 => q.getPaletteIndex(c),
        2 => q.getPaletteIndex(color.Bgra32.from.color(c)),
        3 => q.getPaletteIndex(color.Rgba64.from.rgba(@as(u16, c.r) * 257 +| 13, @as(u16, c.g) * 257 +| 17, @as(u16, c.b) * 257 +| 19, @as(u16, c.a) * 257 +| 23)),
        4 => q.getPaletteIndex(color.Colorf32.from.rgba(@as(f32, @floatFromInt(c.r)) / 255, @as(f32, @floatFromInt(c.g)) / 255, @as(f32, @floatFromInt(c.b)) / 255, @as(f32, @floatFromInt(c.a)) / 255)),
        5 => q.getPaletteIndex(color.Rgb565.from.rgb(@as(u5, @truncate(c.r)), @as(u6, @truncate(c.g)), @as(u5, @truncate(c.b)))),
        else => unreachable,
    };
}

fn normalizedHash(q: *Quantizer, hash: *u64, c: anytype) !void {
    q.root_node.init(8, q);
    try q.root_node.addColor(c, 8, q);
    hashColor(hash, q.root_node.getColor());
}

fn verifyNormalizationHash() !void {
    var quantizer = Quantizer.init(allocator);
    defer quantizer.deinit();
    var hash: u64 = 14695981039346656037;
    var cases: usize = 0;
    for (0..65536) |i| {
        const r: u8 = @truncate(i >> 8);
        const a: u8 = @truncate(i);
        const c = color.Rgba32.from.rgba(r, a, @as(u8, @truncate(i * 13)), a);
        try normalizedHash(&quantizer, &hash, c);
        try normalizedHash(&quantizer, &hash, color.Bgra32.from.color(c));
        try normalizedHash(&quantizer, &hash, color.Rgba64.from.rgba(@as(u16, @truncate(i)), @as(u16, @truncate(i * 13)), @as(u16, @truncate(i * 29)), @as(u16, @truncate(i * 17 + 11))));
        try normalizedHash(&quantizer, &hash, color.Rgb565.from.rgb(@as(u5, @truncate(i >> 11)), @as(u6, @truncate(i >> 5)), @as(u5, @truncate(i))));
        cases += 4;
    }
    for (0..32768) |i| {
        try normalizedHash(&quantizer, &hash, color.Rgb555.from.rgb(@as(u5, @truncate(i >> 10)), @as(u5, @truncate(i >> 5)), @as(u5, @truncate(i))));
        try normalizedHash(&quantizer, &hash, color.Bgr555.from.rgb(@as(u5, @truncate(i)), @as(u5, @truncate(i >> 5)), @as(u5, @truncate(i >> 10))));
        cases += 2;
    }
    for (0..256) |i| {
        try normalizedHash(&quantizer, &hash, color.Rgb332.from.rgb(@as(u3, @truncate(i)), @as(u3, @truncate(i >> 3)), @as(u2, @truncate(i >> 6))));
        cases += 1;
    }
    var random: u32 = 0x12345678;
    for (0..8192) |_| {
        random ^= random << 13;
        random ^= random >> 17;
        random ^= random << 5;
        const r: f32 = @bitCast(random);
        random ^= random << 13;
        random ^= random >> 17;
        random ^= random << 5;
        const g: f32 = @bitCast(random);
        random ^= random << 13;
        random ^= random >> 17;
        random ^= random << 5;
        const b: f32 = @bitCast(random);
        random ^= random << 13;
        random ^= random >> 17;
        random ^= random << 5;
        try normalizedHash(&quantizer, &hash, color.Colorf32.from.rgba(r, g, b, @as(f32, @bitCast(random))));
        cases += 1;
    }
    std.debug.print("Octree normalization: {} colors, hash {x}\n", .{ cases, hash });
    try std.testing.expectEqual(@as(usize, 336128), cases);
    try std.testing.expectEqual(@as(u64, 0x2e3cf0cdc340afc4), hash);
}
