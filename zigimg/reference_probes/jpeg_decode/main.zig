const std = @import("std");
const zigimg = @import("zigimg");
pub fn main() !void {
 const alloc = std.heap.page_allocator;
 const args = try std.process.argsAlloc(alloc);
 for (args[1..]) |path| {
  const data = try std.fs.cwd().readFileAlloc(alloc,path,10000000);
  for (0..2) |mode| {
   var file = try std.fs.cwd().openFile(path,.{});
   defer file.close();
   var buffer: [4096]u8 = undefined;
   var stream = if (mode==0) zigimg.io.ReadStream.initMemory(data) else zigimg.io.ReadStream.initFile(file,&buffer);
   var jpeg = zigimg.formats.jpeg.JPEG.init(alloc);
   defer jpeg.deinit();
   var pixels: ?zigimg.color.PixelStorage = null;
   const frame = jpeg.read(&stream,&pixels) catch |err| {std.debug.print("{s}|{d}|{s}|{d}\n",.{std.fs.path.basename(path),mode,@errorName(err),stream.getPos()}); continue;};
   defer pixels.?.deinit(alloc);
   var hash:u64=14695981039346656037;
   for (pixels.?.asBytes()) |byte| { hash = (hash ^ byte) *% 1099511628211; }
   std.debug.print("{s}|{d}|ok|{d}|{d}|{d}|{s}|{x:0>16}\n",.{std.fs.path.basename(path),mode,stream.getPos(),frame.frame_header.width,frame.frame_header.height,@tagName(pixels.?),hash});
  }
 }
}
