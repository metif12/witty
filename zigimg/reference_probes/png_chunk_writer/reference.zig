const std = @import("std");
const cw = @import("src/formats/png/chunk_writer.zig");
const allocator = std.heap.page_allocator;

fn mix(hash: *u64, value: u64) void { hash.* = (hash.* ^ value) *% 1099511628211; }
const Output = struct { stream: std.Io.Writer, max_write: usize, trace: u64 = 14695981039346656037 };
const Adapter = struct {
    output: *Output,
    pub const Error = std.Io.Writer.Error;
    pub fn writeInt(self: @This(), comptime T: type, value: T, endian: std.builtin.Endian) Error!void {
        mix(&self.output.trace, 1); mix(&self.output.trace, value);
        try self.output.stream.writeInt(T, value, endian);
    }
    pub fn writeAll(self: @This(), bytes: []const u8) Error!void {
        mix(&self.output.trace, 2); mix(&self.output.trace, bytes.len);
        try self.output.stream.writeAll(bytes);
    }
    pub fn write(self: @This(), bytes: []const u8) Error!usize {
        mix(&self.output.trace, 3); mix(&self.output.trace, bytes.len);
        const count = if(self.output.max_write > 0) @min(self.output.max_write, bytes.len) else bytes.len;
        return self.output.stream.write(bytes[0..count]);
    }
};

fn run(comptime size: usize, parts: *std.mem.SplitIterator(u8,.scalar), stdout: *std.Io.Writer) !void {
    const capacity=try std.fmt.parseInt(usize,parts.next().?,10);
    const destination=try allocator.alloc(u8,capacity);defer allocator.free(destination);@memset(destination,0xa5);
    var output=Output{.stream=std.Io.Writer.fixed(destination),.max_write=try std.fmt.parseInt(usize,parts.next().?,10)};
    var writer=cw.ChunkWriter(size,Adapter){.unbuffered_writer=Adapter{.output=&output},.section_id="IDAT".*};
    const operations=parts.next().?;
    if(std.mem.eql(u8,operations,"overflow") or std.mem.eql(u8,operations,"bounds")) {
        writer.end=if(std.mem.eql(u8,operations,"overflow")) std.math.maxInt(usize) else size+1;
        if(std.mem.eql(u8,operations,"overflow")) {
            _=writer.write(&.{1}) catch |err| {std.debug.print("UNEXPECTED {s}\n",.{@errorName(err)});return;};
        } else writer.flush() catch |err| {std.debug.print("UNEXPECTED {s}\n",.{@errorName(err)});return;};
        try stdout.writeAll("UNEXPECTED\n");return;
    }
    var iterator=std.mem.splitScalar(u8,operations,',');var first=true;
    while(iterator.next()) |operation| {
        var status: []const u8="ok";var count: usize=0;
        if(std.mem.eql(u8,operation,"F")) writer.flush() catch |err| {status=@errorName(err);} else {
            const bytes=try allocator.alloc(u8,(operation.len-1)/2);defer allocator.free(bytes);_=try std.fmt.hexToBytes(bytes,operation[1..]);
            count=writer.write(bytes) catch |err| blk: {status=@errorName(err);break :blk 0;};
        }
        var active: u64=14695981039346656037;for(writer.buf[0..writer.end]) |byte| mix(&active,byte);
        if(!first) try stdout.writeByte(';');first=false;
        try stdout.print("{s}:{d}:{d}:{d}:{x:0>16}",.{status,count,writer.end,output.stream.end,active});
    }
    var hash: u64=14695981039346656037;for(destination) |byte| mix(&hash,byte);
    try stdout.print("|{x:0>16}|{x:0>16}\n",.{output.trace,hash});
}

pub fn main() !void {
    const args=try std.process.argsAlloc(allocator);
    const contents=try std.fs.cwd().readFileAlloc(allocator,args[1],64*1024*1024);defer allocator.free(contents);
    var lines=std.mem.tokenizeScalar(u8,contents,'\n');var stdout=std.fs.File.stdout().writer(&.{});
    while(lines.next()) |line| {
        var parts=std.mem.splitScalar(u8,line,'|');const size=try std.fmt.parseInt(usize,parts.next().?,10);
        switch(size) {0=>try run(0,&parts,&stdout.interface),1=>try run(1,&parts,&stdout.interface),4=>try run(4,&parts,&stdout.interface),16=>try run(16,&parts,&stdout.interface),16384=>try run(16384,&parts,&stdout.interface),else=>unreachable}
    }
}
