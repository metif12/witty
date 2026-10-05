const std = @import("std");
const color = @import("src/color.zig");

fn emit(writer: *std.Io.Writer, value: f32) !void {
    const bits: u32 = if (std.math.isNan(value)) 0x7fc00000 else @bitCast(value);
    try writer.print("{d},", .{bits});
}

fn record(writer: *std.Io.Writer, value: anytype) !void {
    inline for (@typeInfo(@TypeOf(value)).@"struct".fields) |field| {
        try emit(writer, @field(value, field.name));
    }
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    const contents = try std.fs.cwd().readFileAlloc(allocator, args[1], 16 * 1024 * 1024);
    var lines = std.mem.tokenizeScalar(u8, contents, '\n');
    var output = std.fs.File.stdout().writer(&.{});
    const writer = &output.interface;
    while (lines.next()) |line| {
        var parts = std.mem.splitScalar(u8, line, '|');
        var values: [6]f32 = undefined;
        for (&values) |*value| value.* = @bitCast(try std.fmt.parseInt(u32, parts.next().?, 10));
        const xyz = color.CIEXYZ{ .x = values[0], .y = values[1], .z = values[2] };
        const xyza = color.CIEXYZAlpha{ .x = values[0], .y = values[1], .z = values[2], .a = values[3] };
        const white = color.CIExyY{ .x = values[4], .y = values[5] };
        const white_xyz = white.toXYZ(1);
        try emit(writer, white.z());
        try record(writer, white_xyz);
        try record(writer, color.CIELab.fromXYZ(xyz, white));
        const lab = color.CIELab{ .l = values[0], .a = values[1], .b = values[2] };
        try record(writer, lab.toXYZ(white));
        try record(writer, lab.toLCHab());
        try record(writer, lab.toLCHab().toLab());
        const lab_alpha = color.CIELabAlpha.fromFloat4(.{ values[0], values[1], values[2], values[3] });
        try record(writer, lab_alpha.toXYZAlpha(white));
        try record(writer, lab_alpha.toLCHabAlpha().toLabAlpha());
        try record(writer, color.CIELuv.fromXYZ(xyz, white));
        const luv = color.CIELuv{ .l = values[0], .u = values[1], .v = values[2] };
        try record(writer, luv.toXYZ(white));
        try record(writer, luv.toLCHuv());
        try record(writer, luv.toLCHuv().toLuv());
        const luv_alpha = color.CIELuvAlpha.fromFloat4(.{ values[0], values[1], values[2], values[3] });
        try record(writer, luv_alpha.toXYZAlpha(white));
        try record(writer, luv_alpha.toLCHuvAlpha().toLuvAlpha());
        try record(writer, color.Oklab.fromXYZ(xyz));
        const oklab = color.Oklab{ .l = values[0], .a = values[1], .b = values[2] };
        try record(writer, oklab.toXYZ());
        try record(writer, oklab.toOkLCh());
        try record(writer, oklab.toOkLCh().toOklab());
        try record(writer, color.OklabAlpha.fromXYZAlpha(xyza));
        try record(writer, (color.OklabAlpha.fromFloat4(.{ values[0], values[1], values[2], values[3] })).toXYZAlpha());
        const matrix = @import("src/math.zig").float4x4.identity();
        const hsluv = color.HSLuv.fromCIELChuv(.{ .l = values[0], .c = values[1], .h = values[2] }, matrix);
        try record(writer, hsluv);
        try record(writer, hsluv.toCIELCHuv(matrix));
        const hsluva = color.HSLuvAlpha.fromCIELChuvAlpha(.{ .l = values[0], .c = values[1], .h = values[2], .alpha = values[3] }, matrix);
        try record(writer, hsluva.toCIELCHuvAlpha(matrix));
        try record(writer, color.HSLuvAlpha.fromFloat4(.{ values[0], values[1], values[2], values[3] }));
        try writer.writeByte('\n');
    }
}
