const std = @import("std");
const Enum = @import("lib/enum.zig").Enum;
const Struct = @import("lib/struct.zig").Struct;
const TaggedUnion = @import("lib/union.zig").TaggedUnion;
const CTag = Enum(.c, &.{ "a", null, "b" });
const VTag = Enum(.zig, &.{ "a", null, "b" });
const NativeNested = struct {
    value: u32 = 7,
    pub const C = Struct(.c, struct { value: u32 = 7 });
    pub fn cval(self: @This()) C { return .{ .value = self.value + 1 }; }
};
const Aligned = Struct(.c, struct { prefix: u8, value: u32 align(8) });
const NativeOnly = TaggedUnion(.zig, union(CTag) { a: u32, b: NativeNested }, u64);
const U = TaggedUnion(.c, union(CTag) { a: u32, b: NativeNested }, u64);
pub fn main() void {
    std.debug.assert(@sizeOf(Enum(.c, &.{ null })) == 4);
    std.debug.assert(@sizeOf(Aligned) == 16);
    std.debug.assert(@alignOf(Aligned) == 8);
    std.debug.assert(@offsetOf(Aligned, "value") == 8);
    std.debug.assert(@sizeOf(NativeOnly.C) == 0);
    std.debug.assert(@sizeOf(NativeOnly.CValue) == 0);
    const tuple = Struct(.zig, struct { u8, u64 });
    const Comptime = Struct(.zig, struct { value: u32 = 7, comptime constant: u8 = 9 });
    const plain = U.cval(.{ .a = 42 });
    const nested = U.cval(.{ .b = .{ .value = 99 } });
    const NativeValue = U.Value(.b);
    std.debug.print("enum={d}/{d}/{d} native_bits={d}\n", .{ @intFromEnum(CTag.a), @intFromEnum(CTag.b), @intFromEnum(VTag.b), @typeInfo(@typeInfo(VTag).@"enum".tag_type).int.bits });
    std.debug.print("struct={d}/{d} defaults={d}/{d} tuple={d}/{any}\n", .{ @sizeOf(NativeNested.C), @sizeOf(Comptime), (Comptime{}).value, (Comptime{}).constant, @sizeOf(tuple), @typeInfo(tuple).@"struct".is_tuple });
    std.debug.print("union={d}/{d} values={d}/{d} native={d}\n", .{ @sizeOf(U.CValue), @sizeOf(U.C), plain.value.a, nested.value.b.value, (NativeValue{ .value = 7 }).value });
}
