const std = @import("std");
const I = @import("src/ImageUnmanaged.zig");
const M = @import("src/Image.zig");
const color = @import("src/color.zig");
const Format = @import("src/pixel_format.zig").PixelFormat;
const W = std.Io.Writer;
fn palette(alloc: std.mem.Allocator, n: usize, seed: usize) ![]color.Rgba32 {
    const result = try alloc.alloc(color.Rgba32, n);
    for (result, 0..) |*entry, i| entry.* = .{ .r = @intCast((seed + i * 17) & 255), .g = @intCast((seed + i * 31) & 255), .b = @intCast((seed + i * 47) & 255), .a = 255 };
    return result;
}
fn pixels(alloc: std.mem.Allocator, format: Format, n: usize, seed: usize) !color.PixelStorage {
    return switch (format) {
        .indexed1 => blk: {
            const indices = try alloc.alloc(u1, n);
            for (indices, 0..) |*value, i| value.* = @intCast(i % 2);
            break :blk .{ .indexed1 = .{ .indices = indices, .palette = try palette(alloc, 2, seed) } };
        },
        .indexed2 => blk: {
            const indices = try alloc.alloc(u2, n);
            for (indices, 0..) |*value, i| value.* = @intCast(i % 4);
            break :blk .{ .indexed2 = .{ .indices = indices, .palette = try palette(alloc, 3, seed) } };
        },
        .indexed4 => blk: {
            const indices = try alloc.alloc(u4, n);
            for (indices, 0..) |*value, i| value.* = @intCast(i % 16);
            break :blk .{ .indexed4 = .{ .indices = indices, .palette = try palette(alloc, 3, seed) } };
        },
        .indexed8 => blk: {
            const indices = try alloc.alloc(u8, n);
            for (indices, 0..) |*value, i| value.* = @intCast(i % 256);
            break :blk .{ .indexed8 = .{ .indices = indices, .palette = try palette(alloc, 3, seed) } };
        },
        .indexed16 => blk: {
            const indices = try alloc.alloc(u16, n);
            for (indices, 0..) |*value, i| value.* = @intCast(i % 65536);
            break :blk .{ .indexed16 = .{ .indices = indices, .palette = try palette(alloc, 3, seed) } };
        },
        else => {
            var result = try color.PixelStorage.init(alloc, format, n);
            for (result.asBytes(), 0..) |*byte, i| byte.* = @intCast((i * 37 + seed) & 255);
            switch (result) {
                .grayscale1 => |values| for (values, 0..) |*value, i| {
                    value.value = @intCast(i % 2);
                },
                .grayscale2 => |values| for (values, 0..) |*value, i| {
                    value.value = @intCast(i % 4);
                },
                .grayscale4 => |values| for (values, 0..) |*value, i| {
                    value.value = @intCast(i % 16);
                },
                else => {},
            }
            return result;
        },
    };
}
fn mutate(storage: *color.PixelStorage) void {
    const bytes = storage.asBytes();
    if (bytes.len > 0) {
        const mask: u8 = switch (storage.*) {
            .indexed1, .grayscale1 => 1,
            .indexed2, .grayscale2 => 3,
            .indexed4, .grayscale4 => 15,
            else => 85,
        };
        bytes[0] ^= mask;
    }
    if (storage.getPalette()) |entries| {
        if (entries.len > 0) entries[0].r ^= 85;
    }
}
fn pixelState(out: *W, storage: color.PixelStorage) !void {
    try out.print("{d}:{d}:{x}:", .{ @intFromEnum(storage), storage.len(), storage.asBytes() });
    if (storage.getPalette()) |entries| {
        try out.print("{x}", .{std.mem.sliceAsBytes(entries)});
    } else {
        try out.writeByte('-');
    }
}
fn frameState(out: *W, frame: I.AnimationFrame) !void {
    try out.print("{d}:", .{@as(u32, @bitCast(frame.duration))});
    try pixelState(out, frame.pixels);
}
fn animationState(out: *W, animation: I.Animation) !void {
    try out.print("{d}:{d}", .{ animation.loop_count, animation.frames.items.len });
    for (animation.frames.items) |frame| {
        try out.writeByte('|');
        try frameState(out, frame);
    }
}
fn imageState(out: *W, img: I) !void {
    try out.print("{d}:{d}:{d}:", .{ img.width, img.height, @intFromBool(img.isAnimation()) });
    try pixelState(out, img.pixels);
    try out.writeByte('|');
    try animationState(out, img.animation);
}
fn number(text: []const u8) !u32 {
    return std.fmt.parseInt(u32, text, 10);
}
fn lineCase(line: []const u8, out: *W) !void {
    var parts = std.mem.splitScalar(u8, line, '|');
    var f: [7][]const u8 = undefined;
    for (&f) |*field| field.* = parts.next().?;
    const op = try number(f[0]);
    const format: Format = @enumFromInt(try number(f[1]));
    const n = try number(f[2]);
    const word = try number(f[3]);
    const count = try number(f[4]);
    const loops = try std.fmt.parseInt(i32, f[5], 10);
    const seed = try number(f[6]);
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    var frame = I.AnimationFrame{ .pixels = try pixels(alloc, format, n, seed), .duration = @bitCast(word) };
    var copy = frame;
    var storage: [3]I.AnimationFrame = undefined;
    for (&storage, 0..) |*entry, i| entry.* = .{ .pixels = try pixels(alloc, format, n, seed + i), .duration = @bitCast(word ^ @as(u32, @intCast(i))) };
    const animation = I.Animation{ .loop_count = loops, .frames = .{ .items = storage[0..count], .capacity = 3 } };
    switch (op) {
        0 => {
            try frameState(out, frame);
            try out.writeByte('|');
            try animationState(out, .{});
            const managed = M.init(alloc);
            try out.print("|{d}:{d}", .{ @intFromBool((I{}).isAnimation()), @intFromBool(managed.isAnimation()) });
        },
        1 => {
            copy.duration = @bitCast(word ^ 0x80000000);
            mutate(&copy.pixels);
            try frameState(out, frame);
            try out.writeByte('|');
            try frameState(out, copy);
        },
        2 => {
            copy.pixels = try pixels(alloc, .rgba32, 2, seed + 9);
            frame.duration = @bitCast(word ^ 0x55555555);
            try frameState(out, frame);
            try out.writeByte('|');
            try frameState(out, copy);
        },
        3 => {
            var other = animation;
            other.loop_count = ~loops;
            if (count > 0) {
                other.frames.items[0].duration = @bitCast(word ^ 0x80000000);
                other.frames.items[0].pixels = try pixels(alloc, .rgb24, 1, seed + 9);
            }
            try animationState(out, animation);
            try out.writeAll("||");
            try animationState(out, other);
        },
        4 => {
            var other = animation;
            other.frames.items = other.frames.items[0..if (count > 0) count - 1 else 0];
            if (count > 1) other.frames.items[0].duration = @bitCast(word ^ 0x80000000);
            try animationState(out, animation);
            try out.writeAll("||");
            try animationState(out, other);
        },
        5 => {
            var other = animation;
            var replacement = [_]I.AnimationFrame{copy};
            other.frames = .{ .items = &replacement, .capacity = 1 };
            other.loop_count = ~loops;
            other.frames.items[0].duration = @bitCast(word ^ 0x80000000);
            try animationState(out, animation);
            try out.writeAll("||");
            try animationState(out, other);
        },
        6 => {
            const original = I{ .width = 17, .height = 19, .pixels = frame.pixels, .animation = animation };
            var view = original.toManaged(alloc);
            view.width = 23;
            view.animation.loop_count = ~loops;
            view.pixels = view.pixels.slice(0, @min(view.pixels.len(), 1));
            mutate(&view.pixels);
            if (count > 0) view.animation.frames.items[0].duration = @bitCast(word ^ 0x80000000);
            try imageState(out, original);
            try out.writeAll("||");
            try imageState(out, view.toUnmanaged());
        },
        7 => {
            var original = M.init(alloc);
            original.width = 17;
            original.height = 19;
            original.pixels = frame.pixels;
            original.animation = animation;
            var view = original.toUnmanaged();
            view.height = 29;
            view.animation.loop_count = ~loops;
            view.pixels = view.pixels.slice(0, @min(view.pixels.len(), 1));
            mutate(&view.pixels);
            if (count > 0) view.animation.frames.items[0].pixels = try pixels(alloc, .rgba32, 1, seed + 9);
            try imageState(out, original.toUnmanaged());
            try out.writeAll("||");
            try imageState(out, view);
        },
        else => unreachable,
    }
    try out.writeByte('\n');
}
fn boxed(format: Format, out: *W) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    var frame = I.AnimationFrame{ .pixels = try pixels(alloc, format, 3, 7), .duration = 0.5 };
    const copy = frame;
    switch (frame.pixels) {
        inline .indexed1, .indexed2, .indexed4, .indexed8, .indexed16 => |*value| value.resizePalette(1),
        else => unreachable,
    }
    try out.print("{d}:{d}:{d}:{d}\n", .{ frame.pixels.getPalette().?.len, copy.pixels.getPalette().?.len, frame.pixels.len(), copy.pixels.len() });
}
pub fn main() !void {
    const alloc = std.heap.page_allocator;
    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);
    var buffer: [8192]u8 = undefined;
    var out = std.fs.File.stdout().writer(&buffer);
    if (std.mem.eql(u8, args[1], "--boxed")) {
        try boxed(@enumFromInt(try number(args[2])), &out.interface);
    } else {
        const text = try std.fs.cwd().readFileAlloc(alloc, args[2], 1073741824);
        defer alloc.free(text);
        var lines = std.mem.splitScalar(u8, text, '\n');
        while (lines.next()) |line| {
            if (line.len > 0) try lineCase(line, &out.interface);
        }
    }
    try out.interface.flush();
}
