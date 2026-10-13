const c = @import("src/color.zig");
pub const Encoded = struct {
    bits: u32,
    pub const from = struct {
        pub fn color(value: c.Colorf32) Encoded {
            return .{ .bits = @as(u32, @intFromBool(value.r == 1)) | (@as(u32, @intFromBool(value.g == 1)) << 1) | (@as(u32, @intFromBool(value.b == 1)) << 2) | (@as(u32, @intFromBool(value.a == 1)) << 3) | 0x12340000 };
        }
    };
};
pub const Swizzled = struct {
    r: u16,
    g: u16,
    b: u16,
    a: u16,
    pub const from = struct {
        pub fn color(value: c.Colorf32) Swizzled {
            return .{ .r = @intFromFloat(value.g * 65535), .g = @intFromFloat(value.b * 65535), .b = @intFromFloat(value.r * 65535), .a = 17 };
        }
    };
};
pub const Snapshot = struct {
    channel_bits: [4]u32,
    pub const from = struct {
        pub fn color(value: c.Colorf32) Snapshot {
            return .{ .channel_bits = .{ @bitCast(value.r), @bitCast(value.g), @bitCast(value.b), @bitCast(value.a) } };
        }
    };
};
pub const Marked = struct {
    tag: i32,
    is_opaque: bool,
    sentinel: f32,
    pub const from = struct {
        pub fn color(value: c.Colorf32) Marked {
            return .{ .tag = @as(i32, @intFromFloat(value.r * 2 + value.g * 3 + value.b * 5)) - 15, .is_opaque = value.a == 1, .sentinel = @bitCast(@as(u32, if (value.r == 1) 0x7fc01234 else 0x80000000)) };
        }
    };
};
