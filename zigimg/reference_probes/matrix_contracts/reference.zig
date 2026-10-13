const std = @import("std");
const math = @import("src/math.zig");
fn emit(writer: *std.Io.Writer, value: f32) !void {
    try writer.print("{d},", .{@as(u32, @bitCast(value))});
}
fn record(comptime N: usize, writer: *std.Io.Writer, value: anytype) !void {
    for (value.matrix) |row| inline for (0..N) |column| try emit(writer, row[column]);
}
fn changed(value: anytype, row: usize, column: usize, raw: u32) @TypeOf(value) {
    var result = value;
    result.matrix[row][column] = @bitCast(raw);
    return result;
}
fn run(comptime N: usize, comptime M: type, writer: *std.Io.Writer, row: usize, column: usize, values: []const f32) !void {
    var storage: [N]@Vector(N, f32) = undefined;
    var flat: [N * N]f32 = undefined;
    for (0..N) |r| for (0..N) |c| {
        storage[r][c] = values[r * N + c];
        flat[r * N + c] = values[r * N + c];
    };
    var original = M{ .matrix = storage };
    const constructed = M.fromArray(flat);
    var copy = original;
    copy.matrix[row][column] = @bitCast(@as(u32, 0x80000000));
    storage[row][column] = @bitCast(@as(u32, 0x7fc01234));
    flat[row * N + column] = @bitCast(@as(u32, 0xff800000));
    var row_copy = constructed;
    row_copy.matrix[row] = storage[row];
    var replacement = original;
    replacement.matrix = storage;
    storage[row][column] = @bitCast(@as(u32, 0x3f800000));
    const returned = changed(original, row, column, 0x7fc05678);
    // Observe every original before and after mutation through another value.
    try record(N, writer, original);
    try record(N, writer, constructed);
    try record(N, writer, copy);
    try record(N, writer, row_copy);
    try record(N, writer, replacement);
    try record(N, writer, returned);
    for (storage) |r| inline for (0..N) |c| try emit(writer, r[c]);
    for (flat) |v| try emit(writer, v);
    var transposed = original.transpose();
    transposed.matrix[column][row] = @bitCast(@as(u32, 0x7fc09abc));
    try record(N, writer, transposed);
    try record(N, writer, original);
    original.matrix[row][column] = @bitCast(@as(u32, 0x40000000));
    try record(N, writer, original);
    try record(N, writer, replacement);
    try record(N, writer, M.identity());
    try writer.writeByte('\n');
}
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    const contents = try std.fs.cwd().readFileAlloc(allocator, args[1], 16 * 1024 * 1024);
    var lines = std.mem.tokenizeScalar(u8, contents, '\n');
    var buffer: [64 * 1024]u8 = undefined;
    var output = std.fs.File.stdout().writer(&buffer);
    const writer = &output.interface;
    while (lines.next()) |line| {
        var parts = std.mem.splitScalar(u8, line, '|');
        const form = try std.fmt.parseInt(u8, parts.next().?, 10);
        const row = try std.fmt.parseInt(usize, parts.next().?, 10);
        const column = try std.fmt.parseInt(usize, parts.next().?, 10);
        var values: [64]f32 = undefined;
        var size: usize = 0;
        while (parts.next()) |raw| {
            values[size] = @bitCast(try std.fmt.parseInt(u32, raw, 10));
            size += 1;
        }
        switch (form) {
            0 => try run(2, math.float2x2, writer, row, column, values[0..size]),
            1 => try run(3, math.float3x3, writer, row, column, values[0..size]),
            2 => try run(4, math.float4x4, writer, row, column, values[0..size]),
            3 => try run(1, math.Matrix([1]@Vector(1, f32)), writer, row, column, values[0..size]),
            4 => try run(2, math.Matrix([2]@Vector(2, f32)), writer, row, column, values[0..size]),
            5 => try run(3, math.Matrix([3]@Vector(3, f32)), writer, row, column, values[0..size]),
            6 => try run(4, math.Matrix([4]@Vector(4, f32)), writer, row, column, values[0..size]),
            7 => try run(5, math.Matrix([5]@Vector(5, f32)), writer, row, column, values[0..size]),
            8 => try run(8, math.Matrix([8]@Vector(8, f32)), writer, row, column, values[0..size]),
            else => return error.InvalidForm,
        }
    }
    try writer.flush();
}
