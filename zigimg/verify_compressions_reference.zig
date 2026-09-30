// The runner copies this harness beside untouched locked source files so its
// private compression modules can be imported without modifying the package.
const std = @import("std");
const io = @import("src/io.zig");
const lzw = @import("src/compressions/lzw.zig");
const ccitt = @import("src/compressions/ccitt.zig");
const packbits = @import("src/compressions/packbits.zig");
const allocator = std.heap.page_allocator;
const Code = struct { value: u16, bits: u16 = 3 };

fn codeStream(comptime endian: std.builtin.Endian, output: []u8, codes: []const Code) ![]const u8 {
    var writer = std.Io.Writer.fixed(output);
    var bits = io.BitWriter(endian){ .writer = &writer };
    for (codes) |code| try bits.writeBits(code.value, code.bits);
    try bits.flushBits();
    return writer.buffered();
}

fn literalStream(comptime endian: std.builtin.Endian, output: []u8, initial: u8, early: u8, count: usize) ![]const u8 {
    var codes: [6000]Code = undefined;
    const roots = @as(u16, 1) << @intCast(initial);
    codes[0] = .{ .value = roots, .bits = initial + 1 };
    var next: u16 = roots + 2;
    var width: u16 = initial + 1;
    for (0..count) |i| {
        codes[i + 1] = .{ .value = @intCast(i % roots), .bits = width };
        if (i > 0) {
            next += 1;
            if (next == (@as(u16, 1) << @intCast(width)) - early and width < 12) width += 1;
        }
    }
    codes[count + 1] = .{ .value = roots + 1, .bits = width };
    return codeStream(endian, output, codes[0 .. count + 2]);
}

