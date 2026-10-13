const std=@import("std");
const p=@import("src/compressions/ccitt.zig");
const io=@import("src/io.zig");
const Code=@TypeOf(p.white_terminating_codes[0]);
const a=std.heap.page_allocator;
const W=std.Io.Writer;
pub const panic=std.debug.FullPanic(observe);
var observed_path: ?[]const u8=null;
var observed_reader: ?*const io.ReadStream=null;
var observed_writer: ?*const io.WriteStream=null;
var observed_codec: ?*const p.Decoder=null;
var observed_input: []const u8=&.{};
var observed_output: []const u8=&.{};
var observed_segment: usize=0;
fn codecState(codec: *const p.Decoder,out: *W) !void {
 try out.print("{d}:{d}:{d}:{d}:{d}", .{@intFromEnum(codec.current_color),@intFromBool(codec.should_reverse),codec.width,codec.num_rows,codec.white_value});
}
fn state(out: *W) !void {
 try out.print("{d}|{d}|{d}|", .{observed_segment,observed_reader.?.getPos(),observed_writer.?.getPos()});
 if (observed_codec) |codec| try codecState(codec,out) else try out.writeByte('-');
 try out.print("|{x}|{x}", .{observed_input,observed_output});
}
fn observe(message: []const u8,address: ?usize) noreturn {
 if (observed_path) |path| {
  if (std.fs.cwd().createFile(path,.{})) |file| {
   defer file.close();var bytes:[4096]u8=undefined;var writer=file.writer(&bytes);
   state(&writer.interface) catch {};writer.interface.flush() catch {};
  } else |_| {}
 }
 std.debug.defaultPanic(message,address);
}
fn num(f:[12][]const u8,index:usize) !usize {return std.fmt.parseInt(usize,f[index],10);}
fn codeState(code:Code,out:*W) !void {try out.print("{d}:{d}:{d}", .{code.run_length,code.code,code.code_length});}
fn tables(out:*W) !void {
 var hash:u64=14695981039346656037;var count:usize=0;
 inline for (.{p.white_terminating_codes,p.black_terminating_codes,p.white_make_up_codes,p.black_make_up_codes,p.additional_make_up_codes}) |table| {
  for (table) |item| {
   for ([_]u8{@truncate(item.run_length),@truncate(item.run_length>>8),@truncate(item.code),@truncate(item.code>>8),item.code_length}) |byte| hash=(hash^byte)*%1099511628211;
   count+=1;
  }
 }
 try out.print("{d}:{d}\n", .{count,hash});
}
fn run(f:[12][]const u8,out:*W) !void {
 if ((try num(f,0))==4) {
  var original=Code{.run_length=@intCast(try num(f,6)),.code=@intCast(try num(f,1)),.code_length=@intCast(try num(f,7))};
  var copied=original;copied.run_length^=65535;copied.code^=43690;copied.code_length^=255;
  try codeState(original,out);try out.writeByte('|');try codeState(copied,out);try out.writeByte('|');
  original.code^=21845;
  try codeState(original,out);try out.writeByte('|');try codeState(copied,out);try out.writeByte('\n');return;
 }
 if ((try num(f,0))==5) {try tables(out);return;}
 if ((try num(f,0))==7) {
  var original=p.Decoder{};var copied=original;
  copied.width=try num(f,1);copied.num_rows=try num(f,2);copied.white_value=@intCast(try num(f,3));
  copied.current_color=@enumFromInt(try num(f,4));copied.should_reverse=(try num(f,5))==1;
  try codecState(&original,out);try out.writeByte('|');try codecState(&copied,out);try out.writeByte('|');
  original.width=17;
  try codecState(&original,out);try out.writeByte('|');try codecState(&copied,out);try out.writeByte('\n');return;
 }
 const output=try a.alloc(u8,try num(f,8));defer a.free(output);@memset(output,0xa5);
 var writer=io.WriteStream.initMemory(output);var reader=io.ReadStream.initMemory("");
 observed_reader=&reader;observed_writer=&writer;observed_output=output;
 if ((try num(f,11))>0) try writer.seekTo(try num(f,11));
 var codec=try p.Decoder.init(try num(f,1),try num(f,2),@intCast(try num(f,3)));
 observed_codec=&codec;
 if ((try num(f,0))==6) {try out.writeAll("ok|");try state(out);try out.writeByte('\n');return;}
 codec.current_color=@enumFromInt(try num(f,4));codec.should_reverse=(try num(f,5))==1;
 const op=try num(f,0);
 if (op!=3) {
  const code:u13=@intCast(try num(f,6));const length:u8=@intCast(try num(f,7));
  const result=switch(op) {0=>codec.get_make_up_code(code,length),1=>codec.get_terminating_code(code,length),else=>codec.get_run_length(code,length)};
  if (result) |value| try out.print("{d}", .{value}) else try out.writeByte('-');
  try out.writeByte('|');try state(out);try out.writeByte('\n');return;
 }
 var parts=std.mem.splitScalar(u8,f[9],',');var index:usize=0;
 while (parts.next()) |part| {
  const data=try a.alloc(u8,part.len/2);defer a.free(data);_=try std.fmt.hexToBytes(data,part);
  reader=io.ReadStream.initMemory(data);
  if (index==0 and (try num(f,10))>0) _=try reader.reader().take(try num(f,10));
  observed_input=data;observed_segment=index;
  if (index>0) try out.writeByte('~');
  codec.decode(reader.reader(),writer.writer()) catch |err| {try out.print("{s}|", .{@errorName(err)});try state(out);index+=1;continue;};
  try out.writeAll("ok|");try state(out);index+=1;
 }
 try out.writeByte('\n');
}
fn lineCase(line:[]const u8,out:*W) !void {
 var parts=std.mem.splitScalar(u8,line,'|');var f:[12][]const u8=undefined;for (&f) |*field| field.*=parts.next().?;
 observed_codec=null;observed_input=&.{};observed_segment=0;
 try run(f,out);
}
pub fn main() !void {
 const args=try std.process.argsAlloc(a);defer std.process.argsFree(a,args);
 var bytes:[8192]u8=undefined;var writer=std.fs.File.stdout().writer(&bytes);const out=&writer.interface;
 if (std.mem.eql(u8,args[1],"--corpus")) {
  const text=try std.fs.cwd().readFileAlloc(a,args[2],1073741824);defer a.free(text);
  var lines=std.mem.splitScalar(u8,text,'\n');while (lines.next()) |line| {if (line.len>0) try lineCase(line,out);}
 } else {observed_path=args[2];try lineCase(args[3],out);}
 try out.flush();
}
