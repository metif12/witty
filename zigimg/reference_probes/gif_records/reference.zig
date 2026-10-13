const std = @import("std");
const p = @import("src/formats/gif.zig");
const io = @import("src/io.zig");
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var observed_word: ?*const u8 = null;
var observed_codec: ?*p.GIF = null;
var observed_stream: ?*io.ReadStream = null;
var observed_path: ?[]const u8 = null;
var observed_toss: bool = false;
fn packedBytes(out: *W, value: anytype) !void {
    try out.print("{x}", .{std.mem.asBytes(&value)});
}
fn snapshot(out: *W, codec: *const p.GIF) !void {
    try packedBytes(out, codec.header);
    try out.print("|{x}|", .{std.mem.sliceAsBytes(codec.global_color_table.data)});
    for (codec.frames.items) |frame| {
        if (frame.graphics_control) |control| try packedBytes(out, control) else try out.writeByte('-');
        try out.writeByte(':');
        for (frame.sub_images.items) |img| {
            try packedBytes(out, img.image_descriptor);
            try out.print(":{x},", .{img.pixels});
        }
        try out.writeByte(';');
    }
    try out.print("|{d}|", .{codec.comments.items.len});
    for (codec.application_infos.items) |info| try out.print("{x}{x}:{x};", .{ info.application_identifier, info.authentification_code, info.data });
}
fn observe(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var buffer: [8192]u8 = undefined;
            var writer = file.writer(&buffer);
            const out = &writer.interface;
            if (observed_word) |word| out.print("{d}", .{word.*}) catch {} else if (observed_codec) |codec| {
                out.print("{d}|", .{observed_stream.?.getPos()}) catch {};
                snapshot(out, codec) catch {};
            } else if (observed_toss) out.print("{d}", .{observed_stream.?.getPos()}) catch {};
            out.flush() catch {};
        } else |_| {}
    }
    std.debug.defaultPanic(message, address);
}
fn narrow(field: []const u8, value: u8) void {
    var h: p.HeaderFlags = @bitCast(@as(u8, 165));
    var d: p.ImageDescriptorFlags = @bitCast(@as(u8, 165));
    var c: p.GraphicControlExtensionFlags = @bitCast(@as(u8, 165));
    if (std.mem.eql(u8, field, "header_size")) {
        observed_word = @ptrCast(&h);
        h.global_color_table_size = @intCast(value);
    } else if (std.mem.eql(u8, field, "resolution")) {
        observed_word = @ptrCast(&h);
        h.color_resolution = @intCast(value);
    } else if (std.mem.eql(u8, field, "local_size")) {
        observed_word = @ptrCast(&d);
        d.local_color_table_size = @intCast(value);
    } else if (std.mem.eql(u8, field, "descriptor_reserved")) {
        observed_word = @ptrCast(&d);
        d.reserved = @intCast(value);
    } else if (std.mem.eql(u8, field, "disposal")) {
        observed_word = @ptrCast(&c);
        c.disposal_method = @enumFromInt(@as(u3, @intCast(value)));
    } else if (std.mem.eql(u8, field, "control_reserved")) {
        observed_word = @ptrCast(&c);
        c.reserved = @intCast(value);
    } else @panic("unknown field");
    std.debug.print("UNEXPECTED: narrow mutation returned\n", .{});
}
fn decode(encoded: []const u8, short_loop: bool) !void {
    const data = try a.alloc(u8, encoded.len / 2);
    _ = try std.fmt.hexToBytes(data, encoded);
    var stream = io.ReadStream.initMemory(data);
    var codec = p.GIF.init(a);
    codec.header.magic = @splat(0);
    codec.header.version = @splat(0);
    observed_codec = &codec;
    observed_stream = &stream;
    if (short_loop) {
        const info: p.ApplicationExtension = .{ .application_identifier = "NETSCAPE".*, .authentification_code = "2.0".*, .data = try a.dupe(u8, &.{1}) };
        try codec.application_infos.append(a, info);
        _ = codec.loopCount();
    } else {
        if (codec.read(&stream)) |_| {
            std.debug.print("UNEXPECTED: decoder returned\n", .{});
        } else |err| {
            std.debug.print("UNEXPECTED: recoverable {}\n", .{err});
        }
    }
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    if (args.len > 1) {
        observed_path = args[2];
        if (std.mem.eql(u8, args[1], "--toss")) {
            var stream = io.ReadStream.initMemory("abcd");
            try stream.seekTo(try std.fmt.parseInt(u64, args[3], 10));
            observed_stream = &stream;
            observed_toss = true;
            stream.reader().toss(try std.fmt.parseInt(usize, args[4], 10));
            std.debug.print("UNEXPECTED: toss returned\n", .{});
            return;
        }
        if (std.mem.eql(u8, args[1], "--narrow")) narrow(args[3], try std.fmt.parseInt(u8, args[4], 10)) else try decode(args[3], std.mem.eql(u8, args[1], "--loop"));
        return;
    }
    var buffer: [8192]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&buffer);
    const out = &stdout.interface;
    for (0..256) |raw| {
        for (0..8) |n| {
            var x: p.HeaderFlags = @bitCast(@as(u8, @intCast(raw)));
            const copied = x;
            x.global_color_table_size = @intCast(n);
            try out.print("H|{d}|0|{d}|{d}|{d}|{}|{d}|{}|{d}\n", .{ raw, n, @as(u8, @bitCast(x)), x.global_color_table_size, x.sorted, x.color_resolution, x.use_global_color_table, @as(u8, @bitCast(copied)) });
        }
    }
    for (0..256) |raw| {
        for (0..2) |n| {
            var x: p.HeaderFlags = @bitCast(@as(u8, @intCast(raw)));
            const copied = x;
            x.sorted = n != 0;
            try out.print("H|{d}|1|{d}|{d}|{d}|{}|{d}|{}|{d}\n", .{ raw, n, @as(u8, @bitCast(x)), x.global_color_table_size, x.sorted, x.color_resolution, x.use_global_color_table, @as(u8, @bitCast(copied)) });
        }
    }
    for (0..256) |raw| {
        for (0..8) |n| {
            var x: p.HeaderFlags = @bitCast(@as(u8, @intCast(raw)));
            const copied = x;
            x.color_resolution = @intCast(n);
            try out.print("H|{d}|2|{d}|{d}|{d}|{}|{d}|{}|{d}\n", .{ raw, n, @as(u8, @bitCast(x)), x.global_color_table_size, x.sorted, x.color_resolution, x.use_global_color_table, @as(u8, @bitCast(copied)) });
        }
    }
    for (0..256) |raw| {
        for (0..2) |n| {
            var x: p.HeaderFlags = @bitCast(@as(u8, @intCast(raw)));
            const copied = x;
            x.use_global_color_table = n != 0;
            try out.print("H|{d}|3|{d}|{d}|{d}|{}|{d}|{}|{d}\n", .{ raw, n, @as(u8, @bitCast(x)), x.global_color_table_size, x.sorted, x.color_resolution, x.use_global_color_table, @as(u8, @bitCast(copied)) });
        }
    }
    for (0..256) |raw| {
        for (0..8) |n| {
            var x: p.ImageDescriptorFlags = @bitCast(@as(u8, @intCast(raw)));
            const copied = x;
            x.local_color_table_size = @intCast(n);
            try out.print("D|{d}|0|{d}|{d}|{d}|{d}|{}|{}|{}|{d}\n", .{ raw, n, @as(u8, @bitCast(x)), x.local_color_table_size, x.reserved, x.sort, x.is_interlaced, x.has_local_color_table, @as(u8, @bitCast(copied)) });
        }
    }
    for (0..256) |raw| {
        for (0..4) |n| {
            var x: p.ImageDescriptorFlags = @bitCast(@as(u8, @intCast(raw)));
            const copied = x;
            x.reserved = @intCast(n);
            try out.print("D|{d}|1|{d}|{d}|{d}|{d}|{}|{}|{}|{d}\n", .{ raw, n, @as(u8, @bitCast(x)), x.local_color_table_size, x.reserved, x.sort, x.is_interlaced, x.has_local_color_table, @as(u8, @bitCast(copied)) });
        }
    }
    for (0..256) |raw| {
        for (0..2) |n| {
            var x: p.ImageDescriptorFlags = @bitCast(@as(u8, @intCast(raw)));
            const copied = x;
            x.sort = n != 0;
            try out.print("D|{d}|2|{d}|{d}|{d}|{d}|{}|{}|{}|{d}\n", .{ raw, n, @as(u8, @bitCast(x)), x.local_color_table_size, x.reserved, x.sort, x.is_interlaced, x.has_local_color_table, @as(u8, @bitCast(copied)) });
        }
    }
    for (0..256) |raw| {
        for (0..2) |n| {
            var x: p.ImageDescriptorFlags = @bitCast(@as(u8, @intCast(raw)));
            const copied = x;
            x.is_interlaced = n != 0;
            try out.print("D|{d}|3|{d}|{d}|{d}|{d}|{}|{}|{}|{d}\n", .{ raw, n, @as(u8, @bitCast(x)), x.local_color_table_size, x.reserved, x.sort, x.is_interlaced, x.has_local_color_table, @as(u8, @bitCast(copied)) });
        }
    }
    for (0..256) |raw| {
        for (0..2) |n| {
            var x: p.ImageDescriptorFlags = @bitCast(@as(u8, @intCast(raw)));
            const copied = x;
            x.has_local_color_table = n != 0;
            try out.print("D|{d}|4|{d}|{d}|{d}|{d}|{}|{}|{}|{d}\n", .{ raw, n, @as(u8, @bitCast(x)), x.local_color_table_size, x.reserved, x.sort, x.is_interlaced, x.has_local_color_table, @as(u8, @bitCast(copied)) });
        }
    }
    for (0..256) |raw| {
        for (0..2) |n| {
            var x: p.GraphicControlExtensionFlags = @bitCast(@as(u8, @intCast(raw)));
            const copied = x;
            x.has_transparent_color = n != 0;
            try out.print("C|{d}|0|{d}|{d}|{}|{}|{d}|{d}|{d}\n", .{ raw, n, @as(u8, @bitCast(x)), x.has_transparent_color, x.user_input, @intFromEnum(x.disposal_method), x.reserved, @as(u8, @bitCast(copied)) });
        }
    }
    for (0..256) |raw| {
        for (0..2) |n| {
            var x: p.GraphicControlExtensionFlags = @bitCast(@as(u8, @intCast(raw)));
            const copied = x;
            x.user_input = n != 0;
            try out.print("C|{d}|1|{d}|{d}|{}|{}|{d}|{d}|{d}\n", .{ raw, n, @as(u8, @bitCast(x)), x.has_transparent_color, x.user_input, @intFromEnum(x.disposal_method), x.reserved, @as(u8, @bitCast(copied)) });
        }
    }
    for (0..256) |raw| {
        for (0..8) |n| {
            var x: p.GraphicControlExtensionFlags = @bitCast(@as(u8, @intCast(raw)));
            const copied = x;
            x.disposal_method = @enumFromInt(n);
            try out.print("C|{d}|2|{d}|{d}|{}|{}|{d}|{d}|{d}\n", .{ raw, n, @as(u8, @bitCast(x)), x.has_transparent_color, x.user_input, @intFromEnum(x.disposal_method), x.reserved, @as(u8, @bitCast(copied)) });
        }
    }
    for (0..256) |raw| {
        for (0..8) |n| {
            var x: p.GraphicControlExtensionFlags = @bitCast(@as(u8, @intCast(raw)));
            const copied = x;
            x.reserved = @intCast(n);
            try out.print("C|{d}|3|{d}|{d}|{}|{}|{d}|{d}|{d}\n", .{ raw, n, @as(u8, @bitCast(x)), x.has_transparent_color, x.user_input, @intFromEnum(x.disposal_method), x.reserved, @as(u8, @bitCast(copied)) });
        }
    }
    try out.writeAll("DEFAULT");
    inline for (.{ p.HeaderFlags{}, p.ImageDescriptorFlags{}, p.GraphicControlExtensionFlags{}, p.Header{ .magic = @splat(0), .version = @splat(0) }, p.ImageDescriptor{}, p.GraphicControlExtension{} }) |val| {
        try out.writeByte('|');
        try packedBytes(out, val);
    }
    try out.writeByte('\n');
    for ([_]u16{ 0, 1, 255, 256, 32768, 65535 }) |seed| {
        var h: p.Header = .{ .magic = "GIF".*, .version = "89a".*, .width = seed, .height = seed, .flags = @bitCast(@as(u8, @truncate(seed))), .background_color_index = @truncate(seed), .pixel_aspect_ratio = @truncate(seed) };
        const hc = h;
        h.magic[0] = 'X';
        h.version[2] = 'b';
        h.width = 17;
        h.height = 18;
        h.flags.sorted = true;
        h.background_color_index = 19;
        h.pixel_aspect_ratio = 20;
        try out.print("HEADER|{d}|", .{seed});
        try packedBytes(out, hc);
        try out.writeByte('|');
        try packedBytes(out, h);
        try out.writeByte('\n');
        var d: p.ImageDescriptor = .{ .left_position = seed, .top_position = seed, .width = seed, .height = seed, .flags = @bitCast(@as(u8, @truncate(seed))) };
        const dc = d;
        d.left_position = 17;
        d.top_position = 18;
        d.width = 19;
        d.height = 20;
        d.flags.is_interlaced = true;
        try out.print("DESCRIPTOR|{d}|", .{seed});
        try packedBytes(out, dc);
        try out.writeByte('|');
        try packedBytes(out, d);
        try out.writeByte('\n');
        var c: p.GraphicControlExtension = .{ .flags = @bitCast(@as(u8, @truncate(seed))), .delay_time = seed, .transparent_color_index = @truncate(seed) };
        const cc = c;
        c.flags.reserved = 3;
        c.delay_time = 17;
        c.transparent_color_index = 18;
        try out.print("CONTROL|{d}|", .{seed});
        try packedBytes(out, cc);
        try out.writeByte('|');
        try packedBytes(out, c);
        try out.writeByte('\n');
        var frame: p.GIF.FrameData = .{ .graphics_control = cc };
        const img = try frame.allocNewSubImage(a);
        img.image_descriptor = dc;
        img.pixels = try a.dupe(u8, &.{ 1, 2, 3 });
        img.local_color_table.resize(2);
        img.local_color_table.data[0] = .{ .r = 1, .g = 2, .b = 3 };
        img.local_color_table.data[1] = .{ .r = 4, .g = 5, .b = 6 };
        const fcopy = frame;
        const scopy = img.*;
        frame.graphics_control = c;
        img.image_descriptor.width = 55;
        img.pixels[0] = 42;
        img.local_color_table.storage[0].r = 77;
        try out.print("FRAME|{d}|", .{seed});
        try packedBytes(out, fcopy.graphics_control.?);
        try out.writeByte('|');
        try packedBytes(out, frame.graphics_control.?);
        try out.print("|{d}|{d}|{d}|{x}|{d}|{d}\n", .{ fcopy.sub_images.items.len, fcopy.sub_images.items[0].image_descriptor.width, scopy.image_descriptor.width, scopy.pixels, scopy.local_color_table.storage[0].r, scopy.local_color_table.data[0].r });
    }
    var data = [_]u8{ 1, 2, 3 };
    var comment: p.CommentExtension = .{ .comment = &data };
    const copied_comment = comment;
    comment.comment[0] = 4;
    data[1] = 5;
    comment.comment = comment.comment[0..1];
    try out.print("COMMENT|{x}|{x}\n", .{ comment.comment, copied_comment.comment });
    var app: p.ApplicationExtension = .{ .application_identifier = @splat(0), .authentification_code = @splat(0), .data = &data };
    const copied_app = app;
    app.application_identifier[0] = 'N';
    app.authentification_code[0] = '2';
    data[2] = 6;
    app.data = app.data[0..1];
    try out.print("APPLICATION|{x}|{x}|{x}|{x}|{x}|{x}\n", .{ app.application_identifier, copied_app.application_identifier, app.authentification_code, copied_app.authentification_code, app.data, copied_app.data });
    try out.flush();
}
