const std = @import("std");
const r = @import("src/formats/png/reader.zig");
const color = @import("src/color.zig");

pub fn main() !void {
    var out = std.fs.File.stdout().writer(&.{});
    for ([_]u16{ 0, 1, 7, 65535 }) |seed| {
        var gray = r.TrnsProcessor{ .trns_data = .{ .gray = seed } };
        const copied = gray;
        gray.trns_data.gray = 33;
        try out.interface.print("G|{d}|{d}|{d}\n", .{ seed, gray.trns_data.gray, copied.trns_data.gray });
        var rgb = r.TrnsProcessor{ .trns_data = .{ .rgb = color.Rgb48.from.rgb(seed, 7, 65535) } };
        const rgb_copy = rgb;
        rgb.trns_data.rgb.r = 33;
        try out.interface.print("R|{d}|{d}|{d}|{d}\n", .{ seed, rgb.trns_data.rgb.r, rgb_copy.trns_data.rgb.r, rgb_copy.trns_data.rgb.b });
        var alpha = [_]u8{ @truncate(seed), 17 };
        var indexed = r.TrnsProcessor{ .trns_data = .{ .index_alpha = &alpha } };
        const index_copy = indexed;
        indexed.trns_data.index_alpha = indexed.trns_data.index_alpha[0..1];
        alpha[0] = 33;
        try out.interface.print("I|{d}|{d}|{d}|{d}\n", .{ seed, indexed.trns_data.index_alpha.len, index_copy.trns_data.index_alpha.len, index_copy.trns_data.index_alpha[0] });
    }
}
