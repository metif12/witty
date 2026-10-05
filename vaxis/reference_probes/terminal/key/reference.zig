const std=@import("std");
const vaxis=@import("main.zig");
const encoder=@import("widgets/terminal/key.zig");
const allocator=std.heap.page_allocator;
fn unexpected(message:[]const u8) void {std.debug.print("{s}: {s}\n",.{"UN"++"EXPECTED",message});}
pub fn main() !void {
    const args=try std.process.argsAlloc(allocator);
    if(std.mem.startsWith(u8,args[1],"trap")) {
        var storage:[16]u8=undefined; var writer=std.Io.Writer.fixed(&storage);
        const bits=try std.fmt.parseInt(u5,args[1][4..],10);
        encoder.encode(&writer,.{.codepoint='a',.text=""},true,@bitCast(bits)) catch |err| {unexpected(@errorName(err));return;}; unexpected("returned");return;
    }
    const text=try std.fs.cwd().readFileAlloc(allocator,args[1],64*1024*1024);
    var buffer:[4096]u8=undefined; var out=std.fs.File.stdout().writer(&buffer);
    var lines=std.mem.splitScalar(u8,text,'\n');
    while(lines.next()) |line| {
        if(line.len==0) continue;
        var parts=std.ArrayList([]const u8){}; var pieces=std.mem.splitScalar(u8,line,'|');while(pieces.next()) |part| try parts.append(allocator,part);
        const p=parts.items; const capacity=try std.fmt.parseInt(usize,p[5],10);
        const storage=try allocator.alloc(u8,capacity); var writer=std.Io.Writer.fixed(storage);
        const initial=try allocator.alloc(u8,p[6].len/2); _=try std.fmt.hexToBytes(initial,p[6]);try writer.writeAll(initial);
        const key:vaxis.Key=.{.codepoint=try std.fmt.parseInt(u21,p[0],10),.mods=@bitCast(try std.fmt.parseInt(u8,p[1],10)),.text=if(std.mem.eql(u8,p[4],"-")) null else blk:{const bytes=try allocator.alloc(u8,p[4].len/2);_=try std.fmt.hexToBytes(bytes,p[4]);break :blk bytes;},.shifted_codepoint=65,.base_layout_codepoint=97};
        var err_text:[]const u8="ok";encoder.encode(&writer,key,std.mem.eql(u8,p[2],"1"),@bitCast(try std.fmt.parseInt(u5,p[3],10))) catch |err| {err_text=@errorName(err);};
        const hex=try allocator.alloc(u8,writer.end*2); const digits="0123456789abcdef";for(writer.buffered(),0..) |byte,i| {hex[i*2]=digits[byte>>4];hex[i*2+1]=digits[byte&15];}try out.interface.print("{s}|{d}|{s}\n",.{err_text,writer.end,hex});
    }
    try out.interface.flush();
}
