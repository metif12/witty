const std=@import("std");
const vaxis=@import("main.zig");
const Terminal=@import("widgets/terminal/Terminal.zig");
const Screen=@import("widgets/terminal/Screen.zig");
const Command=@import("widgets/terminal/Command.zig");
const a=std.heap.page_allocator;
fn unhex(alloc:std.mem.Allocator,text:[]const u8)![]u8{const b=try alloc.alloc(u8,text.len/2);_=try std.fmt.hexToBytes(b,text);return b;}
fn hex(out:*std.Io.Writer,b:[]const u8)!void{for(b)|byte|try out.print("{x:0>2}",.{byte});}
fn number(p:[][]const u8,i:usize)!u16{return std.fmt.parseInt(u16,p[i],10);}
fn color(value:vaxis.Color)u32{return switch(value){.default=>0,.index=>|v|0x1000000|@as(u32,v),.rgb=>|v|0x2000000|(@as(u32,v[0])<<16)|(@as(u32,v[1])<<8)|v[2]};}
fn style(out:*std.Io.Writer,value:vaxis.Style)!void{
 const flags=@as(u8,@intFromBool(value.bold))|(@as(u8,@intFromBool(value.dim))<<1)|(@as(u8,@intFromBool(value.italic))<<2)|(@as(u8,@intFromBool(value.blink))<<3)|(@as(u8,@intFromBool(value.reverse))<<4)|(@as(u8,@intFromBool(value.invisible))<<5)|(@as(u8,@intFromBool(value.strikethrough))<<6);
 try out.print("{d},{d},{d},{d},{d}",.{color(value.fg),color(value.bg),color(value.ul),@intFromEnum(value.ul_style),flags});
}
fn screen(out:*std.Io.Writer,s:Screen)!void{
 try out.print("{d},{d}/{d},{d},{d},{d}/{d},{d},{d},{d},{d}/{d}/",.{s.width,s.height,s.scrolling_region.top,s.scrolling_region.bottom,s.scrolling_region.left,s.scrolling_region.right,s.cursor.col,s.cursor.row,@intFromBool(s.cursor.pending_wrap),@intFromEnum(s.cursor.shape),@intFromBool(s.cursor.visible),@as(u5,@bitCast(s.csi_u_flags))});
 try style(out,s.cursor.style);try out.writeByte(';');
 for(s.buf)|cell|{try hex(out,cell.char.items);try out.print("/{d},{d},{d}/",.{cell.width,@intFromBool(cell.wrapped),@intFromBool(cell.dirty)});try style(out,cell.style);try out.writeByte('/');try hex(out,cell.uri.items);try out.writeByte('/');try hex(out,cell.uri_id.items);try out.writeByte(';');}
}
fn seed(s:*Screen,offset:usize)!void{
 s.cursor.uri=.empty;s.cursor.uri_id=.empty;
 for(s.buf,0..)|*cell,i|{cell.char.clearRetainingCapacity();try cell.char.appendSlice(s.allocator,try std.fmt.allocPrint(s.allocator,"{d}",.{i+offset}));cell.dirty=false;cell.style=.{.bg=.{.index=@intCast(i%8)},.bold=i%2==0};}
}
fn runCase(p:[][]const u8,out:*std.Io.Writer,input_path:[]const u8,response_path:[]const u8)!void{
 var arena=std.heap.ArenaAllocator.init(a);defer arena.deinit();const alloc=arena.allocator();
 const data=try unhex(alloc,p[0]);try std.fs.cwd().writeFile(.{.sub_path=input_path,.data=data});
 const input=try std.fs.cwd().openFile(input_path,.{});defer input.close();
 const output=try std.fs.cwd().createFile(response_path,.{.read=true});defer output.close();
 var env=std.process.EnvMap.init(alloc);var write_buf:[16]u8=undefined;
 const w=try number(p,1);const h=try number(p,2);
 var t=Terminal{.allocator=alloc,.scrollback_size=0,.pty=.{.pty=input,.tty=.{.handle=-1}},.pty_writer=output.writerStreaming(&write_buf),.cmd=Command{.argv=&.{"true"},.working_directory=null,.env_map=&env,.pty=.{.pty=input,.tty=.{.handle=-1}}},.front_screen=try Screen.init(alloc,w,h),.back_screen_pri=try Screen.init(alloc,w,h),.back_screen_alt=try Screen.init(alloc,w,h),.tab_stops=try .initCapacity(alloc,128),.title=try .initCapacity(alloc,128),.working_directory=try .initCapacity(alloc,128)};
 try seed(&t.front_screen,200);try seed(&t.back_screen_pri,0);try seed(&t.back_screen_alt,100);
 t.back_screen=&t.back_screen_pri;t.back_screen.cursor.col=try number(p,3);t.back_screen.cursor.row=try number(p,4);t.back_screen.cursor.pending_wrap=true;
 const modes=try std.fmt.parseInt(u8,p[5],10);t.mode.origin=modes&1!=0;t.mode.autowrap=modes&2!=0;t.mode.cursor=modes&4!=0;t.mode.sync=modes&8!=0;
 t.dirty=std.mem.eql(u8,p[6],"1");t.should_quit=std.mem.eql(u8,p[8],"1");t.last_printed=try unhex(alloc,p[7]);
 var col:u16=0;while(col<w):(col+=8)try t.tab_stops.append(alloc,col);
 try t.title.appendSlice(alloc,"initial");try t.working_directory.appendSlice(alloc,"before");
 var result:[]const u8="ok";t.audit_run() catch |err|{result=@errorName(err);};
 try t.pty_writer.interface.flush();try output.seekTo(0);const reply=try output.readToEndAlloc(alloc,4096);
 const unlocked=t.back_mutex.tryLock();if(unlocked)t.back_mutex.unlock();
 try out.print("{s}|{d}{d}{d}{d}/{d}/{d}/{d}/{d}/{d}|",.{result,@intFromBool(t.mode.origin),@intFromBool(t.mode.autowrap),@intFromBool(t.mode.cursor),@intFromBool(t.mode.sync),@intFromBool(t.dirty),@intFromBool(t.should_quit),@intFromBool(t.back_screen==&t.back_screen_alt),@intFromBool(unlocked),try input.getPos()});
 try hex(out,t.title.items);try out.writeByte('|');try hex(out,t.working_directory.items);try out.writeByte('|');try hex(out,t.last_printed);try out.writeByte('|');try hex(out,reply);try out.writeByte('|');
 for(t.tab_stops.items)|stop|try out.print("{d},",.{stop});try out.writeByte('|');
 while(t.tryEvent())|event|{switch(event){.redraw=>try out.writeByte('r'),.bell=>try out.writeByte('b'),.exited=>try out.writeByte('e'),.title_change=>|bytes|{try out.writeByte('t');try hex(out,bytes);},.pwd_change=>|bytes|{try out.writeByte('p');try hex(out,bytes);}}try out.writeByte(',');}
 try out.writeByte('|');try screen(out,t.front_screen);try out.writeByte('|');try screen(out,t.back_screen_pri);try out.writeByte('|');try screen(out,t.back_screen_alt);try out.writeByte('\n');
}
pub fn main()!void{
 const args=try std.process.argsAlloc(a);const text=try std.fs.cwd().readFileAlloc(a,args[1],16*1024*1024);
 var out=std.Io.Writer.Allocating.init(a);defer out.deinit();var lines=std.mem.tokenizeScalar(u8,text,'\n');
 while(lines.next())|line|{var iter=std.mem.splitScalar(u8,line,'|');var parts:std.ArrayList([]const u8)=.empty;while(iter.next())|p|try parts.append(a,p);try runCase(parts.items,&out.writer,args[2],args[3]);}
 _=try std.posix.write(1,out.written());
}
