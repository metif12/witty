const std = @import("std");
const p = @import("src/compressions/lzw.zig");
const io = @import("src/io.zig");
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_little: ?*const p.Decoder(.little) = null;
var observed_big: ?*const p.Decoder(.big) = null;
var observed_reader: ?*const io.ReadStream = null;
var observed_writer: ?*const io.WriteStream = null;
var observed_output: []const u8 = &.{};
var observed_input: []const u8 = &.{};
var observed_segment: usize = 0;
var observed_endian: usize = 0;

fn dictionaryHash(comptime endian: std.builtin.Endian, codec: *const p.Decoder(endian)) !u64 {
    const keys = try a.dupe(u13,codec.dictionary.keys());defer a.free(keys);
    std.mem.sort(u13,keys,{},std.sort.asc(u13));
    var hash: u64 = 14695981039346656037;
    for (keys) |key| {
        const value = codec.dictionary.get(key).?;
        for ([_]u64{key,value.len}) |number| {
            for (0..8) |shift| hash = (hash ^ @as(u8,@truncate(number>>@as(u6,@intCast(shift*8))))) *% 1099511628211;
        }
        for (value) |byte| hash = (hash ^ byte) *% 1099511628211;
    }
    return hash;
}
fn codecState(comptime endian: std.builtin.Endian, codec: *const p.Decoder(endian), out: *W) !void {
    try out.print("{d}:{d}:{d}:{d}:{d}:", .{codec.code_size,codec.clear_code,codec.initial_code_size,codec.end_information_code,codec.next_code});
    if (codec.previous_code) |value| try out.print("{d}", .{value}) else try out.writeByte('-');
    try out.writeByte(':');
    if (codec.remaining_data) |value| try out.print("{d}", .{value}) else try out.writeByte('-');
    try out.print(":{d}:{d}:{d}:{d}", .{codec.remaining_bits,codec.early_change,codec.dictionary.count(),try dictionaryHash(endian,codec)});
}
fn state(out: *W) !void {
    try out.print("{d}|{d}|{d}|", .{observed_segment,observed_reader.?.getPos(),observed_writer.?.getPos()});
    if (observed_endian==0) {
        if (observed_little) |codec| try codecState(.little,codec,out) else try out.writeByte('-');
    } else {
        if (observed_big) |codec| try codecState(.big,codec,out) else try out.writeByte('-');
    }
    try out.print("|{x}|{x}", .{observed_input,observed_output});
}
fn observe(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| {
        if (std.fs.cwd().createFile(path,.{})) |file| {
            defer file.close();var bytes: [4096]u8 = undefined;var writer=file.writer(&bytes);
            state(&writer.interface) catch {};writer.interface.flush() catch {};
        } else |_| {}
    }
    std.debug.defaultPanic(message,address);
}
fn num(f: [15][]const u8, index: usize) !usize {return std.fmt.parseInt(usize,f[index],10);}
fn runCase(comptime endian: std.builtin.Endian, f: [15][]const u8, out: *W) !void {
    const output=try a.alloc(u8,try num(f,10));defer a.free(output);@memset(output,0xa5);
    var writer=io.WriteStream.initMemory(output);var reader=io.ReadStream.initMemory("");
    if ((try num(f,14))>0) try writer.seekTo(try num(f,14));
    observed_reader=&reader;observed_writer=&writer;observed_output=output;
    var codec=try p.Decoder(endian).init(a,@intCast(try num(f,1)),@intCast(try num(f,2)));
    defer codec.deinit();
    if (endian==.little) observed_little=&codec else observed_big=&codec;
    if (!std.mem.eql(u8,f[3],"-1")) codec.code_size=@intCast(try num(f,3));
    if (!std.mem.eql(u8,f[4],"-1")) codec.next_code=@intCast(try num(f,4));
    if (!std.mem.eql(u8,f[5],"-1")) codec.previous_code=@intCast(try num(f,5));
    if (!std.mem.eql(u8,f[6],"-1")) codec.remaining_data=@intCast(try num(f,6));
    if (!std.mem.eql(u8,f[7],"-1")) codec.remaining_bits=@intCast(try num(f,7));
    if (!std.mem.eql(u8,f[8],"-1")) codec.initial_code_size=@intCast(try num(f,8));
    var borrowed=[_]u8{0xa5,0x5a};
    if ((try num(f,9))==1) try codec.dictionary.put(0,&.{});
    if ((try num(f,9))==2) try codec.dictionary.put(1,&.{});
    if ((try num(f,9))==3) {try codec.dictionary.put(0,&borrowed);borrowed[0]^=85;}
    if ((try num(f,12))==0) {try out.writeAll("ok|");try state(out);try out.writeByte('\n');return;}
    var parts=std.mem.splitScalar(u8,f[11],',');var index: usize=0;
    while (parts.next()) |part| {
        const data=try a.alloc(u8,part.len/2);defer a.free(data);_=try std.fmt.hexToBytes(data,part);
        reader=io.ReadStream.initMemory(data);
        if (index==0 and (try num(f,13))>0) _=try reader.reader().take(try num(f,13));
        observed_segment=index;observed_input=data;
        if (index>0) try out.writeByte('~');
        codec.decode(reader.reader(),writer.writer()) catch |err| {
            try out.print("{s}|", .{@errorName(err)});try state(out);try out.writeByte('\n');return;
        };
        try out.writeAll("ok|");try state(out);index+=1;
    }
    try out.writeByte('\n');
}
fn lineCase(line: []const u8, out: *W) !void {
    var parts=std.mem.splitScalar(u8,line,'|');var f: [15][]const u8=undefined;
    for (&f) |*field| field.*=parts.next().?;
    observed_endian=try num(f,0);observed_little=null;observed_big=null;observed_input=&.{};observed_segment=0;
    if (observed_endian==0) try runCase(.little,f,out) else try runCase(.big,f,out);
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
