const std = @import("std");
const io = @import("src/io.zig");
const AliasU8 = u8;
const AliasU16 = u16;
const AliasU32 = u32;
const AliasU64 = u64;
const AliasI8 = i8;
const AliasI16 = i16;
const AliasInt = i32;
const AliasI64 = i64;
const AliasFloat = f32;
const AliasDouble = f64;
const AliasUsize = usize;
const AliasIsize = isize;

fn decimal(comptime T: type, text: []const u8) !T {
    return std.fmt.parseInt(T, text, 10);
}
fn bytes(text: []const u8) ![]u8 {
    const output = try std.heap.page_allocator.alloc(u8, text.len / 2);
    _ = try std.fmt.hexToBytes(output, text);
    return output;
}
fn hex(writer: *std.Io.Writer, data: []const u8) !void {
    for (data) |byte| try writer.print("{x:0>2}", .{byte});
}
fn valueBits(comptime T: type, value: T) u64 {
    const U = std.meta.Int(.unsigned, @bitSizeOf(T));
    return @as(U, @bitCast(value));
}
fn valueFromBits(comptime T: type, value: u64) T {
    const U = std.meta.Int(.unsigned, @bitSizeOf(T));
    return @bitCast(@as(U, @truncate(value)));
}
fn emitReader(comptime endian: std.builtin.Endian, writer: *std.Io.Writer, bits: io.BitReader(endian), input: *const io.ReadStream) !void {
    try writer.print("@{d}:{d}:{d};", .{ bits.bits, bits.count, input.getPos() });
}
fn bitReads(comptime endian: std.builtin.Endian, comptime T: type, writer: *std.Io.Writer, data: []const u8, actions: []const u8) !void {
    var input = io.ReadStream.initMemory(data);
    var bits: io.BitReader(endian) = .{ .reader = input.reader() };
    var it = std.mem.splitScalar(u8, actions, ',');
    while (it.next()) |action| {
        if (std.mem.eql(u8, action, "a")) {
            bits.alignToByte();
            try writer.writeAll("Ok");
            try emitReader(endian, writer, bits, &input);
            continue;
        }
        if (action[0] == 's') {
            input.seekTo(try decimal(u64, action[1..])) catch |err| {
                try writer.writeAll(@errorName(err));
                try emitReader(endian, writer, bits, &input);
                continue;
            };
            try writer.writeAll("Ok");
            try emitReader(endian, writer, bits, &input);
            continue;
        }
        const num = try decimal(u16, action[1..]);
        switch (action[0]) {
            't' => {
                const value, const count = bits.readBitsTuple(T, num) catch |err| {
                    try writer.writeAll(@errorName(err));
                    try emitReader(endian, writer, bits, &input);
                    continue;
                };
                try writer.print("Ok:{d}:{d}", .{ valueBits(T, value), count });
            },
            'r' => {
                var count: u16 = 999;
                const value = bits.readBits(T, num, &count) catch |err| {
                    try writer.print("{s}:{d}", .{ @errorName(err), count });
                    try emitReader(endian, writer, bits, &input);
                    continue;
                };
                try writer.print("Ok:{d}:{d}", .{ valueBits(T, value), count });
            },
            else => {
                const value = bits.readBitsNoEof(T, num) catch |err| {
                    try writer.writeAll(@errorName(err));
                    try emitReader(endian, writer, bits, &input);
                    continue;
                };
                try writer.print("Ok:{d}", .{valueBits(T, value)});
            },
        }
        try emitReader(endian, writer, bits, &input);
    }
}
fn bitWrites(comptime endian: std.builtin.Endian, comptime T: type, writer: *std.Io.Writer, capacity: usize, actions: []const u8) !void {
    const data = try std.heap.page_allocator.alloc(u8, capacity);
    @memset(data, 0xa5);
    var output = io.WriteStream.initMemory(data);
    var bits: io.BitWriter(endian) = .{ .writer = output.writer() };
    var it = std.mem.splitScalar(u8, actions, ',');
    while (it.next()) |action| {
        var status: []const u8 = "Ok";
        if (std.mem.eql(u8, action, "f")) {
            bits.flushBits() catch |err| {
                status = @errorName(err);
            };
        } else if (action[0] == 's') {
            output.seekTo(try decimal(u64, action[1..])) catch |err| {
                status = @errorName(err);
            };
        } else {
            var parts = std.mem.splitScalar(u8, action[1..], ':');
            const num = try decimal(u16, parts.next().?);
            const raw = try decimal(u64, parts.next().?);
            bits.writeBits(valueFromBits(T, raw), num) catch |err| {
                status = @errorName(err);
            };
        }
        try writer.print("{s}@{d}:{d}:{d}:", .{ status, bits.bits, bits.count, output.getPos() });
        try hex(writer, data);
        try writer.writeByte(';');
    }
}
fn bitCase(comptime endian: std.builtin.Endian, comptime T: type, writer: *std.Io.Writer, mode: u8, data: []const u8, capacity: usize, actions: []const u8) !void {
    if (mode == 0) try bitReads(endian, T, writer, data, actions) else try bitWrites(endian, T, writer, capacity, actions);
}
fn integerCase(comptime endian: std.builtin.Endian, comptime T: type, writer: *std.Io.Writer, data: []const u8, capacity: usize, raw: u64) !void {
    var input = io.ReadStream.initMemory(data);
    const reader = input.reader();
    for ([_]u64{ 0, 1 }) |position| {
        var status: []const u8 = "Ok";
        input.seekTo(position) catch |err| {
            status = @errorName(err);
        };
        try writer.print("{s}:", .{status});
        const value = reader.takeInt(T, endian) catch |err| blk: {
            status = @errorName(err);
            break :blk @as(T, 0);
        };
        try writer.print("{s}:{d}@{d};", .{ status, valueBits(T, value), input.getPos() });
    }
    const data_out = try std.heap.page_allocator.alloc(u8, capacity);
    @memset(data_out, 0xa5);
    var output = io.WriteStream.initMemory(data_out);
    const adapter = output.writer();
    for (0..2) |_| {
        var status: []const u8 = "Ok";
        adapter.writeInt(T, valueFromBits(T, raw), endian) catch |err| {
            status = @errorName(err);
        };
        try writer.print("{s}@{d}:", .{ status, output.getPos() });
        try hex(writer, data_out);
        try writer.writeByte(';');
    }
}
fn dispatchInteger(comptime endian: std.builtin.Endian, writer: *std.Io.Writer, kind: u8, data: []const u8, capacity: usize, raw: u64) !void {
    switch (kind) {
        0 => try integerCase(endian, u8, writer, data, capacity, raw),
        1 => try integerCase(endian, u16, writer, data, capacity, raw),
        2 => try integerCase(endian, u32, writer, data, capacity, raw),
        3 => try integerCase(endian, u64, writer, data, capacity, raw),
        4 => try integerCase(endian, i8, writer, data, capacity, raw),
        5 => try integerCase(endian, i16, writer, data, capacity, raw),
        6 => try integerCase(endian, i32, writer, data, capacity, raw),
        7 => try integerCase(endian, i64, writer, data, capacity, raw),
        10 => try integerCase(endian, usize, writer, data, capacity, raw),
        11 => try integerCase(endian, isize, writer, data, capacity, raw),
        12 => try integerCase(endian, AliasU8, writer, data, capacity, raw),
        13 => try integerCase(endian, AliasU16, writer, data, capacity, raw),
        14 => try integerCase(endian, AliasU32, writer, data, capacity, raw),
        15 => try integerCase(endian, AliasU64, writer, data, capacity, raw),
        16 => try integerCase(endian, AliasI8, writer, data, capacity, raw),
        17 => try integerCase(endian, AliasI16, writer, data, capacity, raw),
        18 => try integerCase(endian, AliasInt, writer, data, capacity, raw),
        19 => try integerCase(endian, AliasI64, writer, data, capacity, raw),
        22 => try integerCase(endian, AliasUsize, writer, data, capacity, raw),
        23 => try integerCase(endian, AliasIsize, writer, data, capacity, raw),
        else => return error.InvalidType,
    }
}
fn dispatch(comptime endian: std.builtin.Endian, writer: *std.Io.Writer, mode: u8, kind: u8, data: []const u8, capacity: usize, actions: []const u8) !void {
    switch (kind) {
        0 => try bitCase(endian, u8, writer, mode, data, capacity, actions),
        1 => try bitCase(endian, u16, writer, mode, data, capacity, actions),
        2 => try bitCase(endian, u32, writer, mode, data, capacity, actions),
        3 => try bitCase(endian, u64, writer, mode, data, capacity, actions),
        4 => try bitCase(endian, i8, writer, mode, data, capacity, actions),
        5 => try bitCase(endian, i16, writer, mode, data, capacity, actions),
        6 => try bitCase(endian, i32, writer, mode, data, capacity, actions),
        7 => try bitCase(endian, i64, writer, mode, data, capacity, actions),
        8 => try bitCase(endian, f32, writer, mode, data, capacity, actions),
        9 => try bitCase(endian, f64, writer, mode, data, capacity, actions),
        10 => try bitCase(endian, usize, writer, mode, data, capacity, actions),
        11 => try bitCase(endian, isize, writer, mode, data, capacity, actions),
        12 => try bitCase(endian, AliasU8, writer, mode, data, capacity, actions),
        13 => try bitCase(endian, AliasU16, writer, mode, data, capacity, actions),
        14 => try bitCase(endian, AliasU32, writer, mode, data, capacity, actions),
        15 => try bitCase(endian, AliasU64, writer, mode, data, capacity, actions),
        16 => try bitCase(endian, AliasI8, writer, mode, data, capacity, actions),
        17 => try bitCase(endian, AliasI16, writer, mode, data, capacity, actions),
        18 => try bitCase(endian, AliasInt, writer, mode, data, capacity, actions),
        19 => try bitCase(endian, AliasI64, writer, mode, data, capacity, actions),
        20 => try bitCase(endian, AliasFloat, writer, mode, data, capacity, actions),
        21 => try bitCase(endian, AliasDouble, writer, mode, data, capacity, actions),
        22 => try bitCase(endian, AliasUsize, writer, mode, data, capacity, actions),
        23 => try bitCase(endian, AliasIsize, writer, mode, data, capacity, actions),
        else => return error.InvalidType,
    }
}
fn emitStream(writer: *std.Io.Writer, input: *io.ReadStream) !void {
    try writer.print("@{d}:", .{input.getPos()});
    const end = input.getEndPos() catch |err| {
        try writer.print("{s};", .{@errorName(err)});
        return;
    };
    try writer.print("{d};", .{end});
}
fn byteReads(writer: *std.Io.Writer, mode: u8, data: []const u8, capacity: usize, actions: []const u8, path: []const u8) !void {
    const allocator = std.heap.page_allocator;
    const buffer = try allocator.alloc(u8, capacity);
    @memset(buffer, 0xa5);
    var file: std.fs.File = undefined;
    var closed = true;
    var input = io.ReadStream.initMemory(data);
    if (mode == 3 or mode == 9) {
        file = try std.fs.cwd().createFile(path, .{ .read = true });
        try file.writeAll(data);
        closed = false;
        if (mode == 9) {
            try file.seekTo(1);
            input = .{ .file = file.readerStreaming(buffer) };
        } else input = io.ReadStream.initFile(file, buffer);
    }
    defer if (!closed) file.close();
    const reader = input.reader();
    var it = std.mem.splitScalar(u8, actions, ',');
    while (it.next()) |action| {
        var status: []const u8 = "Ok";
        switch (action[0]) {
            'p', 't', 'q', 'd', 'b' => {
                var byte: [1]u8 = undefined;
                const content: []const u8 = switch (action[0]) {
                    'p' => reader.peek(try decimal(usize, action[1..])) catch |err| blk: {
                        status = @errorName(err);
                        break :blk "";
                    },
                    't' => reader.take(try decimal(usize, action[1..])) catch |err| blk: {
                        status = @errorName(err);
                        break :blk "";
                    },
                    'q' => reader.peekDelimiterInclusive(try decimal(u8, action[1..])) catch |err| blk: {
                        status = @errorName(err);
                        break :blk "";
                    },
                    'd' => reader.takeDelimiterInclusive(try decimal(u8, action[1..])) catch |err| blk: {
                        status = @errorName(err);
                        break :blk "";
                    },
                    else => blk: {
                        byte[0] = reader.takeByte() catch |err| {
                            status = @errorName(err);
                            break :blk "";
                        };
                        break :blk &byte;
                    },
                };
                try writer.print("{s}:", .{status});
                try hex(writer, content);
            },
            'h', 'l' => {
                const content = try allocator.alloc(u8, try decimal(usize, action[1..]));
                @memset(content, 0xa5);
                if (action[0] == 'h') {
                    const count = reader.readSliceShort(content) catch |err| blk: {
                        status = @errorName(err);
                        break :blk 0;
                    };
                    try writer.print("{s}:{d}:", .{ status, count });
                } else {
                    reader.readSliceAll(content) catch |err| {
                        status = @errorName(err);
                    };
                    try writer.print("{s}:", .{status});
                }
                try hex(writer, content);
            },
            's' => {
                input.seekTo(try decimal(u64, action[1..])) catch |err| {
                    status = @errorName(err);
                };
                try writer.writeAll(status);
            },
            'y' => {
                input.seekBy(try decimal(i64, action[1..])) catch |err| {
                    status = @errorName(err);
                };
                try writer.writeAll(status);
            },
            'x' => {
                reader.discardAll(try decimal(usize, action[1..])) catch |err| {
                    status = @errorName(err);
                };
                try writer.writeAll(status);
            },
            'o' => {
                reader.toss(try decimal(usize, action[1..]));
                try writer.writeAll(status);
            },
            'z' => {
                try file.setEndPos(0);
                try file.pwriteAll(try bytes(action[1..]), 0);
                try writer.writeAll(status);
            },
            'c' => {
                file.close();
                closed = true;
                try writer.writeAll(status);
            },
            'g' => try writer.print("{d}", .{reader.bufferedLen()}),
            'e' => try writer.writeAll(status),
            else => return error.InvalidReadAction,
        }
        try emitStream(writer, &input);
    }
}
fn byteWrites(writer: *std.Io.Writer, mode: u8, capacity: usize, actions: []const u8, path: []const u8) !void {
    const allocator = std.heap.page_allocator;
    const buffer = try allocator.alloc(u8, capacity);
    @memset(buffer, 0xa5);
    var file: std.fs.File = undefined;
    var closed = true;
    var output = io.WriteStream.initMemory(buffer);
    if (mode == 5 or mode == 10) {
        file = try std.fs.cwd().createFile(path, .{ .read = true });
        closed = false;
        if (mode == 10) {
            try file.writeAll("~");
            output = .{ .file = file.writerStreaming(buffer) };
        } else output = io.WriteStream.initFile(file, buffer);
    }
    defer if (!closed) file.close();
    const adapter = output.writer();
    var it = std.mem.splitScalar(u8, actions, ',');
    while (it.next()) |action| {
        var status: []const u8 = "Ok";
        switch (action[0]) {
            'w' => {
                const count = adapter.write(try bytes(action[1..])) catch |err| blk: {
                    status = @errorName(err);
                    break :blk 0;
                };
                try writer.print("{s}:{d}", .{ status, count });
            },
            'a' => {
                adapter.writeAll(try bytes(action[1..])) catch |err| {
                    status = @errorName(err);
                };
                try writer.writeAll(status);
            },
            'b' => {
                adapter.writeByte(try decimal(u8, action[1..])) catch |err| {
                    status = @errorName(err);
                };
                try writer.writeAll(status);
            },
            'f' => {
                adapter.flush() catch |err| {
                    status = @errorName(err);
                };
                try writer.writeAll(status);
            },
            's' => {
                output.seekTo(try decimal(u64, action[1..])) catch |err| {
                    status = @errorName(err);
                };
                try writer.writeAll(status);
            },
            'c' => {
                file.close();
                closed = true;
                try writer.writeAll(status);
            },
            else => return error.InvalidWriteAction,
        }
        try writer.print("@{d}:", .{output.getPos()});
        try hex(writer, adapter.buffered());
        try writer.writeByte(':');
        if (mode == 5 or mode == 10) {
            try hex(writer, try std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024));
        } else try hex(writer, buffer);
        try writer.writeByte(';');
    }
}
fn pipeWrites(writer: *std.Io.Writer, capacity: usize, actions: []const u8) !void {
    const fds = try std.posix.pipe2(.{ .NONBLOCK = true });
    defer std.posix.close(fds[0]);
    var closed = false;
    defer if (!closed) std.posix.close(fds[1]);
    const buffer = try std.heap.page_allocator.alloc(u8, capacity);
    @memset(buffer, 0xa5);
    var output = io.WriteStream.initFile(.{ .handle = fds[1] }, buffer);
    const adapter = output.writer();
    var delivered: std.Io.Writer.Allocating = .init(std.heap.page_allocator);
    var it = std.mem.splitScalar(u8, actions, ',');
    while (it.next()) |action| {
        var status: []const u8 = "Ok";
        switch (action[0]) {
            'w' => {
                const count = adapter.write(try bytes(action[1..])) catch |err| blk: {
                    status = @errorName(err);
                    break :blk 0;
                };
                try writer.print("{s}:{d}", .{ status, count });
            },
            'a' => {
                adapter.writeAll(try bytes(action[1..])) catch |err| {
                    status = @errorName(err);
                };
                try writer.writeAll(status);
            },
            'b' => {
                adapter.writeByte(try decimal(u8, action[1..])) catch |err| {
                    status = @errorName(err);
                };
                try writer.writeAll(status);
            },
            'f' => {
                adapter.flush() catch |err| {
                    status = @errorName(err);
                };
                try writer.writeAll(status);
            },
            's' => {
                output.seekTo(try decimal(u64, action[1..])) catch |err| {
                    status = @errorName(err);
                };
                try writer.writeAll(status);
            },
            'c' => {
                std.posix.close(fds[1]);
                closed = true;
                try writer.writeAll(status);
            },
            else => return error.InvalidPipeAction,
        }
        var target: [128]u8 = undefined;
        while (true) {
            const n = std.posix.read(fds[0], &target) catch |err| switch (err) {
                error.WouldBlock => break,
                else => return err,
            };
            if (n == 0) break;
            try delivered.writer.writeAll(target[0..n]);
        }
        try writer.print("@{d}:", .{output.getPos()});
        try hex(writer, adapter.buffered());
        try writer.writeByte(':');
        try hex(writer, delivered.written());
        try writer.writeByte(';');
    }
}
fn trap(code: u8, path: []const u8) !void {
    var data: [32]u8 = @splat(0xab);
    var input = io.ReadStream.initMemory(&data);
    var output = io.WriteStream.initMemory(&data);
    switch (code) {
        0 => {
            _ = try input.reader().takeByte();
            try input.seekBy(std.math.maxInt(i64));
        },
        1 => {
            var bits: io.BitReader(.little) = .{ .reader = input.reader() };
            _ = try bits.readBitsTuple(u8, 16);
        },
        2 => {
            var bits: io.BitReader(.little) = .{ .reader = input.reader() };
            _ = try bits.readBitsTuple(u16, 17);
        },
        3 => {
            var bits: io.BitWriter(.big) = .{ .writer = output.writer() };
            try bits.writeBits(@as(u8, 0xab), 16);
        },
        4 => {
            var bits: io.BitWriter(.big) = .{ .writer = output.writer() };
            try bits.writeBits(@as(u8, 1), 1);
            try bits.writeBits(@as(u8, 0xab), 16);
        },
        5 => input.reader().toss(33),
        6, 7, 8, 14 => {
            const file = try std.fs.cwd().createFile(path, .{ .read = true });
            defer file.close();
            try file.writeAll("0123456789");
            var buffer: [8]u8 = undefined;
            var stream = io.ReadStream.initFile(file, if (code == 7) buffer[0..0] else &buffer);
            if (code == 8 or code == 14) {
                _ = try stream.reader().takeByte();
                if (code == 14) try stream.seekBy(-1);
                try stream.seekBy(std.math.maxInt(i64));
            } else {
                _ = try stream.reader().take(if (code == 7) 1 else 9);
            }
        },
        9 => {
            var bits: io.BitReader(.big) = .{ .reader = input.reader(), .count = 8 };
            _ = try bits.readBitsTuple(u8, 0);
        },
        10 => {
            var bits: io.BitReader(.little) = .{ .reader = input.reader(), .count = 9 };
            _ = try bits.readBitsTuple(u8, 9);
        },
        11 => {
            var bits: io.BitWriter(.big) = .{ .writer = output.writer(), .count = 9 };
            try bits.writeBits(@as(u8, 0), 0);
        },
        12 => {
            var bits: io.BitWriter(.little) = .{ .writer = output.writer(), .count = 8 };
            try bits.writeBits(@as(u8, 0), 0);
        },
        13 => {
            var bits: io.BitWriter(.big) = .{ .writer = output.writer(), .count = 9 };
            try bits.flushBits();
        },
        15 => {
            const fds = try std.posix.pipe();
            defer std.posix.close(fds[0]);
            var buffer: [0]u8 = undefined;
            var stream = io.WriteStream.initFile(.{ .handle = fds[1] }, &buffer);
            _ = try stream.writer().write("abc");
            std.posix.close(fds[1]);
            try stream.seekTo(0);
        },
        16 => {
            const file = try std.fs.cwd().createFile(path, .{});
            defer file.close();
            var buffer: [1]u8 = undefined;
            var stream = io.WriteStream.initFile(file, &buffer);
            try stream.seekTo(std.math.maxInt(u64));
            try stream.writer().writeByte(1);
            std.debug.print("{d}\n", .{stream.getPos()});
        },
        else => return error.InvalidTrap,
    }
    std.debug.print("returned\n", .{});
}
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    const path = try std.fs.path.join(allocator, &.{ std.fs.path.dirname(args[1]).?, "native-fixture.bin" });
    defer std.fs.cwd().deleteFile(path) catch {};
    const contents = try std.fs.cwd().readFileAlloc(allocator, args[1], 32 * 1024 * 1024);
    var output = std.fs.File.stdout().writer(&.{});
    const writer = &output.interface;
    var lines = std.mem.tokenizeScalar(u8, contents, '\n');
    while (lines.next()) |line| {
        var parts = std.mem.splitScalar(u8, line, '|');
        const mode = try decimal(u8, parts.next().?);
        const endian = try decimal(u8, parts.next().?);
        const kind = try decimal(u8, parts.next().?);
        const capacity = try decimal(usize, parts.next().?);
        const data = try bytes(parts.next().?);
        const actions = parts.next().?;
        if (mode == 6) {
            trap(kind, path) catch |err| {
                std.debug.print("UNEXPECTED_RETURNED_ERROR:{s}\n", .{@errorName(err)});
            };
            return;
        }
        if (mode == 7) {
            if (endian == 0 or endian == 2) try dispatchInteger(.big, writer, kind, data, capacity, try decimal(u64, actions)) else try dispatchInteger(.little, writer, kind, data, capacity, try decimal(u64, actions));
            try writer.writeByte('\n');
            continue;
        }
        if (mode == 8) {
            try pipeWrites(writer, capacity, actions);
            try writer.writeByte('\n');
            continue;
        }
        if (mode <= 1) {
            if (endian == 0 or endian == 2) try dispatch(.big, writer, mode, kind, data, capacity, actions) else try dispatch(.little, writer, mode, kind, data, capacity, actions);
        } else if (mode <= 3 or mode == 9) try byteReads(writer, mode, data, capacity, actions, path) else try byteWrites(writer, mode, capacity, actions, path);
        try writer.writeByte('\n');
    }
}
