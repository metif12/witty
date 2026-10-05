const std = @import("std");
const Image = @import("src/Image.zig");
const ImageUnmanaged = @import("src/ImageUnmanaged.zig");
const PixelFormat = @import("src/pixel_format.zig").PixelFormat;
const color = @import("src/color.zig");
const codecs = @import("src/formats.zig");
const io = @import("src/io.zig");
const allocator = std.heap.page_allocator;

fn options(format: Image.Format, variant: usize) Image.EncoderOptions {
    return switch (format) {
        .bmp => .{ .bmp = .{} },
        .farbfeld => .{ .farbfeld = {} },
        .gif => .{ .gif = {} },
        .iff => .{ .iff = {} },
        .jpeg => .{ .jpeg = {} },
        .pam => .{ .pam = .{ .comments = if (variant == 1) &.{ "one", "two" } else &.{} } },
        .pbm => .{ .pbm = .{ .binary = variant != 1 } },
        .pcx => .{ .pcx = .{} },
        .pgm => .{ .pgm = .{ .binary = variant != 1 } },
        .png => .{ .png = .{ .interlaced = variant == 1 } },
        .ppm => .{ .ppm = .{ .binary = variant != 1 } },
        .qoi => .{ .qoi = .{ .colorspace = if (variant == 1) .linear else .srgb } },
        .ras => .{ .ras = {} },
        .sgi => .{ .sgi = {} },
        .tga => .{ .tga = .{
            .rle_compressed = variant != 1,
            .top_to_bottom_image = variant == 0,
            .image_id = if (variant == 2) &.{ 7, 8, 9 } else &.{},
            .author_name = if (variant == 2) "author" else "",
        } },
        .tiff => .{ .tiff = {} },
        .xbm => .{ .xbm = {} },
    };
}

fn source(profile: usize) !ImageUnmanaged {
    const formats = [_]PixelFormat{ .grayscale8, .rgb24, .rgba32, .bgr24, .bgra32, .rgba64, .indexed8, .invalid };
    var image = try ImageUnmanaged.create(allocator, 4, 2, formats[profile]);
    for (image.pixels.asBytes(), 0..) |*byte, i| byte.* = @truncate(i * 37 + profile * 19);
    if (profile == 6) {
        image.pixels.resizePalette(4);
        for (image.pixels.indexed8.indices, 0..) |*index, i| index.* = @intCast(i % 4);
        for (image.pixels.indexed8.palette, 0..) |*entry, i| entry.* = .{ .r = @intCast(i * 71), .g = @intCast(i * 53), .b = @intCast(i * 37), .a = 255 };
    }
    return image;
}

fn mix(hash: *u64, value: u64) void {
    hash.* = (hash.* ^ value) *% 1099511628211;
}

const interfaces = [_]@import("src/FormatInterface.zig"){
 codecs.bmp.BMP.formatInterface(),
 codecs.farbfeld.Farbfeld.formatInterface(),
 codecs.gif.GIF.formatInterface(),
 codecs.iff.IFF.formatInterface(),
 codecs.jpeg.JPEG.formatInterface(),
 codecs.pam.PAM.formatInterface(),
 codecs.netpbm.PBM.formatInterface(),
 codecs.pcx.PCX.formatInterface(),
 codecs.netpbm.PGM.formatInterface(),
 codecs.png.PNG.formatInterface(),
 codecs.netpbm.PPM.formatInterface(),
 codecs.qoi.QOI.formatInterface(),
 codecs.ras.RAS.formatInterface(),
 codecs.sgi.SGI.formatInterface(),
 codecs.tga.TGA.formatInterface(),
 codecs.tiff.TIFF.formatInterface(),
 codecs.xbm.XBM.formatInterface(),
};

pub fn main() !void {
 const args = try std.process.argsAlloc(allocator);
 defer std.process.argsFree(allocator,args);
 if(args.len>1) {
  const format: Image.Format = if(std.mem.eql(u8,args[1],"png")) .png else .tga;
  var bytes: [1024]u8 = undefined;
  var stream=io.WriteStream{.memory=std.Io.Writer.fixed(&bytes)};
  var image=try source(7);defer image.deinit(allocator);
  interfaces[@intFromEnum(format)].writeImage(allocator,&stream,image,.{.qoi=.{}}) catch |err| {std.debug.print("UNEXPECTED {s}\n",.{@errorName(err)});return;};
  std.debug.print("UNEXPECTED\n",.{});return;
 }
 var output = std.fs.File.stdout().writer(&.{});
 for(std.meta.tags(Image.Format)) |format| {
  const codec=interfaces[@intFromEnum(format)];
  for(std.meta.tags(Image.Format)) |option| {
   if((format==.png or format==.tga) and option!=format) continue;
   for(0..8) |profile| {
    var image=try source(profile);defer image.deinit(allocator);
    for(0..3) |variant| {
     for([_]usize{0,1,7,8,15,31,127,1024}) |size| {
      const bytes=try allocator.alloc(u8,size);defer allocator.free(bytes);@memset(bytes,0xa5);
      var stream=io.WriteStream{.memory=std.Io.Writer.fixed(bytes)};
      var status: []const u8="ok";
      codec.writeImage(allocator,&stream,image,options(option,variant)) catch |err| {status=@errorName(err);};
      var hash: u64=14695981039346656037;for(bytes) |byte| mix(&hash,byte);
      try output.interface.print("{s}:{s}:{d}:{d}:{d}|{s}:{d}:{x:0>16}\n",.{@tagName(format),@tagName(option),profile,variant,size,status,stream.getPos(),hash});
     }
    }
   }
  }
 }
}
