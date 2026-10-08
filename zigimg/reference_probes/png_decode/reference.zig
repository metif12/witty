const std = @import("std");
const png = @import("src/formats/png.zig");
const reader = @import("src/formats/png/reader.zig");
const color = @import("src/color.zig");
const io = @import("src/io.zig");
const allocator = std.heap.page_allocator;

// Fixture-only panic observation; the dependency bodies and visibility stay
// unchanged. Only initialized state is inspected (never decoder pixel tails).
pub const panic = std.debug.FullPanic(observePanic);
var observed_path: ?[]const u8 = null;
var observed_stream: ?*io.ReadStream = null;
var observed_trns: ?*reader.TrnsProcessor = null;
var observed_plte: ?*reader.PlteProcessor = null;
var observed_tracker: ?*Tracker = null;
var observed_palette: []const color.Rgba32 = &.{};

fn stateHash() u64 {
    var hash: u64 = 14695981039346656037;
    if (observed_stream) |stream| mix(&hash, stream.getPos());
    if (observed_trns) |trns| mix(&hash, @intFromBool(trns.processed));
    if (observed_plte) |plte| mix(&hash, @intFromBool(plte.processed));
    if (observed_tracker) |tracker| mix(&hash, tracker.hash);
    mix(&hash, observed_palette.len);
    for (observed_palette) |entry| for ([_]u8{ entry.r, entry.g, entry.b, entry.a }) |byte| mix(&hash, byte);
    return hash;
}
fn observePanic(message: []const u8, return_address: ?usize) noreturn {
    if (observed_path) |path| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var bytes: [128]u8 = undefined;
            var writer = file.writer(&bytes);
            writer.interface.print("{x:0>16}\n", .{stateHash()}) catch {};
            writer.interface.flush() catch {};
        } else |_| {}
    }
    std.debug.defaultPanic(message, return_address);
}
const Observer = struct {
    fn palette(_: *@This(), data: *reader.PaletteProcessData) @import("src/ImageUnmanaged.zig").ReadError!void {
        observed_palette = data.palette;
    }
    fn row(_: *@This(), data: *reader.RowProcessData) @import("src/ImageUnmanaged.zig").ReadError!@import("src/pixel_format.zig").PixelFormat {
        return data.src_format;
    }
};

