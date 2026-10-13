const std = @import("std");
const io = @import("src/io.zig");
const Scan = @import("src/formats/jpeg/Scan.zig");
const Frame = @import("src/formats/jpeg/Frame.zig");
const Header = @import("src/formats/jpeg/FrameHeader.zig");
const Component = @typeInfo(@FieldType(Header, "components")).pointer.child;
const Q = @import("src/formats/jpeg/quantization.zig").Table;
const H = @import("src/formats/jpeg/huffman.zig").Table;
const W = std.Io.Writer;
const allocator = std.heap.page_allocator;
pub const panic = std.debug.FullPanic(observe);
var observed_frame: ?*Frame = null;
var observed_stream: ?*io.ReadStream = null;
var observed_path: ?[]const u8 = null;

fn blockHash(f: *const Frame) u64 {
    var hash: u64 = 14695981039346656037;
    for (f.block_storage) |b| {
        for (b) |c| {
            for (c) |value| {
                const n: u32 = @bitCast(value);
                for ([_]u5{ 0, 8, 16, 24 }) |shift| hash = (hash ^ @as(u8, @truncate(n >> shift))) *% 1099511628211;
            }
        }
    }
    return hash;
}

fn observe(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var buffer: [512]u8 = undefined;
            var writer = file.writer(&buffer);
            const out = &writer.interface;
            if (observed_stream) |stream| out.print("{d}", .{stream.getPos()}) catch {};
            if (observed_frame) |frame| out.print("|{d}", .{blockHash(frame)}) catch {};
            out.flush() catch {};
        } else |_| {}
    }
    std.debug.defaultPanic(message, address);
}

fn number(a: []const []const u8, i: usize) !usize {
    return std.fmt.parseInt(usize, a[i], 10);
}
fn table(a: std.mem.Allocator, symbol: u8, cls: u8) !H {
    var result: H = .{ .allocator = a, .code_counts = @splat(0), .code_map = .init(a), .fast_table = @splat(symbol), .fast_size = @splat(1), .table_class = @intCast(cls) };
    try result.code_map.put(.{ .code = 0, .length_minus_one = 0 }, symbol);
    return result;
}
fn scanState(out: *W, s: *const Scan) !void {
    try out.print("{d},{d},{d},{d},{d}|", .{ s.component_count, s.start_of_spectral_selection, s.end_of_spectral_selection, s.approximation_high, s.approximation_low });
    for (s.components) |entry| {
        if (entry) |c| try out.print("{d},{d},{d};", .{ c.component_id, c.dc_table_selector, c.ac_table_selector }) else try out.writeAll("-;");
    }
    try out.print("|{d},{d},{d}|{d},{d},{d},{d}|{d}", .{ s.prediction_values[0], s.prediction_values[1], s.prediction_values[2], s.reader.bit_buffer, s.reader.bit_count, @intFromBool(s.reader.table != null), s.reader.stream.getPos(), s.frame.block_width });
}

