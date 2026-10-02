const std = @import("std");
const png = @import("src/formats/png.zig");
const reader = @import("src/formats/png/reader.zig");
const color = @import("src/color.zig");
const io = @import("src/io.zig");
const allocator = std.heap.page_allocator;

fn mix(hash: *u64,value: u64) void {hash.*=(hash.*^value)*%1099511628211;}
fn pixelsHash(pixels: color.PixelStorage) u64 {
    var hash: u64=14695981039346656037;
    mix(&hash,@intFromEnum(@as(@import("src/pixel_format.zig").PixelFormat,pixels)));mix(&hash,pixels.len());
    for(pixels.asConstBytes()) |byte| mix(&hash,byte);
    if(pixels.getPalette()) |palette| {mix(&hash,palette.len);for(palette) |c| for([_]u8{c.r,c.g,c.b,c.a}) |byte| mix(&hash,byte);}
    return hash;
}
pub fn main() !void {
    const args=try std.process.argsAlloc(allocator);
    const contents=try std.fs.cwd().readFileAlloc(allocator,args[1],128*1024*1024);defer allocator.free(contents);
    var lines=std.mem.tokenizeScalar(u8,contents,'\n');var stdout=std.fs.File.stdout().writer(&.{});
    while(lines.next()) |line| {
        var parts=std.mem.splitScalar(u8,line,'|');const mode=try std.fmt.parseInt(u8,parts.next().?,10);const encoded=parts.next().?;
        const bytes=try allocator.alloc(u8,encoded.len/2);defer allocator.free(bytes);_=try std.fmt.hexToBytes(bytes,encoded);
        var stream=io.ReadStream.initMemory(bytes);
        var trns=reader.TrnsProcessor{};var plte=reader.PlteProcessor{};
        var diagnostics: [8192]u8=@splat(0xa5);var writer=std.Io.Writer.fixed(&diagnostics);var info=png.InfoProcessor.init(&writer);
        var processors: [2]reader.ReaderProcessor=undefined;var count: usize=0;
        if(mode==1 or mode==3 or mode==7) {processors[count]=trns.processor();count+=1;}
        if(mode==2 or mode==3) {processors[count]=plte.processor();count+=1;}
        if(mode==4) {processors[count]=info.processor();count+=1;}
        const options=reader.ReaderOptions{.processors=processors[0..count]};
        var status: []const u8="ok";var width: usize=0;var height: usize=0;var hash: u64=0;
        if(mode==6 or mode==7) {
            if(reader.loadHeader(&stream)) |header| {
                width=header.width;height=header.height;
                if(reader.loadWithHeader(&stream,&header,allocator,options)) |pixels| {defer pixels.deinit(allocator);hash=pixelsHash(pixels);} else |err| status=@errorName(err);
            } else |err| status=@errorName(err);
        } else {
            const result=if(mode==5) png.PNG.readImage(allocator,&stream) else reader.load(&stream,allocator,options);
            if(result) |value| {var image=value;defer image.deinit(allocator);width=image.width;height=image.height;hash=pixelsHash(image.pixels);} else |err| status=@errorName(err);
        }
        var output_hash: u64=14695981039346656037;for(diagnostics) |byte| mix(&output_hash,byte);
        try stdout.interface.print("{s}|{d}|{d}|{d}|{x:0>16}|{}|{}|{d}|{d}|{d}|{x:0>16}\n",.{status,stream.getPos(),width,height,hash,trns.processed,plte.processed,info.idat_count,info.idat_size,writer.end,output_hash});
    }
}
