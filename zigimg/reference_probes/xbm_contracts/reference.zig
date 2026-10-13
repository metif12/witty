const std = @import("std");
const p = @import("src/formats/xbm.zig").XBM;
const Image = @import("src/ImageUnmanaged.zig");
const io = @import("src/io.zig");
const a = std.heap.page_allocator;
const W = std.Io.Writer;
var loop_ready = false;

fn state(out: *W, codec: p, reader: *const io.ReadStream, data: []const u8, op: usize) !void {
    try out.print("{d}|", .{reader.getPos()});
    if (op == 1) try out.writeAll("-") else try out.print("{d}:{d}:{d}:{d}", .{codec.width,codec.height,codec.hotspot_x,codec.hotspot_y});
    try out.print("|{x}", .{data});
}
fn lineCase(line: []const u8, out: *W) !void {
    var fields = std.mem.splitScalar(u8,line,'|');
    const op = try std.fmt.parseInt(usize,fields.next().?,10);
    const start = try std.fmt.parseInt(usize,fields.next().?,10);
    const text = fields.next().?;
    const data = try a.alloc(u8,text.len/2);
    defer a.free(data);
    _ = try std.fmt.hexToBytes(data,text);
    var reader = io.ReadStream.initMemory(data);
    if (start>0) _ = try reader.reader().take(start);
    var codec = p{.width=97,.height=89,.hotspot_x=77,.hotspot_y=66};
    if (loop_ready) {
        try out.writeAll("ready|");try state(out,codec,&reader,data,op);try out.writeByte('\n');try out.flush();
    }
    if (op == 2) {
        const result = p.formatDetect(&reader) catch |err| {
            try out.print("{s}|", .{@errorName(err)});try state(out,codec,&reader,data,op);try out.writeByte('\n');return;
        };
        try out.print("ok|{d}|", .{@intFromBool(result)});try state(out,codec,&reader,data,op);try out.writeByte('\n');return;
    }
    if (op == 3) {
        var copy = codec;
        copy.width=1;copy.height=2;copy.hotspot_x=3;copy.hotspot_y=4;
        const default_value = p{};
        try out.print("ok|{d}:{d}:{d}:{d}|{d}:{d}:{d}:{d}|", .{copy.width,copy.height,copy.hotspot_x,copy.hotspot_y,default_value.width,default_value.height,default_value.hotspot_x,default_value.hotspot_y});
        try state(out,codec,&reader,data,op);try out.writeByte('\n');return;
    }
    const image = if (op == 0) blk: {
        const pixels = codec.read(a,&reader) catch |err| {
            try out.print("{s}|", .{@errorName(err)});try state(out,codec,&reader,data,op);try out.writeByte('\n');return;
        };
        break :blk Image{.width=codec.width,.height=codec.height,.pixels=pixels};
    } else p.readImage(a,&reader) catch |err| {
        try out.print("{s}|", .{@errorName(err)});try state(out,codec,&reader,data,op);try out.writeByte('\n');return;
    };
    defer image.pixels.deinit(a);
    const raw = image.pixels.asBytes();
    const before = try a.dupe(u8,raw);defer a.free(before);
    var independent: []const u8 = "-";
    if (raw.len>0) {
        const address = @intFromPtr(raw.ptr);
        independent = if (address < @intFromPtr(data.ptr) or address >= @intFromPtr(data.ptr)+data.len) "1" else "0";
        raw[0] ^= 1;
    }
    const pal = image.pixels.getPalette().?;
    const palette_before = try a.dupe(u8,std.mem.sliceAsBytes(pal));defer a.free(palette_before);
    pal[0].g ^= 85;
    try out.print("ok|{d}|{d}|{d}|{x}|{x}|{s}|{x}|{x}|", .{image.width,image.height,@intFromEnum(std.meta.activeTag(image.pixels)),before,raw,independent,palette_before,std.mem.sliceAsBytes(pal)});
    try state(out,codec,&reader,data,op);try out.writeByte('\n');
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);defer std.process.argsFree(a,args);
    var buffer: [8192]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&buffer);const out = &writer.interface;
    if (std.mem.eql(u8,args[1],"--corpus")) {
        const text = try std.fs.cwd().readFileAlloc(a,args[2],1073741824);defer a.free(text);
        var lines = std.mem.splitScalar(u8,text,'\n');
        while (lines.next()) |line| {if (line.len>0) try lineCase(line,out);}
    } else {
        loop_ready = std.mem.eql(u8,args[1],"--loop");try lineCase(args[2],out);
    }
    try out.flush();
}
