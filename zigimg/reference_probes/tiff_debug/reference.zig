const std = @import("std");
const p = @import("src/formats/tiff.zig");
const settings = @import("settings");
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const std_options: std.Options = .{ .log_level = if (settings.enabled) .debug else .info, .logFn = capture };
var messages: [4]?[]u8 = @splat(null);
var message_count: usize = 0;
fn capture(comptime level: std.log.Level, comptime scope: @Type(.enum_literal), comptime format: []const u8, args: anytype) void {
    if (level != .debug or scope != .default) @panic("unexpected log classification");
    messages[message_count] = std.fmt.allocPrint(a, format, args) catch @panic("allocation failed");
    message_count += 1;
}
const H = p.BitmapDescriptor;
const Color = @TypeOf(@as(H, undefined).color_map.storage[0]);
fn numbers(comptime T: type, text: []const u8) ![]T {
    if (text.len == 0) return try a.alloc(T, 0);
    const values = try a.alloc(T, std.mem.count(u8, text, ",") + 1);
    var parts = std.mem.splitScalar(u8, text, ',');
    for (values) |*value| value.* = try std.fmt.parseInt(T, parts.next().?, 10);
    return values;
}
fn optional(text: []const u8) !?[]u32 {
    if (std.mem.eql(u8, text, "n")) return null;
    return try numbers(u32, text[2..]);
}
fn colors(text: []const u8) ![]Color {
    const bytes = try a.alloc(u8, text.len / 2);
    defer a.free(bytes);
    _ = try std.fmt.hexToBytes(bytes, text);
    if (bytes.len % 4 != 0) @panic("malformed colors");
    const result = try a.alloc(Color, bytes.len / 4);
    for (result, 0..) |*c, i| c.* = .{ .r = bytes[i * 4], .g = bytes[i * 4 + 1], .b = bytes[i * 4 + 2], .a = bytes[i * 4 + 3] };
    return result;
}
fn view(text: []const u8) ![2]usize {
    var parts = std.mem.splitScalar(u8, text[2..], ':');
    return .{ try std.fmt.parseInt(usize, parts.next().?, 10), try std.fmt.parseInt(usize, parts.next().?, 10) };
}
fn alias(comptime T: type, data: []const T, storage: []const T) i32 {
    if (data.len == 0) return -2;
    for (storage, 0..) |_, i| {
        if (data.ptr == storage[i..].ptr) return @intCast(i);
    }
    return -1;
}
fn words(comptime T: type, out: *W, values: []const T) !void {
    for (values, 0..) |v, i| {
        if (i != 0) try out.writeByte(',');
        try out.print("{d}", .{v});
    }
}
fn colorWords(out: *W, values: []const Color) !void {
    for (values) |c| {
        for ([_]u8{ c.r, c.g, c.b, c.a }) |v| try out.print("{x:0>2}", .{v});
    }
}
fn optWords(out: *W, value: ?[]u32) !void {
    if (value) |data| {
        try out.writeAll("a:");
        try words(u32, out, data);
    } else {
        try out.writeAll("n");
    }
    try out.writeByte(';');
}
fn state(b: *const H) ![32]u8 {
    var buffer: [32768]u8 = undefined;
    var writer = W.fixed(&buffer);
    const out = &writer;
    try out.print("{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d};", .{ @intFromEnum(b.compression), b.image_width, b.image_height, b.photometric_interpretation, b.rows_per_strip, b.x_resolution[0], b.x_resolution[1], b.y_resolution[0], b.y_resolution[1], @intFromEnum(b.resolution_unit), b.new_subfile_type, b.samples_per_pixel, b.fill_order, b.planar_configuration, b.predictor });
    try optWords(out, b.strip_offsets);
    try optWords(out, b.strip_byte_counts);
    try words(u16, out, b.bits_per_sample.data);
    try out.print("@{d}:", .{alias(u16, b.bits_per_sample.data, &b.bits_per_sample.storage)});
    try words(u16, out, &b.bits_per_sample.storage);
    try out.writeByte(';');
    try words(u16, out, b.extra_samples.data);
    try out.print("@{d}:", .{alias(u16, b.extra_samples.data, &b.extra_samples.storage)});
    try words(u16, out, &b.extra_samples.storage);
    try out.writeByte(';');
    try colorWords(out, b.color_map.data);
    try out.print("@{d}:", .{alias(Color, b.color_map.data, &b.color_map.storage)});
    try colorWords(out, &b.color_map.storage);
    try out.writeByte(';');
    var result: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(writer.buffered(), &result, .{});
    return result;
}
fn row(out: *W, text: []const u8) !void {
    var parts = std.mem.splitScalar(u8, text, '|');
    var f: [16]u32 = undefined;
    for (&f) |*v| v.* = try std.fmt.parseInt(u32, parts.next().?, 10);
    var b = H{ .compression = @enumFromInt(f[1]), .image_width = f[2], .image_height = f[3], .photometric_interpretation = @intCast(f[4]), .rows_per_strip = f[5], .x_resolution = .{ f[6], f[7] }, .y_resolution = .{ f[8], f[9] }, .resolution_unit = @enumFromInt(f[10]), .new_subfile_type = f[11], .samples_per_pixel = @intCast(f[12]), .fill_order = @intCast(f[13]), .planar_configuration = @intCast(f[14]), .predictor = @intCast(f[15]) };
    b.strip_offsets = try optional(parts.next().?);
    defer if (b.strip_offsets) |v| a.free(v);
    b.strip_byte_counts = try optional(parts.next().?);
    defer if (b.strip_byte_counts) |v| a.free(v);
    const bits = try numbers(u16, parts.next().?);
    defer a.free(bits);
    const bits_data = parts.next().?;
    const extra = try numbers(u16, parts.next().?);
    defer a.free(extra);
    const extra_data = parts.next().?;
    const palette = try colors(parts.next().?);
    defer a.free(palette);
    const palette_data = parts.next().?;
    if (bits.len != 8 or extra.len != 8 or palette.len != 256 or parts.next() != null) @panic("malformed row");
    @memcpy(&b.bits_per_sample.storage, bits);
    @memcpy(&b.extra_samples.storage, extra);
    @memcpy(&b.color_map.storage, palette);
    if (bits_data[0] == 'e') {
        b.bits_per_sample.data = try numbers(u16, bits_data[2..]);
    } else {
        const v = try view(bits_data);
        b.bits_per_sample.data = b.bits_per_sample.storage[v[0] .. v[0] + v[1]];
    }
    defer if (bits_data[0] == 'e') a.free(b.bits_per_sample.data);
    if (extra_data[0] == 'e') {
        b.extra_samples.data = try numbers(u16, extra_data[2..]);
    } else {
        const v = try view(extra_data);
        b.extra_samples.data = b.extra_samples.storage[v[0] .. v[0] + v[1]];
    }
    defer if (extra_data[0] == 'e') a.free(b.extra_samples.data);
    if (palette_data[0] == 'e') {
        b.color_map.data = try colors(palette_data[2..]);
    } else {
        const v = try view(palette_data);
        b.color_map.data = b.color_map.storage[v[0] .. v[0] + v[1]];
    }
    defer if (palette_data[0] == 'e') a.free(b.color_map.data);
    message_count = 0;
    const before = try state(&b);
    for (0..f[0]) |_| b.debug();
    const after = try state(&b);
    try out.print("{d}|", .{message_count});
    for (messages[0..message_count]) |message| {
        try out.writeAll("debug:default:");
        for (message.?) |byte| try out.print("{x:0>2}", .{byte});
        try out.writeByte(';');
        a.free(message.?);
    }
    try out.writeByte('|');
    for (before) |byte| try out.print("{x:0>2}", .{byte});
    try out.writeByte('|');
    for (after) |byte| try out.print("{x:0>2}", .{byte});
    try out.writeByte('\n');
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args);
    const text = try std.fs.cwd().readFileAlloc(a, args[1], 32 * 1024 * 1024);
    defer a.free(text);
    var buffer: [8192]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&buffer);
    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    while (lines.next()) |line| try row(&writer.interface, line);
    try writer.interface.flush();
}
