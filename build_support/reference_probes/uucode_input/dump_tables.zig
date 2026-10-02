const std=@import("std"); const tables=@import("tables").tables.buildtime;
pub fn main() !void {
 var buf:[4096]u8=undefined; var out=std.fs.File.stdout().writer(&buf);
 for(tables.stage1) |index| {try out.interface.writeInt(u16,index,.little);}
 for(tables.stage2) |data| {const bits:u16=@as(u16,data.width) | (@as(u16,@intFromEnum(data.grapheme_break_no_control))<<2) | (@as(u16,@intFromBool(data.is_emoji_vs_base))<<7) | (@as(u16,@intFromBool(data.is_symbol))<<8); try out.interface.writeInt(u16,bits,.little);}
 try out.interface.flush();
}
