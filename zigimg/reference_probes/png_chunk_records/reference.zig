const std = @import("std");
const cw = @import("src/formats/png/chunk_writer.zig");
const allocator = std.heap.page_allocator;

const Output = struct { stream: std.Io.Writer, calls: usize = 0 };
const Adapter = struct {
    output: *Output,
    label: u8 = 7,
    pub const Error = std.Io.Writer.Error;
    pub fn writeInt(self: @This(), comptime T: type, value: T, endian: std.builtin.Endian) Error!void {
        self.output.calls += 1;
        try self.output.stream.writeInt(T, value, endian);
    }
    pub fn writeAll(self: @This(), bytes: []const u8) Error!void {
        self.output.calls += 1;
        try self.output.stream.writeAll(bytes);
    }
    pub fn write(self: @This(), bytes: []const u8) Error!usize {
        self.output.calls += 1;
        return self.output.stream.write(bytes);
    }
};
const ByteAlias = u8;
const AdapterAlias = Adapter;
const RecordAlias = cw.ChunkWriter(4, AdapterAlias);

fn hash(bytes: []const u8) u64 {
    var result: u64 = 14695981039346656037;
    for (bytes) |byte| result = (result ^ byte) *% 1099511628211;
    return result;
}

fn fromLocal(comptime size: usize, output: *Output, seed: u8) cw.ChunkWriter(size, Adapter) {
    var buffer: [size]ByteAlias = undefined;
    for (&buffer, 0..) |*byte, i| byte.* = @truncate(i * 37 + @as(usize, seed) * 19);
    const writer = cw.ChunkWriter(size, Adapter){ .unbuffered_writer = .{ .output = output }, .section_id = "IDAT".*, .buf = buffer };
    @memset(&buffer, 0xff);
    return writer;
}

fn run(comptime size: usize, seed: u8, form: u8, stdout: *std.Io.Writer) !void {
    const destination = try allocator.alloc(u8, size * 2 + 32);
    defer allocator.free(destination);
    @memset(destination, 0xa5);
    var output = Output{ .stream = std.Io.Writer.fixed(destination) };
    var writer = if (form == 0)
        cw.ChunkWriter(size, Adapter){ .unbuffered_writer = .{ .output = &output }, .section_id = "IDAT".* }
    else
        fromLocal(size, &output, seed);
    // Source's default buffer is undefined; initialize every byte before reading.
    if (form == 0) for (&writer.buf, 0..) |*byte, i| {
        byte.* = @truncate(i * 37 + @as(usize, seed) * 19);
    };
    const initial_end = writer.end;
    writer.end = size;
    var copy = writer;
    copy.unbuffered_writer.label = 17;
    copy.section_id = "tEXt".*;
    if (size != 0) {
        const borrowed = writer.buf[0..];
        borrowed[0] = seed ^ 0x50;
        copy.buf[size - 1] = seed ^ 0xa0;
    }
    const before = hash(&writer.buf);
    const copied_before = hash(&copy.buf);
    try copy.flush();
    const copied_end = copy.end;
    const original_end_after_copy = writer.end;
    try writer.flush();
    try stdout.print("R|{d}|{d}|{d}|{d}|{d}|{d}|{d}|{d}|{x:0>16}|{x:0>16}|{d}|{d}|{x:0>16}\n", .{
        size,                           seed,                         form,   initial_end,   original_end_after_copy, copied_end,
        writer.unbuffered_writer.label, copy.unbuffered_writer.label, before, copied_before, output.stream.end,       output.calls,
        hash(destination),
    });
}

fn aliasRecord(stdout: *std.Io.Writer) !void {
    var destination = [_]u8{0xa5} ** 32;
    var output = Output{ .stream = std.Io.Writer.fixed(&destination) };
    var writer = RecordAlias{ .unbuffered_writer = .{ .output = &output }, .section_id = "IDAT".*, .buf = .{ 1, 2, 3, 4 } };
    const before = writer.end;
    writer.unbuffered_writer.label = 29;
    writer.buf[0] = 9;
    writer.end = 2;
    writer.section_id = "tEXt".*;
    var copy = writer;
    copy.buf[0] = 8;
    copy.section_id[0] = 'a';
    try copy.flush();
    try stdout.print("A|{d}|{d}|{d}|{d}|{d}|{d}|{d}|{x:0>16}\n", .{
        before,               writer.end,         copy.end,           writer.buf[0], copy.buf[0],
        writer.section_id[0], copy.section_id[0], hash(&destination),
    });
}

fn pointerWriter(stdout: *std.Io.Writer) !void {
    var destination = [_]u8{0xa5} ** 32;
    var output = Output{ .stream = std.Io.Writer.fixed(&destination) };
    var adapter = Adapter{ .output = &output };
    const writer = cw.ChunkWriter(4, *Adapter){ .unbuffered_writer = &adapter, .section_id = "IDAT".*, .buf = .{ 1, 2, 3, 4 }, .end = 2 };
    var copy = writer;
    copy.unbuffered_writer.label = 42;
    copy.buf[0] = 9;
    copy.end = 1;
    try copy.flush();
    try stdout.print("P|{d}|{d}|{d}|{d}|{d}|{d}|{d}|{x:0>16}\n", .{
        writer.unbuffered_writer.label, copy.unbuffered_writer.label,
        writer.buf[0],                  copy.buf[0],
        writer.end,                     copy.end,
        output.stream.end,              hash(&destination),
    });
}

pub fn main() !void {
    var stdout = std.fs.File.stdout().writer(&.{});
    inline for (.{ 0, 1, 4, 16, 16384 }) |size| {
        for (0..16) |seed| for (0..2) |form| {
            try run(size, @intCast(seed), @intCast(form), &stdout.interface);
        };
    }
    try aliasRecord(&stdout.interface);
    try pointerWriter(&stdout.interface);
    var destination = [_]u8{0xa5} ** 32;
    var output = Output{ .stream = std.Io.Writer.fixed(&destination) };
    const factory = cw.chunkWriter(Adapter{ .output = &output }, "IDAT");
    try stdout.interface.print("F|{d}|{d}|{s}|{d}\n", .{ factory.end, factory.buf.len, factory.section_id, factory.unbuffered_writer.label });
}
