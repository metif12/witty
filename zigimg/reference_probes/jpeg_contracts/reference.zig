const std = @import("std");
const io = @import("src/io.zig");
const Header = @import("src/formats/jpeg/FrameHeader.zig");
const JFIF = @import("src/formats/jpeg/JFIFHeader.zig");
const Q = @import("src/formats/jpeg/quantization.zig");
const H = @import("src/formats/jpeg/huffman.zig");
const JPEG = @import("src/formats/jpeg.zig").JPEG;
const color = @import("src/color.zig");
const W = std.Io.Writer;
const alloc = std.heap.page_allocator;
pub const panic = std.debug.FullPanic(observePanic);
var observed_stream: ?*io.ReadStream = null;
var observed_reader: ?*H.Reader = null;
var observed_path: ?[]const u8 = null;

fn readerState(out: *W, r: *H.Reader) !void {
    try out.print("{d},{d},{d}", .{ r.bit_buffer, r.bit_count, r.stream.getPos() });
}
fn observePanic(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var buf: [256]u8 = undefined;
            var writer = file.writer(&buf);
            if (observed_reader) |r| readerState(&writer.interface, r) catch {} else if (observed_stream) |s| writer.interface.print("{d}", .{s.getPos()}) catch {};
            writer.interface.flush() catch {};
        } else |_| {}
    }
    std.debug.defaultPanic(message, address);
}
fn n(p: []const []const u8, i: usize) !u32 {
    return std.fmt.parseInt(u32, p[i], 10);
}
fn bytes(a: std.mem.Allocator, s: []const u8) ![]u8 {
    const result = try a.alloc(u8, s.len / 2);
    _ = try std.fmt.hexToBytes(result, s);
    return result;
}
fn hex(out: *W, b: []const u8) !void {
    for (b) |v| try out.print("{x:0>2}", .{v});
}
fn tableState(out: *W, t: H.Table, a: std.mem.Allocator) !void {
    try out.print("{d}|", .{t.table_class});
    try hex(out, &t.code_counts);
    try out.writeByte('|');
    const keys = try a.alloc(u32, t.code_map.count());
    for (t.code_map.keys(), 0..) |k, i| keys[i] = (@as(u32, k.length_minus_one) << 16) | k.code;
    std.mem.sort(u32, keys, {}, std.sort.asc(u32));
    for (keys) |k| try out.print("{d}:{d},", .{ k, t.code_map.get(.{ .length_minus_one = @intCast(k >> 16), .code = @truncate(k) }).? });
    try out.writeByte('|');
    try hex(out, &t.fast_table);
    try out.writeByte('|');
    for (t.fast_size) |v| try out.print("{x:0>2}", .{@as(u8, v)});
}
fn readerOp(out: *W, r: *H.Reader, op: u8, value: u5) !void {
    switch (op) {
        'p' => {
            if (r.peekBits(value)) |v| try out.print("{d}", .{v}) else |e| try out.print("E{s}", .{@errorName(e)});
        },
        'r' => {
            if (r.readBits(value)) |v| try out.print("{d}", .{v}) else |e| try out.print("E{s}", .{@errorName(e)});
        },
        'm' => {
            if (r.readMagnitudeCoded(value)) |v| try out.print("{d}", .{v}) else |e| try out.print("E{s}", .{@errorName(e)});
        },
        'h' => {
            if (r.readCode()) |v| try out.print("{d}", .{v}) else |e| try out.print("E{s}", .{@errorName(e)});
        },
        'f' => {
            if (r.fillBits(value)) |_| try out.writeAll("ok") else |e| try out.print("E{s}", .{@errorName(e)});
        },
        'c' => {
            r.consumeBits(value);
            try out.writeAll("ok");
        },
        'z' => {
            r.flushBits();
            try out.writeAll("ok");
        },
        else => @panic("invalid fixture operation"),
    }
}
fn record(out: *W, p: []const []const u8, id: usize, file_path: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const a = arena.allocator();
    const data = try bytes(a, p[2]);
    const capacity = try n(p, 1);
    const buffer = try a.alloc(u8, capacity);
    var stream = io.ReadStream.initMemory(data);
    var file: ?std.fs.File = null;
    defer if (file) |f| f.close();
    if (capacity > 0) {
        try std.fs.cwd().writeFile(.{ .sub_path = file_path, .data = data });
        file = try std.fs.cwd().openFile(file_path, .{});
        stream = io.ReadStream.initFile(file.?, buffer);
    }
    if (observed_path != null) observed_stream = &stream;
    try out.print("{d}|", .{id});
    switch (p[0][0]) {
        'F' => {
            const h = Header.read(a, stream.reader()) catch |e| {
                try out.print("E{s}|{d}\n", .{ @errorName(e), stream.getPos() });
                return;
            };
            try out.print("{d},{d},{d}|", .{ h.sample_precision, h.height, h.width });
            for (h.components) |c| try out.print("{d},{d},{d},{d};", .{ c.id, c.horizontal_sampling_factor, c.vertical_sampling_factor, c.quantization_table_id });
            try out.print("|{d},{d}", .{ h.getMaxHorizontalSamplingFactor(), h.getMaxVerticalSamplingFactor() });
        },
        'J' => {
            const h = JFIF.read(&stream) catch |e| {
                try out.print("E{s}|{d}\n", .{ @errorName(e), stream.getPos() });
                return;
            };
            try out.print("{d},{d},{d},{d}", .{ h.jfif_revision, @intFromEnum(h.density_unit), h.x_density, h.y_density });
        },
        'Q' => {
            const t = Q.Table.read(@intCast(try n(p, 3)), stream.reader()) catch |e| {
                try out.print("E{s}|{d}\n", .{ @errorName(e), stream.getPos() });
                return;
            };
            switch (t) {
                .q8 => |values| {
                    try out.writeAll("0|");
                    for (values) |v| try out.print("{d},", .{v});
                },
                .q16 => |values| {
                    try out.writeAll("1|");
                    for (values) |v| try out.print("{d},", .{v});
                },
            }
        },
        'T' => {
            const t = H.Table.read(a, @intCast(try n(p, 3)), stream.reader()) catch |e| {
                try out.print("E{s}|{d}\n", .{ @errorName(e), stream.getPos() });
                return;
            };
            try tableState(out, t, a);
        },
        'R', 'B' => {
            var r = H.Reader.init(&stream);
            r.bit_buffer = try n(p, 3);
            r.bit_count = @intCast(try n(p, 4));
            var t: H.Table = .{ .allocator = a, .code_counts = @splat(0), .code_map = .init(a), .fast_table = @splat(255), .fast_size = @splat(0), .table_class = 0 };
            if (p[0][0] == 'B') {
                t.fast_table[0] = @intCast(try n(p, 6));
                t.fast_size[0] = 1;
                r.setHuffmanTable(&t);
                t.fast_table[0] = @intCast(try n(p, 7));
            }
            var commands = std.mem.splitScalar(u8, p[5], ',');
            while (commands.next()) |c| {
                try readerOp(out, &r, c[0], @intCast(try std.fmt.parseInt(u8, c[1..], 10)));
                try out.writeByte(':');
                try readerState(out, &r);
                try out.writeByte(';');
            }
        },
        'D' => {
            var jpeg = JPEG.init(a);
            const initial = try a.alloc(color.Grayscale8, 1);
            initial[0] = .{ .value = 17 };
            var pixels: ?color.PixelStorage = .{ .grayscale8 = initial };
            const f = jpeg.read(&stream, &pixels) catch |e| {
                try out.print("E{s}|{d},{d}|{d}\n", .{ @errorName(e), @intFromBool(pixels != null), @intFromBool(jpeg.frame != null), stream.getPos() });
                return;
            };
            var hash: u64 = 14695981039346656037;
            for (pixels.?.asBytes()) |b| hash = (hash ^ b) *% 1099511628211;
            try out.print("{d},{d},{s}|{x:0>16}", .{ f.frame_header.width, f.frame_header.height, @tagName(pixels.?), hash });
        },
        else => @panic("invalid fixture record"),
    }
    try out.print("|{d}\n", .{stream.getPos()});
}
fn trap(name: []const u8, path: []const u8, op: []const u8, data: []u8, value: u8) !void {
    var stream = io.ReadStream.initMemory(data);
    var r = H.Reader.init(&stream);
    observed_stream = &stream;
    observed_path = path;
    if (op[0] == 'R') {
        observed_reader = &r;
        if (std.mem.eql(u8, name, "fill_overflow")) {
            r.bit_count = 24;
            r.bit_buffer = 0x12345600;
            try r.fillBits(25);
        } else if (std.mem.eql(u8, name, "fill_shift")) {
            r.bit_count = 25;
            try r.fillBits(26);
        } else if (std.mem.eql(u8, name, "consume")) r.consumeBits(1) else if (std.mem.eql(u8, name, "consume17")) {
            r.bit_count = 24;
            r.consumeBits(17);
        } else if (std.mem.eql(u8, name, "missing_table")) {
            _ = try r.readCode();
        } else {
            _ = try r.peekBits(@intCast(value));
        }
    } else {
        const encoded = try alloc.alloc(u8, data.len * 2);
        var encoder = std.Io.Writer.fixed(encoded);
        try hex(&encoder, data);
        const val = try std.fmt.allocPrint(alloc, "{d}", .{value});
        var buf: [65536]u8 = undefined;
        var writer = std.Io.Writer.fixed(&buf);
        try record(&writer, &.{ op, "0", encoded, val }, 0, "");
    }
    @panic("UNEXPECTED returning trap");
}
pub fn main() !void {
    const args = try std.process.argsAlloc(alloc);
    if (args.len > 2 and std.mem.eql(u8, args[1], "--trap")) {
        trap(args[2], args[3], args[4], try bytes(alloc, args[5]), try std.fmt.parseInt(u8, args[6], 10)) catch |e| {
            std.debug.print("UNEXPECTED {s}\n", .{@errorName(e)});
            std.process.exit(1);
        };
        return;
    }
    const input = try std.fs.cwd().readFileAlloc(alloc, args[1], 128 * 1024 * 1024);
    const file_path = try std.fmt.allocPrint(alloc, "{s}.jpg", .{args[1]});
    var buf: [65536]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&buf);
    var rows = std.mem.splitScalar(u8, input, '\n');
    var id: usize = 0;
    while (rows.next()) |line| {
        if (line.len == 0) continue;
        var split = std.mem.splitScalar(u8, line, '|');
        var parts: [8][]const u8 = undefined;
        var len: usize = 0;
        while (split.next()) |p| {
            parts[len] = p;
            len += 1;
        }
        try record(&writer.interface, parts[0..len], id, file_path);
        id += 1;
    }
    try writer.interface.flush();
}
