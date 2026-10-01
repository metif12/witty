const std = @import("std");
const zigimg = @import("zigimg");

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    std.debug.assert(args.len == 2);
    if (std.mem.eql(u8, args[1], "short_loop_count")) {
        var codec = zigimg.formats.gif.GIF.init(std.heap.page_allocator);
        var data = [_]u8{1};
        try codec.application_infos.append(std.heap.page_allocator, .{ .application_identifier = "NETSCAPE".*, .authentification_code = "2.0".*, .data = &data });
        _ = codec.loopCount();
    } else {
        const header = "GIF89a\x01\x00\x01\x00\x80\x00\x00\x01\x02\x03\x04\x05\x06";
        const bytes: []const u8 = if (std.mem.eql(u8, args[1], "plain_text_overflow"))
            header ++ "\x21\x01\x00\xff" ++ ([1]u8{'A'} ** 255) ++ "\x00\x3b"
        else if (std.mem.eql(u8, args[1], "graphic_toss"))
            header ++ "\x21\xf9\x04\x00\x00\x00"
        else if (std.mem.eql(u8, args[1], "background_index"))
            header ++ "\x21\xf9\x04\x09\x00\x00\x03\x00\x2c\x00\x00\x00\x00\x01\x00\x01\x00\x00\x02\x02\x4c\x01\x00\x3b"
        else
            @panic("unknown case");
        var reader = zigimg.io.ReadStream.initMemory(bytes);
        _ = zigimg.formats.gif.GIF.readImage(std.heap.page_allocator, &reader) catch @panic("UNEXPECTED read error");
    }
    std.debug.print("UNEXPECTED: decoder returned\n", .{});
}