fn verifyLzw(comptime endian: std.builtin.Endian) !void {
    var input: [20000]u8 = undefined;
    var output: [6000]u8 = undefined;
    const Case = struct { codes: []const Code, expected: []const u8, next: u13, size: u8 };
    for ([_]Case{
        .{ .codes = &.{ .{ .value = 4 }, .{ .value = 0 }, .{ .value = 1 }, .{ .value = 6 }, .{ .value = 5, .bits = 4 } }, .expected = &.{ 0, 1, 0, 1 }, .next = 8, .size = 3 },
        .{ .codes = &.{ .{ .value = 4 }, .{ .value = 1 }, .{ .value = 6 }, .{ .value = 5 } }, .expected = &.{ 1, 1, 1 }, .next = 7, .size = 2 },
        .{ .codes = &.{ .{ .value = 4 }, .{ .value = 1 }, .{ .value = 7 }, .{ .value = 2 }, .{ .value = 5 } }, .expected = &.{ 1, 1, 1, 2 }, .next = 7, .size = 2 },
        .{ .codes = &.{ .{ .value = 7 }, .{ .value = 1 }, .{ .value = 5 } }, .expected = &.{1}, .next = 6, .size = 2 },
    }) |item| {
        const data = try codeStream(endian, &input, item.codes);
        var reader = io.ReadStream.initMemory(data);
        var writer = io.WriteStream.initMemory(&output);
        var decoder = try lzw.Decoder(endian).init(allocator, 2, 0);
        defer decoder.deinit();
        try decoder.decode(reader.reader(), writer.writer());
        try std.testing.expectEqualSlices(u8, item.expected, writer.memory.buffered());
        try std.testing.expectEqual(@as(u64, data.len), reader.getPos());
        try std.testing.expectEqual(item.next, decoder.next_code);
        try std.testing.expectEqual(item.size, decoder.code_size);
        try std.testing.expectEqual(@as(?u13, null), decoder.remaining_data);
        if (item.next == 8) {
            try std.testing.expectEqualSlices(u8, &.{ 0, 1 }, decoder.dictionary.get(6).?);
            try std.testing.expectEqualSlices(u8, &.{ 1, 0 }, decoder.dictionary.get(7).?);
        } else if (item.next == 7) {
            try std.testing.expectEqualSlices(u8, &.{ 1, 1 }, decoder.dictionary.get(6).?);
            try std.testing.expect(!decoder.dictionary.contains(7));
        }
    }
    for ([_]u8{ 0, 1 }) |early| {
        for ([_]u8{ 2, 8 }) |initial| {
            const count = 5120;
            var reader = io.ReadStream.initMemory(try literalStream(endian, &input, initial, early, count));
            var writer = io.WriteStream.initMemory(output[0..count]);
            var decoder = try lzw.Decoder(endian).init(allocator, initial, early);
            defer decoder.deinit();
            try decoder.decode(reader.reader(), writer.writer());
            try std.testing.expectEqual(@as(u64, count), writer.getPos());
            const roots = @as(u16, 1) << @intCast(initial);
            for (writer.memory.buffered(), 0..) |byte, i| try std.testing.expectEqual(@as(u8, @truncate(@as(u16, @intCast(i % roots)))), byte);
            try std.testing.expectEqual(@as(u8, 11), decoder.code_size);
            try std.testing.expectEqual(@as(u13, @intCast(roots + 1 + count)), decoder.next_code);
            try std.testing.expectEqual(@as(usize, roots + count - 1), decoder.dictionary.count());
            try std.testing.expectEqual(@as(?u13, null), decoder.remaining_data);
        }
    }
    const continuation = try codeStream(endian, &input, &.{ .{ .value = 4 }, .{ .value = 1 }, .{ .value = 6 }, .{ .value = 5 } });
    var reader = io.ReadStream.initMemory(continuation[0..1]);
    var writer = io.WriteStream.initMemory(&output);
    var decoder = try lzw.Decoder(endian).init(allocator, 2, 0);
    defer decoder.deinit();
    try decoder.decode(reader.reader(), writer.writer());
    try std.testing.expectEqualSlices(u8, &.{1}, writer.memory.buffered());
    try std.testing.expectEqual(@as(u4, 1), decoder.remaining_bits);
    try std.testing.expectEqual(@as(?u13, if (endian == .little) 2 else 3), decoder.remaining_data);
    try std.testing.expectEqual(@as(?u13, 1), decoder.previous_code);
    reader = io.ReadStream.initMemory(continuation[1..]);
    try decoder.decode(reader.reader(), writer.writer());
    try std.testing.expectEqualSlices(u8, &.{ 1, 1, 1 }, writer.memory.buffered());
    try std.testing.expectEqual(@as(?u13, 6), decoder.previous_code);
    try std.testing.expectEqual(@as(?u13, null), decoder.remaining_data);
    try std.testing.expectEqual(@as(u13, 7), decoder.next_code);
    var empty_resume = try lzw.Decoder(endian).init(allocator, 2, 0);
    defer empty_resume.deinit();
    reader = io.ReadStream.initMemory(continuation[0..1]);
    try writer.seekTo(0);
    try empty_resume.decode(reader.reader(), writer.writer());
    reader = io.ReadStream.initMemory("");
    try empty_resume.decode(reader.reader(), writer.writer());
    try std.testing.expectEqual(@as(?u13, null), empty_resume.remaining_data);
    try std.testing.expectEqual(@as(u4, 1), empty_resume.remaining_bits);
    try std.testing.expectEqual(@as(?u13, 1), empty_resume.previous_code);
    try std.testing.expectEqualSlices(u8, &.{1}, writer.memory.buffered());

    for ([_]bool{ false, true }) |absent| {
        const codes: []const Code = if (absent) &.{ .{ .value = 4 }, .{ .value = 1 }, .{ .value = 6 }, .{ .value = 5 } } else &.{ .{ .value = 4 }, .{ .value = 0 }, .{ .value = 1 }, .{ .value = 6 }, .{ .value = 5, .bits = 4 } };
        reader = io.ReadStream.initMemory(try codeStream(endian, &input, codes));
        writer = io.WriteStream.initMemory(output[0..if (absent) @as(usize, 2) else 3]);
        var failure = try lzw.Decoder(endian).init(allocator, 2, 0);
        defer failure.deinit();
        try std.testing.expectError(error.WriteFailed, failure.decode(reader.reader(), writer.writer()));
        try std.testing.expectEqual(@as(u64, 2), reader.getPos());
        try std.testing.expectEqual(@as(?u13, 1), failure.previous_code);
        try std.testing.expectEqual(@as(u13, if (absent) 6 else 7), failure.next_code);
        try std.testing.expectEqualSlices(u8, if (absent) &.{ 1, 1 } else &.{ 0, 1 }, failure.dictionary.get(6).?);
        try std.testing.expect(!failure.dictionary.contains(7));
        try std.testing.expectEqualSlices(u8, if (absent) &.{ 1, 1 } else &.{ 0, 1, 0 }, writer.memory.buffered());
    }
    reader = io.ReadStream.initMemory(if (endian == .little) &.{65} else &.{32});
    writer = io.WriteStream.initMemory(&output);
    var partial = try lzw.Decoder(endian).init(allocator, 8, 0);
    defer partial.deinit();
    try partial.decode(reader.reader(), writer.writer());
    try std.testing.expectEqualSlices(u8, if (endian == .little) &.{65} else &.{32}, writer.memory.buffered());
    try std.testing.expectEqual(@as(?u13, if (endian == .little) 65 else 32), partial.previous_code);
    try std.testing.expectEqual(@as(?u13, 0), partial.remaining_data);
    try std.testing.expectEqual(@as(u4, 9), partial.remaining_bits);
    try std.testing.expectEqual(@as(u13, 258), partial.next_code);
}

