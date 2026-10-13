const std = @import("std");
const p = @import("src/io.zig");
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_reader: ?*p.ReadStream = null;
var observed_writer: ?*p.WriteStream = null;
var observed_rb: ?*const p.BitReader(.big) = null;
var observed_rl: ?*const p.BitReader(.little) = null;
var observed_wb: ?*const p.BitWriter(.big) = null;
var observed_wl: ?*const p.BitWriter(.little) = null;
var observed_input: []const u8 = &.{};
var observed_output: []const u8 = &.{};
var observed_index: usize = 0;
var observed_count: u16 = 777;
fn state(out: *W) !void {
 var bits: u8 = 0; var count: u4 = 0;
 if (observed_rb) |b| {bits=b.bits;count=b.count;}
 if (observed_rl) |b| {bits=b.bits;count=b.count;}
 if (observed_wb) |b| {bits=b.bits;count=b.count;}
 if (observed_wl) |b| {bits=b.bits;count=b.count;}
 try out.print("{d}|{d}|{d}|{d}:{d}|{d}|{x}|{x}", .{observed_index,observed_reader.?.getPos(),observed_writer.?.getPos(),bits,count,observed_count,observed_input,observed_output});
}
fn observe(message: []const u8, address: ?usize) noreturn {
 if (observed_path) |path| {
  if (std.fs.cwd().createFile(path,.{})) |file| {
   defer file.close();var buffer: [4096]u8=undefined;var writer=file.writer(&buffer);
   state(&writer.interface) catch {};writer.interface.flush() catch {};
  } else |_| {}
 }
 std.debug.defaultPanic(message,address);
}
fn number(text: []const u8) !u64 {return std.fmt.parseInt(u64,text,10);}
fn word(value: anytype) u64 {
 const U=std.meta.Int(.unsigned,@bitSizeOf(@TypeOf(value)));
 return @as(U,@bitCast(value));
}
fn readAction(comptime endian: std.builtin.Endian, comptime T: type, bits: *p.BitReader(endian), action: []const u8, out: *W) !void {
 if (std.mem.eql(u8,action,"a")) {bits.alignToByte();try out.writeAll("ok");return;}
 if (action[0]=='s') {try observed_reader.?.seekTo(try number(action[1..]));try out.writeAll("ok");return;}
 const num: u16=@intCast(try number(action[1..]));
 switch (action[0]) {
  't' => {const value,const count=try bits.readBitsTuple(T,num);try out.print("ok:{d}:{d}", .{word(value),count});},
  'r' => {const value=try bits.readBits(T,num,&observed_count);try out.print("ok:{d}:{d}", .{word(value),observed_count});},
  'c' => {var copied=bits.*;const value,const count=try copied.readBitsTuple(T,num);try out.print("copy:{d}:{d}:{d}:{d}", .{word(value),count,copied.bits,copied.count});},
  else => {const value=try bits.readBitsNoEof(T,num);try out.print("ok:{d}", .{word(value)});},
 }
}
fn writeAction(comptime endian: std.builtin.Endian, comptime T: type, bits: *p.BitWriter(endian), action: []const u8, out: *W) !void {
 if (std.mem.eql(u8,action,"f")) {try bits.flushBits();try out.writeAll("ok");return;}
 if (action[0]=='s') {try observed_writer.?.seekTo(try number(action[1..]));try out.writeAll("ok");return;}
 var parts=std.mem.splitScalar(u8,action[1..],':');const num: u16=@intCast(try number(parts.next().?));
 const U=std.meta.Int(.unsigned,@bitSizeOf(T));const value: T=@bitCast(@as(U,@truncate(try number(parts.next().?))));
 if (action[0]=='c') {var copied=bits.*;try copied.writeBits(value,num);try out.print("copy:{d}:{d}", .{copied.bits,copied.count});return;}
 try bits.writeBits(value,num);try out.writeAll("ok");
}
fn run(comptime endian: std.builtin.Endian, comptime T: type, f: [9][]const u8, out: *W) !void {
 const input=try a.alloc(u8,f[6].len/2);defer a.free(input);_=try std.fmt.hexToBytes(input,f[6]);
 const output=try a.alloc(u8,try number(f[5]));defer a.free(output);@memset(output,0xa5);
 var reader=p.ReadStream.initMemory(input);var writer=p.WriteStream.initMemory(output);
 observed_reader=&reader;observed_writer=&writer;observed_input=input;observed_output=output;
 var actions=std.mem.splitScalar(u8,f[8],',');var index: usize=0;
 if (std.mem.eql(u8,f[2],"0")) {
  if ((try number(f[7]))>0) try reader.seekTo(try number(f[7]));
  var bits=p.BitReader(endian){.reader=reader.reader(),.bits=@intCast(try number(f[3])),.count=@intCast(try number(f[4]))};
  if (endian==.big) observed_rb=&bits else observed_rl=&bits;
  while (actions.next()) |action| {
   observed_index=index;observed_count=777;if (index>0) try out.writeByte('~');
   if (std.mem.eql(u8,action,"m")) {if (input.len>0) input[0]^=85;try out.writeAll("ok");}
   else readAction(endian,T,&bits,action,out) catch |err| {try out.writeAll(@errorName(err));};
   try out.writeByte('|');try state(out);index+=1;
  }
 } else {
  if ((try number(f[7]))>0) try writer.seekTo(try number(f[7]));
  var bits=p.BitWriter(endian){.writer=writer.writer(),.bits=@intCast(try number(f[3])),.count=@intCast(try number(f[4]))};
  if (endian==.big) observed_wb=&bits else observed_wl=&bits;
  while (actions.next()) |action| {
   observed_index=index;observed_count=777;if (index>0) try out.writeByte('~');
   writeAction(endian,T,&bits,action,out) catch |err| {try out.writeAll(@errorName(err));};
   try out.writeByte('|');try state(out);index+=1;
  }
 }
 try out.writeByte('\n');
}
fn dispatch(comptime endian: std.builtin.Endian, f: [9][]const u8, out: *W) !void {
 switch (try number(f[1])) {
  0, 12 => try run(endian,u8,f,out),
  1, 13 => try run(endian,u16,f,out),
  2, 14 => try run(endian,u32,f,out),
  3, 15 => try run(endian,u64,f,out),
  4, 16 => try run(endian,i8,f,out),
  5, 17 => try run(endian,i16,f,out),
  6, 18 => try run(endian,i32,f,out),
  7, 19 => try run(endian,i64,f,out),
  8, 20 => try run(endian,usize,f,out),
  9, 21 => try run(endian,isize,f,out),
  10, 22 => try run(endian,f32,f,out),
  11, 23 => try run(endian,f64,f,out),
  24, 25 => try run(endian,bool,f,out),
  else => unreachable,
 }
}
fn lineCase(line: []const u8, out: *W) !void {
 var parts=std.mem.splitScalar(u8,line,'|');var f: [9][]const u8=undefined;for (&f) |*field| field.*=parts.next().?;
 observed_index=0;observed_count=777;observed_rb=null;observed_rl=null;observed_wb=null;observed_wl=null;
 if ((try number(f[0]))%2==0) try dispatch(.little,f,out) else try dispatch(.big,f,out);
}
pub fn main() !void {
 const args=try std.process.argsAlloc(a);defer std.process.argsFree(a,args);
 var buffer: [8192]u8=undefined;var writer=std.fs.File.stdout().writer(&buffer);const out=&writer.interface;
 if (std.mem.eql(u8,args[1],"--corpus")) {
  const text=try std.fs.cwd().readFileAlloc(a,args[2],1073741824);defer a.free(text);
  var lines=std.mem.splitScalar(u8,text,'\n');while (lines.next()) |line| {if (line.len>0) try lineCase(line,out);}
 } else {observed_path=args[2];try lineCase(args[3],out);}
 try out.flush();
}
