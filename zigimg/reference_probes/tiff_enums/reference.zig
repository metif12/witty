const std = @import("std");
const p = @import("src/formats/tiff.zig");
const io = @import("src/io.zig");
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var observed_codec: ?*p.TIFF = null;
var observed_stream: ?*io.ReadStream = null;
var observed_path: ?[]const u8 = null;
var observed_buffer: []const u8 = &.{};

fn snapshot(out: *W, codec: *p.TIFF, stream: *io.ReadStream, buffer: []const u8) !void {
    const b = &codec.bitmap;
    try out.print("{d}|{d}|{x}|{d}:{d}|{d}:{d}:{d}:{d}|", .{ stream.getPos(), stream.reader().bufferedLen(), buffer, codec.header.version, codec.header.idf_offset, codec.ifd.ifd_offset, codec.ifd.num_tag_entries, codec.ifd.next_ifd_offset, codec.ifd.tags_map.count() });
    var it = codec.ifd.tags_map.iterator();
    while (it.next()) |entry| try out.print("{d}:{d}:{d}:{d},", .{ @intFromEnum(entry.key_ptr.*), entry.value_ptr.data_type, entry.value_ptr.data_count, entry.value_ptr.data_offset });
    try out.print("|{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}|", .{ @intFromEnum(b.compression), b.image_width, b.image_height, b.photometric_interpretation, b.rows_per_strip, b.x_resolution[0], b.x_resolution[1], b.y_resolution[0], b.y_resolution[1], @intFromEnum(b.resolution_unit), b.new_subfile_type, b.samples_per_pixel, b.fill_order, b.planar_configuration, b.predictor, b.bits_per_sample.data.len });
    for (b.bits_per_sample.storage) |v| try out.print("{d},", .{v});
    try out.print("|{d}|", .{b.extra_samples.data.len});
    for (b.extra_samples.storage) |v| try out.print("{d},", .{v});
    try out.print("|{d}|{x}|", .{ b.color_map.data.len, std.mem.sliceAsBytes(&b.color_map.storage) });
    for (b.strip_offsets.?) |v| try out.print("{d},", .{v});
    try out.writeByte('|');
    for (b.strip_byte_counts.?) |v| try out.print("{d},", .{v});
}
fn observe(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var buffer: [8192]u8 = undefined;
            var writer = file.writer(&buffer);
            if (observed_codec) |codec| snapshot(&writer.interface, codec, observed_stream.?, observed_buffer) catch {};
            writer.interface.flush() catch {};
        } else |_| {}
    }
    std.debug.defaultPanic(message, address);
}
fn record(out: *W, line: []const u8, path: []const u8, allocator: std.mem.Allocator) !void {
    var it = std.mem.splitScalar(u8, line, '|');
    const capacity = try std.fmt.parseInt(usize, it.next().?, 10);
    const endian: std.builtin.Endian = if (std.mem.eql(u8, it.next().?, "0")) .little else .big;
    const decode = std.mem.eql(u8, it.next().?, "1");
    const reads = try std.fmt.parseInt(usize, it.next().?, 10);
    const encoded = it.next().?;
    const data = try allocator.alloc(u8, encoded.len / 2);
    _ = try std.fmt.hexToBytes(data, encoded);
    const buffer = try allocator.alloc(u8, capacity);
    @memset(buffer, 165);
    var stream = io.ReadStream.initMemory(data);
    var file: ?std.fs.File = null;
    if (capacity > 0) {
        try std.fs.cwd().writeFile(.{ .sub_path = path, .data = data });
        file = try std.fs.cwd().openFile(path, .{});
        stream = io.ReadStream.initFile(file.?, buffer);
    }
    defer if (file) |f| f.close();
    var codec: p.TIFF = .{ .endianess = endian, .header = .{ .version = 42, .idf_offset = 123 }, .ifd = try p.IFD.init(allocator, &stream, 1), .bitmap = .{
        .compression = .packbits,
        .resolution_unit = .cm,
        .image_width = 17,
        .image_height = 19,
        .photometric_interpretation = 2,
        .rows_per_strip = 7,
        .x_resolution = .{ 23, 29 },
        .y_resolution = .{ 31, 37 },
        .new_subfile_type = 41,
        .samples_per_pixel = 3,
        .fill_order = 2,
        .planar_configuration = 2,
        .predictor = 2,
    } };
    codec.ifd.num_tag_entries = 77;
    codec.ifd.next_ifd_offset = 0x55667788;
    try codec.ifd.tags_map.put(.orientation, .{ .data_type = 4, .data_count = 1, .data_offset = 99 });
    codec.bitmap.strip_offsets = try allocator.dupe(u32, &.{ 11, 22 });
    codec.bitmap.strip_byte_counts = try allocator.dupe(u32, &.{ 33, 44 });
    codec.bitmap.bits_per_sample.resize(8);
    codec.bitmap.extra_samples.resize(8);
    for (0..8) |i| {
        codec.bitmap.bits_per_sample.data[i] = @intCast(100 + i);
        codec.bitmap.extra_samples.data[i] = @intCast(200 + i);
    }
    codec.bitmap.bits_per_sample.resize(3);
    codec.bitmap.extra_samples.resize(2);
    codec.bitmap.color_map.resize(256);
    for (codec.bitmap.color_map.data, 0..) |*v, i| v.* = .{ .r = @truncate(i * 31), .g = @truncate(i * 71), .b = @truncate(i * 47), .a = 99 };
    codec.bitmap.color_map.resize(4);
    if (observed_path != null) {
        observed_codec = &codec;
        observed_stream = &stream;
        observed_buffer = buffer;
    }
    for (0..reads) |_| {
        const status: []const u8 = blk: {
            codec.ifd.readTags(endian) catch |err| break :blk @errorName(err);
            if (decode) codec.decodeBitmap(allocator, &stream) catch |err| break :blk @errorName(err);
            break :blk "ok";
        };
        try out.print("{s}|", .{status});
        try snapshot(out, &codec, &stream, buffer);
        try out.writeByte('~');
    }
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    var buffer: [8192]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&buffer);
    const out = &stdout.interface;
    if (args.len == 4 and std.mem.eql(u8, args[1], "--trap")) {
        observed_path = args[2];
        try record(out, args[3], try std.fmt.allocPrint(a, "{s}.bin", .{args[2]}), a);
        try out.writeByte('\n');
        try out.flush();
        return;
    }
    const input = try std.fs.cwd().readFileAlloc(a, args[1], 64 * 1024 * 1024);
    var lines = std.mem.splitScalar(u8, input, '\n');
    const path = try std.fmt.allocPrint(a, "{s}.zig.bin", .{args[1]});
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var arena = std.heap.ArenaAllocator.init(a);
        defer arena.deinit();
        try record(out, line, path, arena.allocator());
        try out.writeByte('\n');
    }
    try out.flush();
}