fn verifyPackbits() !void {
    const Case = struct { input: []const u8, length: u32, expected: []const u8, pos: u64 };
    for ([_]Case{
        .{ .input = &.{ 0, 7 }, .length = 2, .expected = &.{7}, .pos = 2 },
        .{ .input = &.{ 2, 1, 2, 3, 255, 9 }, .length = 6, .expected = &.{ 1, 2, 3, 9, 9 }, .pos = 6 },
        .{ .input = &.{ 128, 128, 0, 7, 128 }, .length = 5, .expected = &.{7}, .pos = 4 },
        .{ .input = &.{ 3, 1, 2, 3, 4 }, .length = 3, .expected = &.{ 1, 2 }, .pos = 3 },
        .{ .input = &.{ 128, 255, 9 }, .length = 2, .expected = &.{}, .pos = 1 },
        .{ .input = &.{}, .length = 1, .expected = &.{}, .pos = 0 },
    }) |item| {
        var output = [_]u8{99} ** 140;
        var reader = io.ReadStream.initMemory(item.input);
        try packbits.decode(&reader, &output, item.length);
        try std.testing.expectEqualSlices(u8, item.expected, output[0..item.expected.len]);
        for (output[item.expected.len..]) |byte| try std.testing.expectEqual(@as(u8, 99), byte);
        try std.testing.expectEqual(item.pos, reader.getPos());
    }
    var output: [128]u8 = undefined;
    var reader = io.ReadStream.initMemory(&.{ 129, 8 });
    try packbits.decode(&reader, &output, 2);
    try std.testing.expectEqualSlices(u8, &([_]u8{8} ** 128), &output);
    reader = io.ReadStream.initMemory(&([_]u8{127} ++ [_]u8{6} ** 128));
    try packbits.decode(&reader, &output, 129);
    try std.testing.expectEqualSlices(u8, &([_]u8{6} ** 128), &output);
    for ([_][]const u8{ &.{ 2, 1, 2 }, &.{255}, &.{} }) |input| {
        @memset(&output, 99);
        reader = io.ReadStream.initMemory(input);
        try std.testing.expectError(error.EndOfStream, packbits.decode(&reader, &output, 4));
        try std.testing.expectEqual(@as(u64, input.len), reader.getPos());
        try std.testing.expectEqualSlices(u8, if (input.len == 3) &.{ 1, 2, 99, 99 } else &.{ 99, 99, 99, 99 }, output[0..4]);
    }
}

