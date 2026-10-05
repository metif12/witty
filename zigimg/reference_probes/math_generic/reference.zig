const std = @import("std");
const math = @import("src/math.zig");
fn emit(writer: *std.Io.Writer, value: f32) !void {
    const raw: u32 = if(std.math.isNan(value)) 0x7fc00000 else @bitCast(value);
    try writer.print("{d},",.{raw});
}
fn record(comptime N: usize,writer: *std.Io.Writer,value: anytype) !void {
    for(value.matrix) |row| inline for(0..N) |column| try emit(writer,row[column]);
}
fn run(comptime N: usize, comptime Storage: type, writer: *std.Io.Writer, values: []const f32) !void {
    const Matrix = math.Matrix(Storage);
    const Vector = @Vector(N,f32);
    const left = Matrix.fromArray(values[0..N*N].*);
    const right = Matrix.fromArray(values[N*N..2*N*N].*);
    const vector: Vector = values[2*N*N..2*N*N+N].*;
    try emit(writer,left.determinant());
    try record(N,writer,left.inverse());
    const result = left.mulVector(vector);
    inline for(0..N) |index| try emit(writer,result[index]);
    try record(N,writer,left.mul(right));
    try record(N,writer,left.transpose());
    try record(N,writer,Matrix.identity());
    try record(N,writer,left);
    try record(N,writer,right);
    inline for(0..N) |index| try emit(writer,vector[index]);
}
const CustomFiveRows = [5]@Vector(5,f32);
pub fn main() !void {
    const allocator=std.heap.page_allocator;
    const args=try std.process.argsAlloc(allocator);
    const contents=try std.fs.cwd().readFileAlloc(allocator,args[1],16*1024*1024);
    var lines=std.mem.tokenizeScalar(u8,contents,'\n');
    var buffer: [64*1024]u8=undefined;
    var output=std.fs.File.stdout().writer(&buffer);
    const writer=&output.interface;
    while(lines.next()) |line| {
        var parts=std.mem.splitScalar(u8,line,'|');
        const dimension=try std.fmt.parseInt(u8,parts.next().?,10);
        var values: [136]f32=undefined;
        var size: usize=0;
        while(parts.next()) |value| {values[size]=@bitCast(try std.fmt.parseInt(u32,value,10));size+=1;}
        switch(dimension) {
            1 => {try run(1,[1]@Vector(1,f32),writer,values[0..size]);},
            2 => {try run(2,[2]@Vector(2,f32),writer,values[0..size]);try run(2,[2]math.float2,writer,values[0..size]);},
            3 => {try run(3,[3]@Vector(3,f32),writer,values[0..size]);try run(3,[3]math.float3,writer,values[0..size]);},
            4 => {try run(4,[4]@Vector(4,f32),writer,values[0..size]);try run(4,[4]math.float4,writer,values[0..size]);},
            5 => {try run(5,[5]@Vector(5,f32),writer,values[0..size]);try run(5,CustomFiveRows,writer,values[0..size]);},
            8 => {try run(8,[8]@Vector(8,f32),writer,values[0..size]);},
            else => return error.InvalidDimension,
        }
        try writer.writeByte('\n');
    }
    try writer.flush();
}
