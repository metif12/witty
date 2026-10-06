const std = @import("std");
const v = @import("vaxis");
const B = v.Window.BorderOptions;

pub fn main() !void {
    var glyphs: B.Glyphs = .{ .custom = .{ "0", "1", "2", "3", "4", "5" } };
    const copied = glyphs;
    glyphs.custom[0] = "new";
    var where: @FieldType(B, "where") = .{ .other = .{} };
    const copied_where = where;
    where.other.top = true;
    var buffer: [256]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&buffer);
    try stdout.interface.print("{s}\n{s}\n{d}\n{d}\n", .{ glyphs.custom[0], copied.custom[0], @intFromBool(where.other.top), @intFromBool(copied_where.other.top) });
    try stdout.interface.flush();
}