fn verifyCcitt() !void {
    var hash: u64 = 0xcbf29ce484222325;
    inline for (.{ ccitt.white_terminating_codes, ccitt.black_terminating_codes, ccitt.white_make_up_codes, ccitt.black_make_up_codes, ccitt.additional_make_up_codes }) |table| {
        for (table) |item| {
            const bytes = [_]u8{ @truncate(item.run_length), @truncate(item.run_length >> 8), @truncate(item.code), @truncate(item.code >> 8), item.code_length };
            for (bytes) |byte| hash = (hash ^ byte) *% 0x100000001b3;
        }
    }
    try std.testing.expectEqual(@as(u64, 0x8aa26e4c9fe26ada), hash);
    var lookup = try ccitt.Decoder.init(8, 1, 1);
    for ([_]ccitt.Color{ .white, .black }) |color| {
        lookup.current_color = color;
        const terminating = if (color == .white) ccitt.white_terminating_codes else ccitt.black_terminating_codes;
        const make_up = if (color == .white) ccitt.white_make_up_codes else ccitt.black_make_up_codes;
        for (terminating) |item| {
            lookup.should_reverse = false;
            try std.testing.expectEqual(@as(?u16, item.run_length), lookup.get_run_length(@intCast(item.code), item.code_length));
            try std.testing.expect(lookup.should_reverse);
        }
        for (make_up) |item| {
            lookup.should_reverse = false;
            try std.testing.expectEqual(@as(?u16, item.run_length), lookup.get_run_length(@intCast(item.code), item.code_length));
            try std.testing.expect(!lookup.should_reverse);
        }
        for (ccitt.additional_make_up_codes) |item| try std.testing.expectEqual(@as(?u16, item.run_length), lookup.get_run_length(@intCast(item.code), item.code_length));
        try std.testing.expectEqual(@as(?u16, null), lookup.get_run_length(0, 14));
    }
    const Case = struct { width: usize, rows: usize = 1, input: []const u8, expected: []const u8, color: ccitt.Color = .black, pos: u64 };
    for ([_]u1{ 0, 1 }) |white| {
        for ([_]Case{
            .{ .width = 8, .input = &.{0x98}, .expected = &.{0xff}, .pos = 1 },
            .{ .width = 8, .input = &.{ 0x35, 0x14 }, .expected = &.{0}, .color = .white, .pos = 2 },
            .{ .width = 8, .input = &.{0xb6}, .expected = &.{0xf0}, .color = .white, .pos = 1 },
            .{ .width = 7, .input = &.{0xf0}, .expected = &.{}, .pos = 1 },
            .{ .width = 15, .input = &.{0xd4}, .expected = &.{0xff}, .pos = 1 },
            .{ .width = 65, .input = &.{ 0xd8, 0xe0 }, .expected = &([_]u8{255} ** 8), .pos = 2 },
            .{ .width = 64, .input = &.{ 0xd9, 0xa8 }, .expected = &([_]u8{255} ** 8), .color = .white, .pos = 1 },
            .{ .width = 8, .rows = 2, .input = &.{ 0x98, 0x14 }, .expected = &.{ 255, 0 }, .color = .white, .pos = 2 },
            .{ .width = 8, .rows = 3, .input = &.{ 0x98, 0x14, 0x13 }, .expected = &.{ 255, 0, 255 }, .pos = 3 },
        }) |item| {
            var output: [32]u8 = undefined;
            var reader = io.ReadStream.initMemory(item.input);
            var writer = io.WriteStream.initMemory(output[0..item.expected.len]);
            var decoder = try ccitt.Decoder.init(item.width, item.rows, white);
            try decoder.decode(reader.reader(), writer.writer());
            try std.testing.expectEqual(@as(usize, item.expected.len), writer.memory.buffered().len);
            for (writer.memory.buffered(), item.expected) |actual, expected| try std.testing.expectEqual(if (white == 1) expected else expected ^ 255, actual);
            try std.testing.expectEqual(item.pos, reader.getPos());
            try std.testing.expectEqual(item.color, decoder.current_color);
            try std.testing.expect(!decoder.should_reverse);
        }
    }
    for ([_][]const u8{ "", &.{ 0, 0 } }) |input| {
        var output: [1]u8 = undefined;
        var reader = io.ReadStream.initMemory(input);
        var writer = io.WriteStream.initMemory(&output);
        var decoder = try ccitt.Decoder.init(8, 1, 1);
        try std.testing.expectError(error.InvalidData, decoder.decode(reader.reader(), writer.writer()));
        try std.testing.expectEqual(@as(u64, input.len), reader.getPos());
        try std.testing.expectEqual(@as(u64, 0), writer.getPos());
    }
    var reader = io.ReadStream.initMemory(&.{0x98});
    var writer = io.WriteStream.initMemory(&.{});
    var decoder = try ccitt.Decoder.init(8, 1, 1);
    try std.testing.expectError(error.WriteFailed, decoder.decode(reader.reader(), writer.writer()));
    try std.testing.expectEqual(@as(u64, 1), reader.getPos());
    try std.testing.expect(decoder.current_color == .white and decoder.should_reverse);
}

pub fn main() !void {
    try verifyLzw(.little);
    try verifyLzw(.big);
    try verifyPackbits();
    try verifyCcitt();
    std.debug.print("PASS: locked LZW, PackBits, and CCITT compression reference checks\n", .{});
}
