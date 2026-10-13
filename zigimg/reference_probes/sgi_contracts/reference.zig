const std = @import("std");
const p = @import("src/formats/sgi.zig");
const io = @import("src/io.zig");
const a = std.heap.page_allocator;
const Header = @TypeOf((p.SGI{}).header);
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_codec: ?*const p.SGI = null;
var observed_reader: ?*io.ReadStream = null;
var observed_buffer: []const u8 = &.{};
fn state(out: *std.Io.Writer) !void {
    const codec = observed_codec.?;
    try out.print("{d}|{x}|{x}|{x}", .{ observed_reader.?.getPos(), std.mem.asBytes(&codec.header), std.mem.sliceAsBytes(codec.palette.data), observed_buffer });
}
fn observe(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var bytes: [4096]u8 = undefined;
            var writer = file.writer(&bytes);
            state(&writer.interface) catch {};
            writer.interface.flush() catch {};
        } else |_| {}
    }
    std.debug.defaultPanic(message, address);
}
fn header(width: u16, height: u16, channels: u16, bpc: u8) Header {
    return .{ .compression = .rle, .bytes_per_channel = bpc, .dimension = .single_channel, .x_size = width, .y_size = height, .z_size = channels, .pix_min = 123, .pix_max = 456, .dummy1 = 789, .image_name = .{'X'} ++ .{0} ** 79, .pixel_format = .normal, .dummy2 = .{0} ** 403 ++ .{77} };
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    var bytes: [8192]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&bytes);
    const out = &writer.interface;
    if (args.len > 1) {
        if (!std.mem.eql(u8, args[2], "-")) observed_path = args[2];
        const read = std.mem.eql(u8, args[1], "--read");
        var codec = p.SGI{ .header = if (read) header(7, 9, 3, 1) else header(try std.fmt.parseInt(u16, args[4], 10), try std.fmt.parseInt(u16, args[5], 10), try std.fmt.parseInt(u16, args[6], 10), try std.fmt.parseInt(u8, args[3], 10)) };
        codec.palette.resize(4);
        for (codec.palette.data, 0..) |*entry, i| entry.* = .{ .r = @intCast(i * 31), .g = @intCast(i * 71), .b = @intCast(i * 47), .a = 99 };
        const data = try std.fs.cwd().readFileAlloc(a, args[if (read) 3 else 8], 1048576);
        var reader = io.ReadStream.initMemory(data);
        observed_codec = &codec;
        observed_reader = &reader;
        if (read) {
            const result = codec.read(a, &reader) catch |err| {
                try out.print("{s}|", .{@errorName(err)});
                try state(out);
                try out.writeByte('\n');
                try out.flush();
                return;
            };
            defer result.deinit(a);
            {
                try out.writeAll("ok|");
                try state(out);
                try out.print("|{d}|{d}|{x}\n", .{ @intFromEnum(std.meta.activeTag(result)), result.len(), result.asBytes() });
                try out.flush();
                return;
            }
        } else {
            var buffer: [1024]u8 = @splat(165);
            const capacity = try std.fmt.parseInt(usize, args[7], 10);
            observed_buffer = buffer[0..capacity];
            codec.uncompressBitmap(a, &reader, buffer[0..capacity]) catch |err| {
                try out.print("{s}|", .{@errorName(err)});
                try state(out);
                try out.writeByte('\n');
                try out.flush();
                return;
            };
            {
                try out.writeAll("ok|");
                try state(out);
                try out.writeByte('\n');
                try out.flush();
                return;
            }
        }
    }
    const h = header(7, 9, 3, 1);
    try out.print("H|{d}|{x}\n", .{ @sizeOf(Header), std.mem.asBytes(&h) });
    for ([_]u16{ 0, 1, 255, 32768, 65535 }) |width| for ([_]u16{ 0, 1, 255, 32768, 65535 }) |height| {
        var codec = p.SGI{ .header = header(width, height, 3, 1) };
        try out.print("D|{d}|{d}\n", .{ codec.width(), codec.height() });
    };
    for (std.meta.tags(p.SgiPixelFormat)) |format| for (std.meta.tags(p.Dimensions)) |dimension| {
        for ([_]u8{ 0, 1, 2, 3, 255 }) |bpc| for ([_]u16{ 0, 1, 3, 4, 256, 65535 }) |channels| {
            var codec = p.SGI{ .header = header(1, 1, channels, bpc) };
            codec.header.pixel_format = format;
            codec.header.dimension = dimension;
            var status: []const u8 = "ok";
            const result = codec.pixelFormat() catch |err| blk: {
                status = @errorName(err);
                break :blk @as(@import("src/pixel_format.zig").PixelFormat, .invalid);
            };
            try out.print("P|{d}|{d}|{d}|{d}|{s}|{d}\n", .{ @intFromEnum(format), @intFromEnum(dimension), bpc, channels, status, @intFromEnum(result) });
        };
    };
    try out.flush();
}
