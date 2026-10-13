const std=@import("std");const color=@import("src/color.zig");const Q=@import("src/OctTreeQuantizer.zig");
const Node=@TypeOf(@as(Q,undefined).root_node);
const Context=@typeInfo(@typeInfo(@TypeOf(Node.makePalette)).@"fn".params[1].type.?).pointer.child;
const a=std.heap.page_allocator;const W=std.Io.Writer;
pub const panic=std.debug.FullPanic(observe);
var observed_path:?[]const u8=null;var observed_q:?*const Q=null;var observed_nodes:[5]*const Node=undefined;
var observed_context:?*const Context=null;var observed_palette:[]const color.Rgba32=&.{};
fn id(node:?*const Node) u64 {
 const ptr=node orelse return 0;
 for (observed_nodes,0..) |known,index| {if(ptr==known)return index+1;}
 @panic("OBSERVER ERROR: unknown node");
}
fn mix(current:u64,value:u64) u64 {
 var hash=current;for(0..8) |shift| {hash=(hash^@as(u8,@truncate(value>>@as(u6,@intCast(shift*8)))))*%1099511628211;}
 return hash;
}
fn nodeHash(node:*const Node,current:u64) u64 {
 var hash=current;for([_]u64{node.red,node.green,node.blue,node.reference_count,node.palette_index}) |value| {hash=mix(hash,value);}
 for(node.children) |child| {hash=mix(hash,id(child));}
 return mix(hash,id(node.level_next));
}
fn state(out:*W) !void {
 var hash:u64=14695981039346656037;for(observed_nodes) |node| {hash=nodeHash(node,hash);}
 for(observed_q.?.levels) |level| {hash=mix(hash,id(level));}
 try out.print("{d}:{d}|{d}|", .{observed_context.?.palette_index,observed_context.?.color_count,hash});
 for(observed_palette) |c| {try out.print("{x:0>2}{x:0>2}{x:0>2}{x:0>2}", .{c.r,c.g,c.b,c.a});}
}
fn observe(message:[]const u8,address:?usize) noreturn {
 if(observed_path) |path| {if(std.fs.cwd().createFile(path,.{})) |file| {
  defer file.close();var buffer:[4096]u8=undefined;var writer=file.writer(&buffer);state(&writer.interface) catch {};writer.interface.flush() catch {};
 } else |_| {}}
 std.debug.defaultPanic(message,address);
}
fn number(text:[]const u8) !u32 {return std.fmt.parseInt(u32,text,10);}
fn scalar(node:*const Node,out:*W) !void {try out.print("{d}:{d}:{d}:{d}:{d}", .{node.red,node.green,node.blue,node.reference_count,node.palette_index});}
fn lineCase(line:[]const u8,out:*W) !void {
 var fields=std.mem.splitScalar(u8,line,'|');var f:[12][]const u8=undefined;for(&f) |*field| field.*=fields.next().?;
 var q=Q{.area_allocator=std.heap.ArenaAllocator.init(a)};defer q.deinit();q.root_node.init(0,&q);
 q.root_node.red=try number(f[2]);q.root_node.green=try number(f[3]);q.root_node.blue=try number(f[4]);q.root_node.reference_count=try number(f[5]);q.root_node.palette_index=try number(f[6]);
 var a1=Node{.red=2,.green=10,.blue=20,.reference_count=1,.palette_index=5};var a2=Node{.red=3,.green=20,.blue=30,.reference_count=1,.palette_index=7};
 var a3=Node{.red=4,.green=30,.blue=40,.reference_count=1,.palette_index=9};var a4=Node{};
 q.levels[2]=&a2;a2.level_next=&a3;
 const graph=try number(f[10]);
 if(graph==1){q.root_node.children[0]=&a1;}
 if(graph==2){q.root_node.children[0]=&a1;q.root_node.children[7]=&a2;}
 if(graph==3){q.root_node.children[0]=&a4;a4.children[0]=&a1;a4.children[7]=&a2;}
 if(graph==4){q.root_node.children[0]=&a1;q.root_node.children[7]=&a1;}
 if(graph==5 or graph==6){q.root_node.children[0]=&a4;q.levels[7]=&a4;if(graph==6){a1.reference_count=0;a2.reference_count=0;a4.children[0]=&a1;a4.children[7]=&a2;}}
 const palette=try a.alloc(color.Rgba32,try number(f[9]));defer a.free(palette);@memset(palette,color.Rgba32.from.rgb(17,18,19));
 var context=Context{.palette=palette,.palette_index=try number(f[8]),.color_count=try number(f[7])};
 observed_q=&q;observed_nodes=.{&q.root_node,&a1,&a2,&a3,&a4};observed_context=&context;observed_palette=palette;
 var parts=std.mem.splitScalar(u8,f[11],':');const c=color.Rgb24.from.rgb(@intCast(try number(parts.next().?)),@intCast(try number(parts.next().?)),@intCast(try number(parts.next().?)));
 const level=try std.fmt.parseInt(i32,f[1],10);const op=try number(f[0]);
 switch(op){
  0=>{const value=q.root_node.getColor();try out.print("color:{d}:{d}:{d}:{d}", .{value.r,value.g,value.b,value.a});},
  1=>{try q.root_node.addColor(c,level,&q);try out.writeAll("ok");},
  2=>{q.addLevelNode(level,&a1);try out.writeAll("ok");},
  3=>{q.root_node.init(level,&q);try out.writeAll("ok");},
  4=>{try out.print("removed:{d}", .{q.root_node.removeLeaves()});},
  5=>{q.root_node.makePalette(&context);try out.writeAll("ok");},
  6=>{if(q.root_node.getPaletteIndex(c,level)) |index| {try out.print("index:{d}", .{index});} else |err| {try out.writeAll(@errorName(err));}},
  7=>{const view=q.makePalette(try number(f[7]),palette);try out.print("palette:{d}", .{view.len});if(view.len>0)view[0].r^=85;},
  8=>{var copied=q;copied.root_node.red^=0x55aa55aa;copied.root_node.palette_index^=0xffffffff;if(copied.root_node.children[0]) |child| {child.green^=85;}try out.writeAll("copy:");try scalar(&q.root_node,out);try out.writeByte(':');try scalar(&copied.root_node,out);},
  9=>{var copied=q.root_node;copied.blue^=0x55aa55aa;copied.palette_index^=0xffffffff;if(copied.children[0]) |child| {child.red^=85;}try out.writeAll("copy:");try scalar(&q.root_node,out);try out.writeByte(':');try scalar(&copied,out);},
  10=>{var copied=context;copied.palette_index^=0xffffffff;copied.color_count^=0x55aa55aa;if(copied.palette.len>0)copied.palette[0].b^=85;try out.print("copy:{d}:{d}", .{copied.palette_index,copied.color_count});},
  11=>{var factory=Q.init(a);defer factory.deinit();var count:usize=0;for(factory.levels[1..]) |ptr| {if(ptr!=null)count+=1;}try out.writeAll("factory:");try scalar(&factory.root_node,out);try out.print(":{d}", .{count});},
  else=>unreachable,
 }
 try out.writeByte('|');try state(out);try out.writeByte('\n');
}
pub fn main() !void {
 const args=try std.process.argsAlloc(a);defer std.process.argsFree(a,args);var buffer:[8192]u8=undefined;var writer=std.fs.File.stdout().writer(&buffer);const out=&writer.interface;
 if(std.mem.eql(u8,args[1],"--corpus")){const text=try std.fs.cwd().readFileAlloc(a,args[2],1073741824);defer a.free(text);var lines=std.mem.splitScalar(u8,text,'\n');while(lines.next()) |line| {if(line.len>0)try lineCase(line,out);}}
 else{observed_path=args[2];try lineCase(args[3],out);}
 try out.flush();
}
