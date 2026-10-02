const std = @import("std");
fn hash(key: anytype) u64 {return std.hash_map.AutoContext(@TypeOf(key)).hash(.{},key);}
const Payload = struct {value:u32};
const Tagged = union(enum) {empty:struct{},payload:Payload};
const Padded = struct {small:u8,large:u32};
const Unique = extern struct {first:u32,second:u16,third:u8,fourth:u8};
const Tag = enum(u8) {zero=0,high=127};
pub fn main() void {
    const value:u32 = 0x11223344;
    const error_id:anyerror = @errorFromInt(1);
    const present:?u32 = value;
    const absent:?u32 = null;
    const successful:anyerror!u32 = value;
    const failed:anyerror!u32 = error_id;
    const empty:Tagged = .{.empty=.{}};
    const tagged:Tagged = .{.payload=.{.value=value}};
    const null_pointer:?*const u32 = null;
    const pointer:?*const u32 = &value;
    std.debug.print("scalar={d}\nfixed={d}\npresent={d}\nabsent={d}\nempty={d}\ntagged={d}\nerror={d}\nsuccess={d}\nfailure={d}\nnull_pointer={d}\npadded={d}\nenum={d}\nbool={d}\nsigned={d}\n", .{
        hash(value),hash([2]u16{0x1122,0x3344}),hash(present),hash(absent),hash(empty),hash(tagged),
        hash(error_id),hash(successful),hash(failed),hash(null_pointer),hash(Padded{.small=7,.large=42}),hash(Tag.high),hash(true),hash(@as(i16,-7)),
    });
    std.debug.print("unique={d}\n", .{hash(Unique{.first=0x11223344,.second=0x5566,.third=0x77,.fourth=0x88})});
    std.debug.assert(std.meta.hasUniqueRepresentation(Unique));
    std.debug.assert(hash(&value)==hash(@intFromPtr(&value)));
    std.debug.assert(hash(pointer)==hash(@intFromPtr(&value)));
    std.debug.assert(std.hash_map.AutoContext(anyerror).eql(.{},error_id,@errorFromInt(1)));
    const a:[]const u8 = "same";
    const b:[]const u8 = "same";
    const optional_slice:?[]const u8 = a;
    var hasher=std.hash.Wyhash.init(0);
    std.hash.autoHashStrat(&hasher,@intFromPtr(a.ptr),.Shallow);
    std.hash.autoHashStrat(&hasher,a.len,.Shallow);
    std.debug.assert(hash(optional_slice)==hasher.final());
    std.debug.assert(std.hash_map.AutoContext(?[]const u8).eql(.{},optional_slice,b));
}
