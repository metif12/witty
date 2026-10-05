const std = @import("std");
const Parser = @import("widgets/terminal/Parser.zig");
const ansi = @import("widgets/terminal/ansi.zig");
const allocator = std.heap.page_allocator;

fn hex(bytes: []const u8) ![]u8 {
    const output = try allocator.alloc(u8, bytes.len * 2);
    const digits = "0123456789abcdef";
    for (bytes, 0..) |byte, i| {
        output[i * 2] = digits[byte >> 4];
        output[i * 2 + 1] = digits[byte & 15];
    }
    return output;
}
fn unhex(text: []const u8) ![]u8 {
    const output = try allocator.alloc(u8, text.len / 2);
    _ = try std.fmt.hexToBytes(output, text);
    return output;
}
fn opt(value: ?u8) i16 { return if (value) |byte| byte else -1; }
fn parseOptional(text: []const u8) !?u8 {
    return if (std.mem.eql(u8, text, "-1")) null else try std.fmt.parseInt(u8, text, 10);
}
fn unexpected(message: []const u8) void { std.debug.print("{s}: {s}\n", .{ "UN" ++ "EXPECTED", message }); }

fn eventText(event: anytype) ![]const u8 {
    return switch (event) {
        .print => |bytes| try std.fmt.allocPrint(allocator, "p:{s}", .{try hex(bytes)}),
        .c0 => |value| try std.fmt.allocPrint(allocator, "c:{d}", .{@intFromEnum(value)}),
        .escape => |bytes| try std.fmt.allocPrint(allocator, "e:{s}", .{try hex(bytes)}),
        .ss2 => |byte| try std.fmt.allocPrint(allocator, "s2:{d}", .{byte}),
        .ss3 => |byte| try std.fmt.allocPrint(allocator, "s3:{d}", .{byte}),
        .csi => |seq| try std.fmt.allocPrint(allocator, "i:{d}:{d}:{d}:{s}", .{seq.final,opt(seq.private_marker),opt(seq.intermediate),try hex(seq.params)}),
        .osc => |bytes| try std.fmt.allocPrint(allocator, "o:{s}", .{try hex(bytes)}),
        .apc => |bytes| try std.fmt.allocPrint(allocator, "a:{s}", .{try hex(bytes)}),
    };
}
fn parserCase(out: *std.Io.Writer, parts: [][]const u8, file_path: []const u8) !void {
    const data = try unhex(parts[1]);
    const capacity = try std.fmt.parseInt(i32, parts[2], 10);
    var parser: Parser = .{ .buf = try std.array_list.Managed(u8).initCapacity(allocator, 128), .pending_byte = try parseOptional(parts[3]) };
    var fixed = std.Io.Reader.fixed(data);
    const storage = try allocator.alloc(u8, if(capacity < 0) 0 else @intCast(capacity));
    var file: std.fs.File = undefined;
    var buffered: std.fs.File.Reader = undefined;
    if(capacity >= 0) {
        try std.fs.cwd().writeFile(.{.sub_path=file_path,.data=data});
        file = try std.fs.cwd().openFile(file_path, .{});
        buffered = file.readerStreaming(storage);
    }
    defer if(capacity >= 0) file.close();
    const reader = if(capacity < 0) &fixed else &buffered.interface;
    const steps = try std.fmt.parseInt(usize, parts[4], 10);
    for(0..steps) |step| {
        if(step > 0) try out.writeByte(';');
        const event = parser.parseReader(reader) catch |err| {
            try out.print("!{s}@{d}/{d}/{d}/{s}", .{@errorName(err),if(capacity < 0) reader.seek else buffered.logicalPos(),reader.bufferedLen(),opt(parser.pending_byte),try hex(parser.buf.items)});
            break;
        };
        try out.print("{s}@{d}/{d}/{d}/{s}", .{try eventText(event),if(capacity < 0) reader.seek else buffered.logicalPos(),reader.bufferedLen(),opt(parser.pending_byte),try hex(parser.buf.items)});
    }
    try out.writeByte('\n');
}
fn iteratorCase(comptime T: type, out: *std.Io.Writer, parts: [][]const u8) !void {
    const seq: ansi.CSI = .{.params=try unhex(parts[2]),.final='m'};
    var iter = seq.iterator(T);
    iter.idx=try std.fmt.parseInt(usize,parts[3],10);
    var operations = std.mem.splitScalar(u8,parts[4],',');
    var first = true;
    while(operations.next()) |operation| {
        if(!first) try out.writeByte(';'); first=false;
        if(operation[0]=='n') {
            if(iter.next()) |value| try out.print("v{d}", .{@as(u64,@intCast(value))}) else try out.writeByte('-');
        } else try out.print("h{d}", .{@intFromBool(iter.hasAtLeast(try std.fmt.parseInt(usize,operation[1..],10)))});
        try out.print("/{d}/{d}/{d}", .{iter.idx,@intFromBool(iter.next_is_sub),@intFromBool(iter.is_empty)});
    }
    try out.writeByte('\n');
}
fn formatCase(out: *std.Io.Writer, parts: [][]const u8) !void {
    const seq: ansi.CSI = .{.params=try unhex(parts[1]),.private_marker=try parseOptional(parts[2]),.intermediate=try parseOptional(parts[3]),.final=try std.fmt.parseInt(u8,parts[4],10)};
    const capacity=try std.fmt.parseInt(usize,parts[5],10);
    const storage=try allocator.alloc(u8,capacity);var writer=std.Io.Writer.fixed(storage);
    try writer.writeAll(try unhex(parts[6]));
    var error_name: []const u8="ok";
    seq.format(&writer) catch |err| {error_name=@errorName(err);};
    var checks: [4]bool = undefined;
    for([_]u8{0,0x20,0x3f,0xff},0..) |byte,index| checks[index]=seq.hasIntermediate(byte);
    try out.print("{s}/{d}/{s}/{d}{d}{d}{d}/",.{error_name,writer.end,try hex(writer.buffered()),@intFromBool(checks[0]),@intFromBool(checks[1]),@intFromBool(checks[2]),@intFromBool(checks[3])});
    for([_]u8{0,0x20,0x3f,0xff}) |byte| try out.print("{d}",.{@intFromBool(seq.hasPrivateMarker(byte))});
    try out.writeByte('\n');
}
fn borrowCase(out: *std.Io.Writer, parts: [][]const u8) !void {
    var parser: Parser=.{.buf=try std.array_list.Managed(u8).initCapacity(allocator,128)};
    var reader=std.Io.Reader.fixed(try unhex(parts[1]));
    const first=try parser.parseReader(&reader);
    const before=try eventText(first);
    const second=try parser.parseReader(&reader);
    try out.print("{s}/{s}/{s}/{d}\n", .{before,try eventText(second),try eventText(first),reader.seek});
}
fn trap(comptime T:type, text:[]const u8, lookahead:bool) void {
    var iter=ansi.ParamIterator(T){.bytes=text};
    if(lookahead) _=iter.hasAtLeast(1) else _=iter.next();
    unexpected("returned");
}
pub fn main() !void {
    const args=try std.process.argsAlloc(allocator);
    if(std.mem.startsWith(u8,args[1],"trap")) {
        const kind=try std.fmt.parseInt(u8,args[1][4..],10);
        switch(kind) {
            0=>trap(u8,"256",false),1=>trap(u8,"260",true),
            2=>trap(u16,"65536",false),3=>trap(u16,"65540",true),
            4=>trap(i16,"32768",false),5=>trap(i16,"32770",true),
            6=>trap(u32,"4294967296",false),7=>trap(u32,"4294967300",true),
            8=>trap(i32,"2147483648",false),9=>trap(i32,"2147483650",true),
            10=>trap(u64,"18446744073709551616",false),11=>trap(u64,"18446744073709551620",true),
            12=>trap(i64,"9223372036854775808",false),13=>trap(i64,"9223372036854775810",true),
            14=>trap(usize,"18446744073709551616",false),15=>trap(isize,"9223372036854775810",true),
            else=>unreachable,
        } return;
    }
    const text=try std.fs.cwd().readFileAlloc(allocator,args[1],64*1024*1024);
    var buffer:[8192]u8=undefined;var file_out=std.fs.File.stdout().writer(&buffer);const out=&file_out.interface;
    var lines=std.mem.splitScalar(u8,text,'\n');
    while(lines.next()) |line| {
        if(line.len==0) continue;
        var parts=std.ArrayList([]const u8){};var pieces=std.mem.splitScalar(u8,line,'|');while(pieces.next()) |part| try parts.append(allocator,part);
        const p=parts.items;
        switch(p[0][0]) {
            'P'=>try parserCase(out,p,args[2]),
            'B'=>try borrowCase(out,p),
            'A'=>try formatCase(out,p),
            'I'=>switch(try std.fmt.parseInt(u8,p[1],10)) {
                0=>try iteratorCase(u8,out,p),1=>try iteratorCase(u16,out,p),2=>try iteratorCase(i16,out,p),
                3=>try iteratorCase(u32,out,p),4=>try iteratorCase(i32,out,p),5=>try iteratorCase(u64,out,p),
                6=>try iteratorCase(i64,out,p),7=>try iteratorCase(usize,out,p),8=>try iteratorCase(isize,out,p),
                9=>try iteratorCase(u16,out,p),else=>unreachable,
            },
            else=>unreachable,
        }
    }
    try out.flush();
}
