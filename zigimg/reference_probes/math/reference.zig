const std = @import("std");
const math = @import("src/math.zig");

fn emit(writer: *std.Io.Writer, value: f32) !void {
    const bits: u32 = if (std.math.isNan(value)) 0x7fc00000 else @bitCast(value);
    try writer.print("{d},", .{bits});
}

fn matrix(writer: *std.Io.Writer, value: anytype) !void {
    for (value.matrix) |row| {
        inline for (0..value.matrix.len) |column| try emit(writer, row[column]);
    }
}

fn run(comptime N: usize, writer: *std.Io.Writer, values: []const f32) !void {
    const Matrix = switch (N) { 2 => math.float2x2, 3 => math.float3x3, 4 => math.float4x4, else => unreachable };
    const Vector = @Vector(N, f32);
    const left = Matrix.fromArray(values[0..N*N].*);
    const right = Matrix.fromArray(values[N*N..2*N*N].*);
    const vector: Vector = values[2*N*N..2*N*N+N].*;
    try emit(writer, left.determinant());
    try matrix(writer, left.inverse());
    const result = left.mulVector(vector);
    inline for (0..N) |channel| try emit(writer, result[channel]);
    try matrix(writer, left.mul(right));
    try matrix(writer, left.transpose());
    const clamp = switch (N) { 2 => math.clamp2, 3 => math.clamp3, 4 => math.clamp4, else => unreachable };
    const clamped = clamp(vector, values[2*N*N+N], values[2*N*N+N+1]);
    inline for (0..N) |channel| try emit(writer, clamped[channel]);
    try matrix(writer, Matrix.identity());
    try matrix(writer, left);
    inline for (0..N) |channel| try emit(writer, vector[channel]);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    const contents = try std.fs.cwd().readFileAlloc(allocator, args[1], 16 * 1024 * 1024);
    var lines = std.mem.tokenizeScalar(u8, contents, '\n');
    var output = std.fs.File.stdout().writer(&.{});
    while (lines.next()) |line| {
        var parts = std.mem.splitScalar(u8, line, '|');
        const dimension = try std.fmt.parseInt(u8, parts.next().?, 10);
        var values: [38]f32 = undefined;
        var size: usize = 0;
        while (parts.next()) |value| {
            values[size] = @bitCast(try std.fmt.parseInt(u32, value, 10));
            size += 1;
        }
        switch (dimension) {
            2 => try run(2, &output.interface, values[0..size]),
            3 => try run(3, &output.interface, values[0..size]),
            4 => try run(4, &output.interface, values[0..size]),
            else => return error.InvalidDimension,
        }
        try output.interface.writeByte('\n');
    }
}
