const std = @import("std");
const p = @import("src/formats/tga.zig");
const io = @import("src/io.zig");
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var observed_codec: ?*p.TGA = null;
var observed_stream: ?*io.ReadStream = null;
var observed_word: ?*const u8 = null;
var observed_path: ?[]const u8 = null;

fn bytes(out: *W, value: anytype) !void {
    try out.print("{x}", .{std.mem.asBytes(&value)});
}
fn observe(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var buffer: [8192]u8 = undefined;
            var writer = file.writer(&buffer);
            const out = &writer.interface;
            if (observed_word) |word| {
                out.print("{d}", .{word.*}) catch {};
            } else if (observed_codec) |codec| {
                out.print("{d}|", .{observed_stream.?.getPos()}) catch {};
                bytes(out, codec.header) catch {};
                out.print("|{x}|", .{codec.id.data}) catch {};
                if (codec.extension) |extension| bytes(out, extension) catch {} else out.writeByte('-') catch {};
            }
            out.flush() catch {};
        } else |_| {}
    }
    std.debug.defaultPanic(message, address);
}
fn narrow(field: []const u8, value: u8) void {
    var flags: p.TGAImageType = @bitCast(@as(u8, 165));
    var descriptor: p.TGADescriptor = @bitCast(@as(u8, 165));
    if (std.mem.eql(u8, field, "pad1")) {
        observed_word = @ptrCast(&flags);
        flags.pad1 = @intCast(value);
    } else {
        observed_word = @ptrCast(&descriptor);
        if (std.mem.eql(u8, field, "attributes")) descriptor.num_attributes_bit = @intCast(value) else if (std.mem.eql(u8, field, "pad")) descriptor.pad = @intCast(value) else @panic("unknown field");
    }
    std.debug.print("UNEXPECTED: narrow mutation returned\n", .{});
}
fn decode(path: []const u8) !void {
    const input = try std.fs.cwd().readFileAlloc(a, path, 4096);
    var stream = io.ReadStream.initMemory(input);
    var codec: p.TGA = .{ .extension = .{ .extension_size = 123 } };
    observed_codec = &codec;
    observed_stream = &stream;
    if (codec.read(a, &stream)) |_| {
        std.debug.print("UNEXPECTED: decoder returned\n", .{});
    } else |err| {
        std.debug.print("UNEXPECTED: recoverable {}\n", .{err});
    }
}
fn records(out: *W) !void {
    try out.writeAll("DEFAULT");
    inline for (.{ p.TGAImageType{}, p.TGADescriptor{}, p.TGAColorMapSpec{}, p.TGAImageSpec{}, p.TGAHeader{}, p.TGAExtensionComment{}, p.TGAExtensionSoftwareVersion{}, p.TGAExtensionTimestamp{}, p.TGAExtensionJobTime{}, p.TGAExtensionRatio{}, p.TGAExtension{}, p.TGAFooter{ .signature = @splat(0) } }) |value| {
        try out.writeByte('|');
        try bytes(out, value);
    }
    try out.writeByte('\n');
    for ([_]u16{ 0, 1, 255, 256, 32768, 65535 }) |seed| {
        var header: p.TGAHeader = .{ .id_length = @truncate(seed), .has_color_map = 1, .image_type = @bitCast(@as(u8, @truncate(seed))), .color_map_spec = .{ .first_entry_index = seed, .length = seed, .bit_depth = @truncate(seed) }, .image_spec = .{ .origin_x = seed, .origin_y = seed, .width = seed, .height = seed, .bit_per_pixel = @truncate(seed), .descriptor = @bitCast(@as(u8, @truncate(seed))) } };
        const header_copy = header;
        header.image_type.run_length = true;
        header.color_map_spec.length = 17;
        header.image_spec.descriptor.top_to_bottom = true;
        header.image_spec.width = 7;
        try out.print("HEADER|{d}|", .{seed});
        try bytes(out, header_copy);
        try out.writeByte('|');
        try bytes(out, header);
        try out.writeByte('\n');
        var extension: p.TGAExtension = .{ .extension_size = seed, .timestamp = .{ .month = seed, .day = seed, .year = seed, .hour = seed, .minute = seed, .second = seed }, .job_time = .{ .hours = seed, .minutes = seed, .seconds = seed }, .software_version = .{ .number = seed, .letter = @truncate(seed) }, .key_color = .{ .b = @truncate(seed), .g = @truncate(seed), .r = @truncate(seed), .a = @truncate(seed) }, .pixel_aspect = .{ .numerator = seed, .denominator = seed }, .gamma_value = .{ .numerator = seed, .denominator = seed }, .color_correction_offset = @as(u32, seed) * 65537, .postage_stamp_offset = @as(u32, seed) * 65537, .scanline_offset = @as(u32, seed) * 65537, .attributes = @enumFromInt(seed % 5) };
        for (0..40) |i| {
            extension.author_name[i] = @truncate(@as(usize, seed) + i);
            extension.job_id[i] = @truncate(@as(usize, seed) + i + 1);
            extension.software_id[i] = @truncate(@as(usize, seed) + i + 2);
        }
        for (0..4) |row| for (0..80) |col| {
            extension.author_comment.lines[row][col] = @truncate(@as(usize, seed) + row * 80 + col);
        };
        const extension_copy = extension;
        extension.author_name[0] = 17;
        extension.author_comment.lines[3][79] = 18;
        extension.timestamp.year = 19;
        extension.job_id[39] = 20;
        extension.job_time.seconds = 21;
        extension.software_id[39] = 22;
        extension.software_version.letter = 23;
        extension.key_color.a = 24;
        extension.pixel_aspect.denominator = 25;
        extension.gamma_value.numerator = 26;
        extension.scanline_offset = 27;
        extension.attributes = .useful_alpha_channel;
        try out.print("EXTENSION|{d}|", .{seed});
        try bytes(out, extension_copy);
        try out.writeByte('|');
        try bytes(out, extension);
        try out.writeByte('\n');
        var footer: p.TGAFooter = .{ .extension_offset = @as(u32, seed) * 65537, .dev_area_offset = @as(u32, seed) * 65537 };
        for (0..16) |i| footer.signature[i] = @truncate(@as(usize, seed) + i);
        const footer_copy = footer;
        footer.extension_offset = 17;
        footer.signature[15] = 18;
        footer.dot = 19;
        footer.null_value = 20;
        try out.print("FOOTER|{d}|", .{seed});
        try bytes(out, footer_copy);
        try out.writeByte('|');
        try bytes(out, footer);
        try out.writeByte('\n');
    }
    var image_id = [_]u8{ 1, 2, 3 };
    var options: p.TGA.EncoderOptions = .{};
    try out.print("OPTIONS_DEFAULT|{}|{}|{d}|{d}|{d}|", .{ options.rle_compressed, options.top_to_bottom_image, options.color_map_depth, options.image_id.len, options.author_name.len });
    try bytes(out, options.author_comment);
    try out.writeByte('|');
    try bytes(out, options.timestamp);
    try out.print("|{d}|", .{options.job_id.len});
    try bytes(out, options.job_time);
    try out.print("|{d}|", .{options.software_id.len});
    try bytes(out, options.software_version);
    try out.writeByte('\n');
    options.rle_compressed = false;
    options.top_to_bottom_image = false;
    options.color_map_depth = 16;
    options.image_id = &image_id;
    options.author_name = "author";
    options.author_comment.lines[1][79] = 42;
    options.timestamp.year = 2026;
    options.job_id = "job";
    options.job_time.seconds = 17;
    options.software_id = "software";
    options.software_version = .{ .number = 123, .letter = 'v' };
    const copied = options;
    image_id[0] = 9;
    options.image_id = options.image_id[0..1];
    options.author_name = "new";
    options.author_comment.lines[1][79] = 43;
    options.timestamp.year = 2027;
    options.job_id = "new";
    options.job_time.seconds = 18;
    options.software_id = "new";
    options.software_version.number = 124;
    try out.print("OPTIONS_COPY|{}|{}|{d}|{x}|{s}|", .{ copied.rle_compressed, copied.top_to_bottom_image, copied.color_map_depth, copied.image_id, copied.author_name });
    try bytes(out, copied.author_comment);
    try out.writeByte('|');
    try bytes(out, copied.timestamp);
    try out.print("|{s}|", .{copied.job_id});
    try bytes(out, copied.job_time);
    try out.print("|{s}|", .{copied.software_id});
    try bytes(out, copied.software_version);
    try out.print("|{x}|{s}|", .{ options.image_id, options.author_name });
    try bytes(out, options.author_comment);
    try out.writeByte('|');
    try bytes(out, options.timestamp);
    try out.print("|{s}|", .{options.job_id});
    try bytes(out, options.job_time);
    try out.print("|{s}|", .{options.software_id});
    try bytes(out, options.software_version);
    try out.writeByte('\n');
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    if (args.len > 1) {
        if (std.mem.eql(u8, args[1], "--lengths")) {
            const e: p.TGAExtension = .{};
            var buffer: [256]u8 = undefined;
            var writer = std.fs.File.stdout().writer(&buffer);
            try writer.interface.print("{d},{d},{d},{d}\n", .{ e.author_name.len, e.job_id.len, e.software_id.len, e.author_comment.lines[0].len });
            try writer.interface.flush();
            return;
        }
        observed_path = args[2];
        if (std.mem.eql(u8, args[1], "--narrow")) narrow(args[3], try std.fmt.parseInt(u8, args[4], 10)) else if (std.mem.eql(u8, args[1], "--decode")) try decode(args[3]) else @panic("unknown mode");
        return;
    }
    var buffer: [8192]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&buffer);
    const out = &stdout.interface;
    for (0..256) |raw| {
        for (0..5) |field| for (0..(if (field == 4) @as(usize, 16) else 2)) |n| {
            var x: p.TGAImageType = @bitCast(@as(u8, @intCast(raw)));
            const copied = x;
            switch (field) {
                0 => x.indexed = n != 0,
                1 => x.truecolor = n != 0,
                2 => x.pad0 = n != 0,
                3 => x.run_length = n != 0,
                else => x.pad1 = @intCast(n),
            }
            try out.print("I|{d}|{d}|{d}|{d}|{}|{}|{}|{}|{d}|{d}\n", .{ raw, field, n, @as(u8, @bitCast(x)), x.indexed, x.truecolor, x.pad0, x.run_length, x.pad1, @as(u8, @bitCast(copied)) });
        };
        for (0..4) |field| for (0..([_]usize{ 16, 2, 2, 4 })[field]) |n| {
            var x: p.TGADescriptor = @bitCast(@as(u8, @intCast(raw)));
            const copied = x;
            switch (field) {
                0 => x.num_attributes_bit = @intCast(n),
                1 => x.right_to_left = n != 0,
                2 => x.top_to_bottom = n != 0,
                else => x.pad = @intCast(n),
            }
            try out.print("D|{d}|{d}|{d}|{d}|{d}|{}|{}|{d}|{d}\n", .{ raw, field, n, @as(u8, @bitCast(x)), x.num_attributes_bit, x.right_to_left, x.top_to_bottom, x.pad, @as(u8, @bitCast(copied)) });
        };
        for ([_]u8{ 0, 1, 2, 255 }) |map_type| for (0..256) |depth| {
            const header: p.TGAHeader = .{ .has_color_map = map_type, .image_type = @bitCast(@as(u8, @intCast(raw))), .color_map_spec = .{ .bit_depth = @intCast(depth) } };
            try out.print("VALID|{d}|{d}|{d}|{}\n", .{ raw, map_type, depth, header.isValid() });
        };
    }
    try records(out);
    try out.flush();
}