fn record(out: *W, fields: []const []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const bytes = try a.alloc(u8, fields[1].len / 2);
    _ = try std.fmt.hexToBytes(bytes, fields[1]);
    var stream = io.ReadStream.initMemory(bytes);
    if (observed_path != null) observed_stream = &stream;
    if (fields[0][0] == 'C') {
        const c = Scan.ScanComponentSpec.read(stream.reader()) catch |err| {
            try out.print("E{s}|{d}", .{ @errorName(err), stream.getPos() });
            return;
        };
        try out.print("{d},{d},{d}|{d}", .{ c.component_id, c.dc_table_selector, c.ac_table_selector, stream.getPos() });
        return;
    }
    var q: [4]?Q = @splat(null);
    var dc: [4]?H = @splat(null);
    var ac: [4]?H = @splat(null);
    for (0..4) |i| {
        if (try number(fields, 4) & (@as(usize, 1) << @intCast(i)) != 0) dc[i] = try table(a, @intCast(try number(fields, 14)), 0);
        if (try number(fields, 4) & (@as(usize, 1) << @intCast(i + 4)) != 0) ac[i] = try table(a, @intCast(try number(fields, 15)), 1);
    }
    var components: std.ArrayList(Component) = .empty;
    if (fields[3].len > 0) {
        var ids = std.mem.splitScalar(u8, fields[3], ',');
        while (ids.next()) |id| {
            try components.append(a, .{ .id = try std.fmt.parseInt(u8, id, 10), .horizontal_sampling_factor = @intCast((try number(fields, 12)) >> 4), .vertical_sampling_factor = @intCast((try number(fields, 12)) & 15), .quantization_table_id = 0 });
        }
    }
    var f: Frame = .{ .allocator = a, .frame_header = .{ .allocator = a, .sample_precision = 8, .width = 0, .height = 0, .components = components.items }, .quantization_tables = &q, .dc_huffman_tables = &dc, .ac_huffman_tables = &ac, .block_storage = try a.alloc([3][64]i32, try number(fields, 10)), .frame_type = @enumFromInt(try number(fields, 2)), .block_width = @intCast(try number(fields, 7)), .block_height = @intCast(try number(fields, 8)), .block_width_actual = @intCast(try number(fields, 9)), .block_height_actual = 4, .horizontal_sampling_factor_max = try number(fields, 5), .vertical_sampling_factor_max = try number(fields, 6) };
    for (f.block_storage, 0..) |*b, bi| {
        for (b, 0..) |*c, ci| {
            for (c, 0..) |*v, i| {
                v.* = @as(i32, @intCast((bi * 13 + ci * 29 + i * 19) % 513)) - 256;
            }
        }
    }
    if (observed_path != null) observed_frame = &f;
    if (fields[0][0] == 'P') {
        Scan.performScan(&f, @intCast(try number(fields, 11)), &stream) catch |err| {
            try out.print("E{s}|{d}|{d}", .{ @errorName(err), stream.getPos(), blockHash(&f) });
            return;
        };
        try out.print("ok|{d}|{d}", .{ stream.getPos(), blockHash(&f) });
        return;
    }
    var scan = Scan.init(&f, &stream) catch |err| {
        try out.print("E{s}|{d}", .{ @errorName(err), stream.getPos() });
        return;
    };
    if (fields[0][0] == 'I') {
        try scanState(out, &scan);
        try out.print("|{d},{d}", .{ @intFromBool(scan.frame == &f), @intFromBool(scan.reader.stream == &stream) });
        return;
    }
    if (fields[0][0] != 'R') @panic("fixture operation");
    var copy = scan;
    scan.component_count = @intCast(try number(fields, 13));
    scan.start_of_spectral_selection = @intCast(try number(fields, 13));
    scan.end_of_spectral_selection = @intCast(try number(fields, 13));
    scan.approximation_high = @intCast((try number(fields, 13)) & 15);
    scan.approximation_low = @intCast((try number(fields, 13)) & 15);
    scan.prediction_values[0] = @as(i32, @intCast(try number(fields, 13))) - 128;
    scan.reader.bit_buffer = @intCast(try number(fields, 13));
    scan.reader.bit_count = @intCast((try number(fields, 13)) & 31);
    scan.components[0].?.component_id = @intCast(try number(fields, 13));
    f.block_width = @intCast(try number(fields, 13));
    copy.components[1] = null;
    copy.prediction_values[1] = 42;
    try scanState(out, &scan);
    try out.writeByte('|');
    try scanState(out, &copy);
    try out.print("|{d}", .{stream.getPos()});
}

pub fn main() !void {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    var buffer: [8192]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&buffer);
    const out = &writer.interface;
    if (args.len > 1 and std.mem.eql(u8, args[1], "--trap")) {
        observed_path = args[2];
        const parts = try split(args[3]);
        try record(out, parts);
        try out.writeByte('\n');
        try out.flush();
        return;
    }
    const input = try std.fs.cwd().readFileAlloc(allocator, args[1], 32 * 1024 * 1024);
    defer allocator.free(input);
    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        const parts = try split(line);
        defer allocator.free(parts);
        try record(out, parts);
        try out.writeByte('\n');
    }
    try out.flush();
}
fn split(line: []const u8) ![][]const u8 {
    var parts: std.ArrayList([]const u8) = .empty;
    var it = std.mem.splitScalar(u8, line, '|');
    while (it.next()) |part| try parts.append(allocator, part);
    return parts.toOwnedSlice(allocator);
}
