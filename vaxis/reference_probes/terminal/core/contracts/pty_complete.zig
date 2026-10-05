const std=@import("std");const T=@import("widgets/terminal/Terminal.zig");const P=@import("widgets/terminal/Pty.zig");const C=@import("widgets/terminal/Command.zig");const S=@import("widgets/terminal/Screen.zig");const a=std.heap.page_allocator;
fn use(value:anytype)void{_ = value;}
pub fn main()!void{
 var bytes:[8]u8=undefined;var env=std.process.EnvMap.init(a);
 const pair=P{.pty=.{.handle=-1},.tty=.{.handle=-1}};
 const writer=(std.fs.File{.handle=-1}).writerStreaming(&bytes);
 const command=C{.argv=&.{},.working_directory=null,.env_map=&env,.pty=pair};
 const screen=try S.init(a,4,2);
const value=P{.pty=.{.handle=-1},.tty=.{.handle=-1}};
use(value);use(pair);use(writer);use(command);use(screen);
}
