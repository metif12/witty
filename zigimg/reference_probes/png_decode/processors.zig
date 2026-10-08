const std = @import("std");
const reader = @import("src/formats/png/reader.zig");
const png = @import("src/formats/png/types.zig");
const color = @import("src/color.zig");
const io = @import("src/io.zig");
const PixelFormat = @import("src/pixel_format.zig").PixelFormat;
const ReadError = @import("src/ImageUnmanaged.zig").ReadError;
const allocator = std.heap.page_allocator;

// All bytes observed here are initialized consumer-owned rows/palettes. The
// alpha allocation made by processChunk is observed by length, never contents.
pub const panic = std.debug.FullPanic(observePanic);
var observed_path: ?[]const u8 = null;
var observed: ?*State = null;
const State = struct {
    stream: io.ReadStream,
    trns: reader.TrnsProcessor,
    plte: reader.PlteProcessor,
    row: reader.RowProcessData,
    palette: []color.Rgba32,
    observe_trns_data: bool = true,
    fn hash(self: *const State) u64 {
        var value: u64 = 14695981039346656037;
        for ([_]u64{ self.stream.getPos(), @intFromBool(self.trns.processed), @intFromBool(self.plte.processed), @intFromEnum(self.row.src_format), @intFromEnum(self.row.dest_format), self.row.dest_row.len, self.palette.len, self.plte.palette.len }) |x| mix(&value, x);
        for (self.row.dest_row) |x| mix(&value, x);
        for (self.palette) |p| for ([_]u8{ p.r, p.g, p.b, p.a }) |x| mix(&value, x);
        if (!self.observe_trns_data) return value;
        switch (self.trns.trns_data) {
            .unset => mix(&value, 0),
            .gray => |x| { mix(&value, 1); mix(&value, x); },
            .rgb => |x| { mix(&value, 2); mix(&value, x.r); mix(&value, x.g); mix(&value, x.b); },
            .index_alpha => |x| { mix(&value, 3); mix(&value, x.len); },
        }
        return value;
    }
};
fn mix(hash: *u64, value: u64) void { hash.* = (hash.* ^ value) *% 1099511628211; }
fn observePanic(message: []const u8, return_address: ?usize) noreturn {
    if (observed_path) |path| if (observed) |state| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var bytes: [64]u8 = undefined;
            var writer = file.writer(&bytes);
            writer.interface.print("{x:0>16}\n", .{state.hash()}) catch {};
            writer.interface.flush() catch {};
        } else |_| {}
    };
    std.debug.defaultPanic(message, return_address);
}
pub fn main() !void {
    const args = try std.process.argsAlloc(allocator);
    if (args.len > 2) observed_path = args[2];
    const contents = try std.fs.cwd().readFileAlloc(allocator, args[1], 16 * 1024 * 1024);
    defer allocator.free(contents);
    var lines = std.mem.tokenizeScalar(u8, contents, '\n');
    var stdout = std.fs.File.stdout().writer(&.{});
    while (lines.next()) |line| {
        var fields = std.mem.splitScalar(u8, line, '|');
        var p: [7]u32 = undefined;
        for (&p) |*value| value.* = try std.fmt.parseInt(u32, fields.next().?, 10);
        const op = p[0];
        var bytes: [64]u8 = undefined;
        for (&bytes, 0..) |*x, i| x.* = @truncate(i * 13 + 7);
        var header = png.HeaderData{ .width = 1, .height = 1, .bit_depth = 8, .color_type = .grayscale, .compression_method = .deflate, .filter_method = .adaptive, .interlace_method = .none };
        const row_len: usize = if (op <= 2) p[4] else 16;
        const palette_len: usize = if (op == 2) p[3] else if (op == 3) p[3] else 4;
        const palette = try allocator.alloc(color.Rgba32, palette_len);
        defer allocator.free(palette);
        for (palette, 0..) |*x, i| x.* = .{ .r = @truncate(i * 3 + 1), .g = @truncate(i * 5 + 2), .b = @truncate(i * 7 + 3), .a = 211 };
        const row = try allocator.alloc(u8, row_len);
        defer allocator.free(row);
        for (row, 0..) |*x, i| x.* = @truncate(i * 13 + p[5]);
        var alpha: [16]u8 = undefined;
        for (&alpha, 0..) |*x, i| x.* = @truncate(i * 17 + 3);
        var state = State{
            .stream = io.ReadStream.initMemory(bytes[0..if (op == 4) p[6] else bytes.len]),
            .trns = .{},
            .plte = .{ .palette = palette },
            .row = .{ .dest_row = row, .src_format = if (op <= 2) @enumFromInt(p[1]) else .grayscale8, .dest_format = if (op <= 2) @enumFromInt(p[2]) else .rgba32, .header = &header, .temp_allocator = allocator },
            .palette = palette,
        };
        observed = &state;
        const arm = if (op <= 1) p[3] else if (op == 3) p[1] else 0;
        state.trns.trns_data = switch (arm) {
            0 => .unset,
            1 => .{ .gray = 7 },
            2 => .{ .rgb = .{ .r = 7, .g = 18, .b = 29 } },
            3 => .{ .index_alpha = alpha[0..if (op == 3) p[2] else 2] },
            else => unreachable,
        };
        if (op == 2 and palette.len > 0) {
            const stride: usize = if (state.row.dest_format == .rgba64) 8 else 4;
            var pos: usize = 0;
            while (pos + 3 < row.len) : (pos += stride) {
                const index: u16 = @intCast(p[5] + if (p[6] >= 2) @as(u32, @intCast(pos / stride)) else 0);
                row[pos] = @truncate(index);
                if (state.row.src_format == .indexed16) {
                    const native = std.mem.asBytes(&index);
                    row[pos] = native[0]; row[pos + 1] = native[1];
                }
            }
        }
        var result = state.row.src_format;
        var status: []const u8 = "ok";
        switch (op) {
            0 => result = state.trns.processDataRow(&state.row) catch |err| blk: { status = @errorName(err); break :blk .invalid; },
            1 => { var processor = state.trns.processor(); result = processor.processDataRow(&state.row) catch |err| blk: { status = @errorName(err); break :blk .invalid; }; },
            2 => { var processor = state.plte.processor(); result = if (p[6] == 0) state.plte.processDataRow(&state.row) catch |err| blk: { status = @errorName(err); break :blk .invalid; } else processor.processDataRow(&state.row) catch |err| blk: { status = @errorName(err); break :blk .invalid; }; },
            3 => {
                var data = reader.PaletteProcessData{ .palette = palette, .temp_allocator = allocator };
                if (p[6] == 0) state.trns.processPalette(&data) catch |err| { status = @errorName(err); } else { var processor = state.trns.processor(); processor.processPalette(&data) catch |err| { status = @errorName(err); }; }
            },
            4, 5 => {
                header.color_type = @enumFromInt(p[1]); header.bit_depth = @intCast(p[2]);
                state.trns.processed = p[5] != 0; state.plte.processed = p[5] != 0;
                var data = reader.ChunkProcessData{ .read_stream = &state.stream, .chunk_id = 0, .chunk_length = p[4], .current_format = @enumFromInt(p[3]), .header = &header, .temp_allocator = allocator };
                result = if (op == 4) state.trns.processChunk(&data) catch |err| blk: { status = @errorName(err); break :blk .invalid; } else state.plte.processChunk(&data) catch |err| blk: { status = @errorName(err); break :blk .invalid; };
            },
            6 => {
                var processor = reader.ReaderProcessor.init(0, &state, null, null, null);
                var data = reader.ChunkProcessData{ .read_stream = &state.stream, .chunk_id = 0, .chunk_length = 0, .current_format = .grayscale16, .header = &header, .temp_allocator = allocator };
                if (p[1] == 0) result = try processor.processChunk(&data) else if (p[1] == 1) { var pd = reader.PaletteProcessData{ .palette = palette, .temp_allocator = allocator }; try processor.processPalette(&pd); } else result = try processor.processDataRow(&state.row);
            },
            7 => {
                header.width = p[1]; header.height = p[2];
                var input = [_]u8{ 0, 0, 0, 0, 'I', 'D', 'A', 'T' };
                state.stream = io.ReadStream.initMemory(&input);
                _ = reader.loadWithHeader(&state.stream, &header, allocator, .{}) catch |err| { status = @errorName(err); };
            },
            else => unreachable,
        }
        // Failed try-assignment can leave a source union payload undefined.
        // Observe only initialized rows/palettes/positions/flags on that path.
        if (op == 4 and !std.mem.eql(u8, status, "ok")) state.observe_trns_data = false;
        try stdout.interface.print("{s}|{d}|{x:0>16}\n", .{status, @intFromEnum(result), state.hash()});
    }
}
