const std=@import("std");
const fixed=@import("src/utils.zig").FixedStorage;
const color=@import("src/color.zig");
const allocator=std.heap.page_allocator;
fn mix(hash: *u64,value: u64) void { hash.*=(hash.* ^ value) *% 1099511628211; }
fn run(comptime T: type,comptime capacity: usize,trap: bool,output: *std.Io.Writer) !void {
 var buffer=fixed(T,capacity){};
 if(trap) { buffer.resize(capacity+1);std.debug.print("UNEXPECTED\n",.{});return; }
 const bytes=std.mem.sliceAsBytes(&buffer.storage);
 for(bytes,0..) |*byte,i| byte.*=@truncate(i*37+11);
 for(0..capacity+1) |size| {
  buffer.resize(size);
  const borrowed=size==0 or buffer.data.ptr==&buffer.storage;
  const old=buffer.data;
  buffer.resize(0);
  if(size>0) { const old_bytes=std.mem.sliceAsBytes(old);old_bytes[old_bytes.len-1]^=0x5a; }
  buffer.resize(size);
  var active: u64=14695981039346656037;for(std.mem.sliceAsBytes(buffer.data)) |byte| mix(&active,byte);
  var hash: u64=14695981039346656037;for(bytes) |byte| mix(&hash,byte);
  try output.print("{d}:{d}:{d}|{}:{d}:{d}:{x:0>16}:{x:0>16}\n",.{@sizeOf(T),capacity,size,borrowed,old.len,buffer.data.len,active,hash});
 }
}
pub fn main() !void {
 const args=try std.process.argsAlloc(allocator);defer std.process.argsFree(allocator,args);
 var output=std.fs.File.stdout().writer(&.{});
 try run(u8,0,args.len>1,&output.interface);
 try run(u8,1,args.len>1,&output.interface);
 try run(u8,7,args.len>1,&output.interface);
 try run(u8,8,args.len>1,&output.interface);
 try run(u8,256,args.len>1,&output.interface);
 try run(u8,513,args.len>1,&output.interface);
 try run(u16,0,args.len>1,&output.interface);
 try run(u16,1,args.len>1,&output.interface);
 try run(u16,7,args.len>1,&output.interface);
 try run(u16,8,args.len>1,&output.interface);
 try run(u16,256,args.len>1,&output.interface);
 try run(u16,513,args.len>1,&output.interface);
 try run(color.Rgba32,0,args.len>1,&output.interface);
 try run(color.Rgba32,1,args.len>1,&output.interface);
 try run(color.Rgba32,7,args.len>1,&output.interface);
 try run(color.Rgba32,8,args.len>1,&output.interface);
 try run(color.Rgba32,256,args.len>1,&output.interface);
 try run(color.Rgba32,513,args.len>1,&output.interface);
}
