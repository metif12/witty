const std = @import("std");
const utils = @import("src/utils.zig");
const png = @import("src/formats/png/types.zig");
const Code = enum(u16) { zero, one, large = 0x1234 };
const Color = enum(u8) { zero, two = 2, six = 6 };
const Inner = extern struct { color: Color, flag: bool, bytes: [3]u8 };
const Header = extern struct { value: u32, signed_value: i16, code: Code, inner: Inner, bytes: [2]u8 };
const AliasCode = Code;
const AliasByte = u8;
const AliasBytes = [2]AliasByte;
const AliasWord = u16;
const AliasFlag = bool;
const AliasCompression = png.CompressionMethod;
const AliasFilter = png.FilterMethod;
const AliasInnerFields = extern struct { code: AliasCode, flag: AliasFlag, bytes: AliasBytes };
const AliasInner = AliasInnerFields;
const AliasHeaderFields = extern struct { number: AliasWord, inner: AliasInner, compression: AliasCompression, filter: AliasFilter };
const AliasHeader = AliasHeaderFields;
const alias_little: std.builtin.Endian = .little;
const alias_big: std.builtin.Endian = .big;

fn aliases(out: *std.Io.Writer) !void {
    for (0..5) |length| {
        for (0..256) |seed| {
            var bytes: [4]u8 = undefined;
            for (0..length) |index| bytes[index] = @truncate(seed + index * 71);
            try out.print("am:{d}:{d}|{x:0>8}:{x:0>8}\n", .{ length, seed, utils.toMagicNumber(bytes[0..length], alias_little), utils.toMagicNumber(bytes[0..length], alias_big) });
        }
    }
    std.debug.assert(@sizeOf(AliasHeader) == 10);
    for (0..256) |compression| {
        for ([_]u16{ 0, 1, 0x1234, 0xabcd }) |code| {
            for (0..13) |length| {
                var bytes: [12]u8 = undefined;
                for (&bytes, 0..) |*byte, index| byte.* = @truncate(compression + index * 37);
                bytes[2] = @truncate(code >> 8);
                bytes[3] = @truncate(code);
                bytes[4] = @intCast(compression & 1);
                bytes[8] = @intCast(compression);
                bytes[9] = @intCast(255 - compression);
                inline for (0..4) |mode| {
                    var reader = std.Io.Reader.fixed(bytes[0..length]);
                    const result = switch (mode) {
                        0 => utils.takeStructNative(&reader, AliasHeader),
                        1 => utils.takeStructForeign(&reader, AliasHeader),
                        2 => utils.takeStruct(&reader, AliasHeader, alias_big),
                        3 => utils.takeStruct(&reader, AliasHeader, alias_little),
                        else => unreachable,
                    };
                    if (result) |value| {
                        try out.print("as:{d}:{d}:{d}:{d}|{d}:{d}:{d}:{}:{d}:{d}:{d}:{d}\n", .{ compression, code, length, mode, reader.seek, value.number, @intFromEnum(value.inner.code), value.inner.flag, value.inner.bytes[0], value.inner.bytes[1], @intFromEnum(value.compression), @intFromEnum(value.filter) });
                    } else |err| {
                        try out.print("as:{d}:{d}:{d}:{d}|{d}:{s}\n", .{ compression, code, length, mode, reader.seek, @errorName(err) });
                    }
                }
            }
        }
    }
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    var output = std.fs.File.stdout().writer(&.{});
    const out = &output.interface;
    if (args.len > 1) {
        if (std.mem.eql(u8, args[1], "aliases")) {
            try aliases(out);
            return;
        }
        const bytes = [_]u8{0} ** 5;
        if (std.mem.eql(u8, args[1], "native")) {
            _ = utils.toMagicNumberNative(&bytes);
        } else {
            _ = utils.toMagicNumberForeign(&bytes);
        }
        std.debug.print("UNEXPECTED\n", .{});
        return;
    }
    for (0..5) |length| {
        for (0..256) |seed| {
            var bytes: [4]u8 = undefined;
            for (0..length) |index| bytes[index] = @truncate(seed + index * 71);
            const magic = bytes[0..length];
            try out.print("m:{d}:{d}|{x:0>8}:{x:0>8}:{x:0>8}:{x:0>8}\n", .{ length, seed, utils.toMagicNumberNative(magic), utils.toMagicNumberForeign(magic), utils.toMagicNumber(magic, .little), utils.toMagicNumber(magic, .big) });
        }
    }
    std.debug.assert(@sizeOf(Header) == 16);
    for (0..16) |seed| {
        for ([_]u16{ 0, 1, 0x1234, 0xabcd }) |code| {
            for ([_]u8{ 0, 2, 6, 3 }) |color| {
                for (0..19) |length| {
                    var bytes: [18]u8 = undefined;
                    for (&bytes, 0..) |*byte, i| byte.* = @truncate(seed * 13 + i * 37);
                    bytes[6] = @truncate(code >> 8);
                    bytes[7] = @truncate(code);
                    bytes[8] = color;
                    bytes[9] = @truncate(seed & 1);
                    inline for (0..4) |mode| {
                        var reader = std.Io.Reader.fixed(bytes[0..length]);
                        const result = switch (mode) {
                            0 => utils.takeStructNative(&reader, Header),
                            1 => utils.takeStructForeign(&reader, Header),
                            2 => utils.takeStruct(&reader, Header, .big),
                            3 => utils.takeStruct(&reader, Header, .little),
                            else => unreachable,
                        };
                        if (result) |value| {
                            try out.print("s:{d}:{d}:{d}:{d}:{d}|{d}:{d}:{d}:{d}:{d}:{}:{d}:{d}:{d}:{d}:{d}\n", .{ seed, code, color, length, mode, reader.seek, value.value, value.signed_value, @intFromEnum(value.code), @intFromEnum(value.inner.color), value.inner.flag, value.inner.bytes[0], value.inner.bytes[1], value.inner.bytes[2], value.bytes[0], value.bytes[1] });
                        } else |err| {
                            try out.print("s:{d}:{d}:{d}:{d}:{d}|{d}:{s}\n", .{ seed, code, color, length, mode, reader.seek, @errorName(err) });
                        }
                    }
                }
            }
        }
    }
    for (0..256) |compression| {
        const bytes = [_]u8{ 0, 0, 0, 1, 0, 0, 0, 1, 8, 2, @intCast(compression), @intCast(255 - compression), 0 };
        var reader = std.Io.Reader.fixed(&bytes);
        const value = try utils.takeStruct(&reader, png.HeaderData, .big);
        try out.print("p:{d}|{d}:{d}:{d}\n", .{ compression, reader.seek, @intFromEnum(value.compression_method), @intFromEnum(value.filter_method) });
    }
}
