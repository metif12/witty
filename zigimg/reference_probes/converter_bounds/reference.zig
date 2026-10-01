const std = @import("std");
const color = @import("src/color.zig");
const Converter = @import("src/PixelFormatConverter.zig");
const PixelFormat = @import("src/pixel_format.zig").PixelFormat;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    std.debug.assert(args.len == 2);
    const name = args[1];
    var source: color.PixelStorage = .{ .invalid = {} };
    var destination: PixelFormat = .rgb24;
    if (std.mem.startsWith(u8, name, "bgr_")) {
        source = try color.PixelStorage.init(allocator, .bgr555, 1);
        source.bgr555[0] = color.Bgr555.from.rgb(1, 0, 0);
        destination = std.meta.stringToEnum(PixelFormat, name[4..]).?;
    } else if (std.mem.eql(u8, name, "empty_raw_float")) {
        var bytes: [1]u8 align(4) = .{0};
        source = try color.PixelStorage.initRawPixels(bytes[0..0], .float32);
        _ = try Converter.convert(allocator, &source, .rgba32);
        std.debug.print("UNEXPECTED: converter returned\n", .{});
        return;
    } else if (std.mem.startsWith(u8, name, "empty_")) {
        const format: PixelFormat = if (std.mem.eql(u8, name, "empty_rgba32")) .rgba32 else if (std.mem.eql(u8, name, "empty_bgra32")) .bgra32 else .float32;
        source = try color.PixelStorage.init(allocator, format, 0);
        destination = if (format != .float32) .float32 else if (std.mem.eql(u8, name, "empty_float_rgba")) .rgba32 else .bgra32;
    } else if (std.mem.eql(u8, name, "unaligned_float")) {
        var bytes: [17]u8 align(4) = @splat(0);
        source = try color.PixelStorage.initRawPixels(bytes[1..], .float32);
        destination = .rgba32;
        _ = try Converter.convert(allocator, &source, destination);
        std.debug.print("UNEXPECTED: converter returned\n", .{});
        return;
    } else if (std.mem.eql(u8, name, "palette_index")) {
        source = .{ .indexed8 = try color.IndexedStorage8.initPaletteSize(allocator, 1, 1) };
        source.indexed8.indices[0] = 1;
    } else if (std.mem.startsWith(u8, name, "float_")) {
        const value: f32 = if (std.mem.eql(u8, name, "float_negative")) -1 else if (std.mem.eql(u8, name, "float_large")) 2 else if (std.mem.eql(u8, name, "float_nan")) std.math.nan(f32) else if (std.mem.eql(u8, name, "float_infinity")) std.math.inf(f32) else @panic("unknown case");
        source = try color.PixelStorage.init(allocator, .float32, 4);
        @memset(source.float32, .{ .r = value });
        destination = .rgba32;
    } else @panic("unknown case");
    const result = try Converter.convert(allocator, &source, destination);
    if (std.mem.eql(u8, name, "float_nan")) {
        for (result.rgba32) |entry| try std.testing.expectEqual(@as(u8, 0), entry.r);
        std.debug.print("PASS: pinned ARM64 NaN prefix converts to zero\n", .{});
        return;
    }
    std.debug.print("UNEXPECTED: converter returned\n", .{});
}