fn mix(hash: *u64, value: u64) void {
    hash.* = (hash.* ^ value) *% 1099511628211;
}
fn pixelsHash(pixels: color.PixelStorage) u64 {
    var hash: u64 = 14695981039346656037;
    mix(&hash, @intFromEnum(@as(@import("src/pixel_format.zig").PixelFormat, pixels)));
    mix(&hash, pixels.len());
    for (pixels.asConstBytes()) |byte| mix(&hash, byte);
    if (pixels.getPalette()) |palette| {
        mix(&hash, palette.len);
        for (palette) |c| for ([_]u8{ c.r, c.g, c.b, c.a }) |byte| mix(&hash, byte);
    }
    return hash;
}
const Tracker = struct {
    mode: u16,
    hash: u64 = 14695981039346656037,
    fn processChunk(self: *@This(), data: *reader.ChunkProcessData) @import("src/ImageUnmanaged.zig").ReadError!@import("src/pixel_format.zig").PixelFormat {
        for ([_]u64{ 1, data.chunk_id, data.chunk_length, data.read_stream.getPos(), @intFromEnum(data.current_format) }) |value| mix(&self.hash, value);
        if ((self.mode == 9 and data.chunk_id == 0x49484452) or (self.mode == 10 and data.chunk_id == 0x49444154)) return error.Unsupported;
        if (!reader.isChunkCritical(data.chunk_id)) try data.read_stream.seekBy(@as(i64, data.chunk_length) + 4);
        return if (self.mode == 15 and data.chunk_id == 0x49484452) .rgb24 else data.current_format;
    }
    fn processPalette(self: *@This(), data: *reader.PaletteProcessData) @import("src/ImageUnmanaged.zig").ReadError!void {
        mix(&self.hash, 2);
        mix(&self.hash, data.palette.len);
        for (data.palette) |c| for ([_]u8{ c.r, c.g, c.b, c.a }) |byte| mix(&self.hash, byte);
        if (self.mode == 12) return error.Unsupported;
    }
    fn processRow(self: *@This(), data: *reader.RowProcessData) @import("src/ImageUnmanaged.zig").ReadError!@import("src/pixel_format.zig").PixelFormat {
        for ([_]u64{ 3, @intFromEnum(data.src_format), @intFromEnum(data.dest_format), data.dest_row.len }) |value| mix(&self.hash, value);
        for (data.dest_row) |byte| mix(&self.hash, byte);
        if (self.mode == 11) return error.Unsupported;
        if (self.mode == 14) data.dest_row = data.dest_row[0..1];
        return if (self.mode == 13) .invalid else data.dest_format;
    }
};
pub fn main() !void {
    const args = try std.process.argsAlloc(allocator);
    if (args.len > 2) observed_path = args[2];
    const file_path = try std.fmt.allocPrint(allocator, "{s}.png", .{args[1]});
    defer allocator.free(file_path);
    const contents = try std.fs.cwd().readFileAlloc(allocator, args[1], 128 * 1024 * 1024);
    defer allocator.free(contents);
    var lines = std.mem.tokenizeScalar(u8, contents, '\n');
    var stdout = std.fs.File.stdout().writer(&.{});
    while (lines.next()) |line| {
        var parts = std.mem.splitScalar(u8, line, '|');
        const encoded_mode = try std.fmt.parseInt(u16, parts.next().?, 10);
        const mode = encoded_mode % 100;
        const transport = encoded_mode / 100;
        const encoded = parts.next().?;
        const bytes = try allocator.alloc(u8, encoded.len / 2);
        defer allocator.free(bytes);
        _ = try std.fmt.hexToBytes(bytes, encoded);
        var stream = io.ReadStream.initMemory(bytes);
        var file: ?std.fs.File = null;
        defer if (file) |value| value.close();
        const buffer = try allocator.alloc(u8, if (transport > 0) ([_]usize{ 17, 31, 4096, 16, 33 })[transport - 1] else 0);
        defer allocator.free(buffer);
        if (transport > 0) {
            try std.fs.cwd().writeFile(.{ .sub_path = file_path, .data = bytes });
            file = try std.fs.cwd().openFile(file_path, .{});
            stream = io.ReadStream.initFile(file.?, buffer);
        }
        var trns = reader.TrnsProcessor{};
        var plte = reader.PlteProcessor{};
        var diagnostics: [8192]u8 = @splat(0xa5);
        var writer = std.Io.Writer.fixed(&diagnostics);
        var info = png.InfoProcessor.init(&writer);
        var processors: [3]reader.ReaderProcessor = undefined;
        var count: usize = 0;
        var tracker = Tracker{ .mode = mode };
        var observer = Observer{};
        if (observed_path != null) {
            observed_stream = &stream;
            observed_trns = &trns;
            observed_plte = &plte;
            observed_tracker = &tracker;
            processors[count] = reader.ReaderProcessor.init(0, &observer, null, Observer.palette, Observer.row);
            count += 1;
        }
        if (mode == 1 or mode == 3 or mode == 7) {
            processors[count] = trns.processor();
            count += 1;
        }
        if (mode == 2 or mode == 3) {
            processors[count] = plte.processor();
            count += 1;
        }
        if (mode == 4) {
            processors[count] = info.processor();
            count += 1;
        }
        if (mode >= 8) {
            processors[count] = reader.ReaderProcessor.init(@import("src/formats/png/types.zig").Chunks.Any.id, &tracker, Tracker.processChunk, Tracker.processPalette, Tracker.processRow);
            count += 1;
        }
        const options = reader.ReaderOptions{ .processors = processors[0..count] };
        var status: []const u8 = "ok";
        var width: usize = 0;
        var height: usize = 0;
        var hash: u64 = 0;
        if (mode == 6 or mode == 7) {
            if (reader.loadHeader(&stream)) |header| {
                width = header.width;
                height = header.height;
                if (reader.loadWithHeader(&stream, &header, allocator, options)) |pixels| {
                    defer pixels.deinit(allocator);
                    hash = pixelsHash(pixels);
                } else |err| status = @errorName(err);
            } else |err| status = @errorName(err);
        } else {
            const result = if (mode == 5) png.PNG.readImage(allocator, &stream) else reader.load(&stream, allocator, options);
            if (result) |value| {
                var image = value;
                defer image.deinit(allocator);
                width = image.width;
                height = image.height;
                hash = pixelsHash(image.pixels);
            } else |err| status = @errorName(err);
        }
        var output_hash: u64 = 14695981039346656037;
        for (diagnostics) |byte| mix(&output_hash, byte);
        try stdout.interface.print("{s}|{d}|{d}|{d}|{x:0>16}|{}|{}|{d}|{d}|{d}|{x:0>16}|{x:0>16}\n", .{ status, stream.getPos(), width, height, hash, trns.processed, plte.processed, info.idat_count, info.idat_size, writer.end, output_hash, tracker.hash });
    }
}
