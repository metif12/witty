const std = @import("std");
const p = @import("src/formats/tga.zig");
const Image = @import("src/ImageUnmanaged.zig");
const color = @import("src/color.zig");
const Format = @import("src/pixel_format.zig").PixelFormat;
const io = @import("src/io.zig");
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_codec: ?*const p.TGA = null;
var observed_writer: ?*io.WriteStream = null;
var observed_image: ?*const Image = null;
var observed_buffer: []const u8 = &.{};
var observed_disk: ?[]const u8 = null;

fn snapshot(out: *W) !void {
    const writer = observed_writer.?;
    try out.print("{d}:{d}|{x}|", .{ writer.getPos(), writer.writer().buffered().len, observed_buffer });
    if (observed_codec) |codec| try out.print("{x}:{x}:{s}", .{ std.mem.asBytes(&codec.header), codec.id.data, if (codec.extension != null) "true" else "false" }) else try out.writeByte('-');
    const image = observed_image.?;
    try out.print("|{d}:{d}:{d}:{d}:{x}|", .{ image.width, image.height, @intFromEnum(std.meta.activeTag(image.pixels)), image.pixels.len(), image.pixels.asBytes() });
    if (image.pixels.getPalette()) |pal| try out.print("{x}", .{std.mem.sliceAsBytes(pal)}) else try out.writeByte('-');
    try out.writeByte('|');
    if (observed_disk) |path| {
        const data = try std.fs.cwd().readFileAlloc(a, path, 65536);
        defer a.free(data);
        try out.print("{x}", .{data});
    } else try out.writeByte('-');
}
fn observe(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var buffer: [8192]u8 = undefined;
            var writer = file.writer(&buffer);
            snapshot(&writer.interface) catch {};
            writer.interface.flush() catch {};
        } else |_| {}
    }
    std.debug.defaultPanic(message, address);
}
fn number(comptime T: type, value: []const u8) !T {
    return std.fmt.parseInt(T, value, 10);
}
fn record(line: []const u8, path: []const u8, out: *W) !void {
    var f: [16][]const u8 = undefined;
    var it = std.mem.splitScalar(u8, line, '|');
    for (&f) |*field| field.* = it.next().?;
    const cap = try number(i32, f[0]);
    const op = try number(u8, f[1]);
    const width = try number(usize, f[2]);
    const height = try number(usize, f[3]);
    const format: Format = @enumFromInt(try number(u32, f[4]));
    var pixels = try color.PixelStorage.init(a, format, try number(usize, f[5]));
    defer pixels.deinit(a);
    const seed = try number(u8, f[6]);
    const stride: usize = if (pixels.asBytes().len > 0) format.pixelStride() else 1;
    for (pixels.asBytes(), 0..) |*byte, i| {
        const value: usize = switch (seed) {
            0 => 7,
            1 => (i / stride) / 17,
            2 => (i / stride) * 13,
            else => (i / stride) / 16 * 3,
        };
        byte.* = @truncate(value + (i % stride) * 5);
        if ((format == .rgb555 or format == .bgr555) and i % 2 == 1) byte.* &= 127;
    }
    if (pixels.getPalette()) |pal| {
        const length = @min(try number(usize, f[7]), pal.len);
        pixels.resizePalette(length);
        for (pal[0..length], 0..) |*entry, i| entry.* = .{ .r = @truncate(i * 31), .g = @truncate(i * 71), .b = @truncate(i * 113), .a = @truncate(i * 47) };
    }
    const image = Image{ .width = width, .height = height, .pixels = pixels };
    observed_image = &image;
    const id = try a.alloc(u8, try number(usize, f[13]));
    defer a.free(id);
    @memset(id, 'i');
    const meta = try number(u8, f[14]);
    const options = p.TGA.EncoderOptions{
        .rle_compressed = std.mem.eql(u8, f[10], "1"),
        .top_to_bottom_image = std.mem.eql(u8, f[11], "1"),
        .color_map_depth = try number(u8, f[12]),
        .image_id = id,
        .author_name = if (meta == 1) "author" else if (meta == 2) "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" else "",
        .job_id = if (meta == 1) "job" else if (meta == 3) "jjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjj" else "",
        .software_id = if (meta == 1) "V" else if (meta == 4) "ssssssssssssssssssssssssssssssssssssssss" else "",
        .timestamp = .{ .year = 2026 },
        .software_version = .{ .number = 123, .letter = 'b' },
    };
    var codec = p.TGA{ .header = .{ .id_length = @truncate(id.len), .image_spec = .{ .width = @truncate(width), .height = @truncate(height), .origin_x = 37, .origin_y = 11 } } };
    codec.header.image_type.run_length = options.rle_compressed;
    codec.header.image_spec.descriptor.top_to_bottom = options.top_to_bottom_image;
    switch (format) {
        .grayscale8 => {
            codec.header.image_type.indexed = true;
            codec.header.image_type.truecolor = true;
            codec.header.image_spec.bit_per_pixel = 8;
        },
        .indexed8 => {
            codec.header.image_type.indexed = true;
            codec.header.has_color_map = 1;
            codec.header.image_spec.bit_per_pixel = 8;
            codec.header.color_map_spec.length = @intCast(pixels.indexed8.palette.len);
            codec.header.color_map_spec.bit_depth = options.color_map_depth;
        },
        .rgb555 => {
            codec.header.image_type.truecolor = true;
            codec.header.image_spec.bit_per_pixel = 16;
        },
        .rgb24, .bgr24 => {
            codec.header.image_type.truecolor = true;
            codec.header.image_spec.bit_per_pixel = 24;
        },
        .rgba32, .bgra32 => {
            codec.header.image_type.truecolor = true;
            codec.header.image_spec.bit_per_pixel = 32;
            codec.header.image_spec.descriptor.num_attributes_bit = 8;
        },
        else => {},
    }
    if (op == 0) {
        codec.id.resize(id.len);
        @memcpy(codec.id.data, id);
        if (!std.mem.eql(u8, f[15], "5")) codec.extension = .{ .timestamp = options.timestamp, .software_version = options.software_version };
        switch (try number(u8, f[15])) {
            1 => codec.header.color_map_spec.first_entry_index = 1,
            2 => {
                codec.header.color_map_spec.first_entry_index = 1;
                codec.header.color_map_spec.length = 65535;
            },
            3 => codec.header.id_length = 1,
            else => {},
        }
    }
    observed_codec = if (op == 0) &codec else null;
    const buffer = try a.alloc(u8, if (cap < 0) @intCast(-cap - 1) else @intCast(cap));
    defer a.free(buffer);
    @memset(buffer, 165);
    observed_buffer = buffer;
    observed_disk = null;
    var file: ?std.fs.File = null;
    defer if (file) |value| value.close();
    var writer = io.WriteStream.initMemory(buffer);
    if (cap >= 0) {
        const initial = [_]u8{165} ** 1024;
        try std.fs.cwd().writeFile(.{ .sub_path = path, .data = &initial });
        file = try std.fs.cwd().openFile(path, .{ .mode = .read_write });
        try file.?.seekTo(1024);
        writer = io.WriteStream.initFile(file.?, buffer);
        observed_disk = path;
    }
    observed_writer = &writer;
    const start = try number(usize, f[8]);
    if (start > 0) try writer.seekTo(start);
    const iface = p.TGA.formatInterface();
    for (0..try number(usize, f[9])) |_| {
        var status: []const u8 = "ok";
        if (op == 0) codec.write(&writer, pixels) catch |err| {
            status = @errorName(err);
        } else if (op == 1) p.TGA.writeImage(a, &writer, image, .{ .tga = options }) catch |err| {
            status = @errorName(err);
        } else iface.writeImage(a, &writer, image, .{ .tga = options }) catch |err| {
            status = @errorName(err);
        };
        try out.print("{s}|", .{status});
        try snapshot(out);
        try out.writeByte('~');
    }
    var status: []const u8 = "ok";
    writer.writer().flush() catch |err| {
        status = @errorName(err);
    };
    try out.print("flush:{s}|", .{status});
    try snapshot(out);
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args);
    var buffer: [8192]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&buffer);
    const out = &writer.interface;
    if (std.mem.eql(u8, args[1], "--trap")) {
        observed_path = args[2];
        const path = try std.fmt.allocPrint(a, "{s}.bin", .{args[2]});
        defer a.free(path);
        try record(args[3], path, out);
        try out.writeByte('\n');
    } else {
        const text = try std.fs.cwd().readFileAlloc(a, args[1], 1073741824);
        defer a.free(text);
        const path = try std.fmt.allocPrint(a, "{s}.native.bin", .{args[1]});
        defer a.free(path);
        var lines = std.mem.splitScalar(u8, text, '\n');
        while (lines.next()) |line| {
            if (line.len == 0) continue;
            try record(line, path, out);
            try out.writeByte('\n');
        }
    }
    try out.flush();
}
