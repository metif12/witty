const std = @import("std");
const simd = @import("src/simd.zig");
const Editor = @import("src/ImageEditor.zig");
const Image = @import("src/Image.zig");
const Unmanaged = @import("src/ImageUnmanaged.zig");
extern "c" fn printf([*:0]const u8, ...) c_int;
var memory = std.heap.page_allocator;

fn bytes(text: []const u8) ![]u8 {
    const result = try memory.alloc(u8, text.len / 2);
    _ = try std.fmt.hexToBytes(result, text);
    return result;
}
fn values(comptime T: type, text: []const u8) ![]T {
    const raw = try bytes(text);
    const result = try memory.alloc(T, raw.len / @sizeOf(T));
    @memcpy(std.mem.sliceAsBytes(result), raw);
    return result;
}
fn emit(data: []const u8) void {
    for (data) |byte| _ = printf("%02x", @as(c_uint, byte));
}
fn emitArray(comptime T: type, comptime N: usize, vector: anytype) void {
    const array: [N]T = vector;
    emit(std.mem.asBytes(&array));
}
fn operations(comptime T: type, comptime N: usize, parts: []const []const u8) !void {
    const length = try std.fmt.parseInt(u32, parts[3], 10);
    inline for (0..N + 1) |L| {
        if (length == L) {
            const raw = try bytes(parts[4]);
            switch (parts[0][0]) {
                'L' => emitArray(T, N, simd.load(T, try values(T, parts[4]), @Vector(N, T), L)),
                'B' => emitArray(T, N, simd.loadBytes(raw, @Vector(N, T), L)),
                'S' => {
                    const input: @Vector(N, T) = (try values(T, parts[4]))[0..N].*;
                    const destination = try values(T, parts[5]);
                    simd.store(T, destination, input, L);
                    emit(std.mem.sliceAsBytes(destination));
                },
                else => return error.InvalidOperation,
            }
            return;
        }
    }
    return error.InvalidLength;
}
fn convert(comptime D: type, comptime S: type, comptime N: usize, operation: u8, text: []const u8) !void {
    const input = try values(S, text);
    if (comptime @typeInfo(D) == .float) {
        std.debug.assert(operation == 'I');
        emitArray(D, N, simd.intToFloat(D, input, N));
    } else {
        std.debug.assert(operation == 'F');
        emitArray(D, N, simd.floatToInt(D, input, N));
    }
}
fn pointerConvert(comptime D: type, comptime S: type, parts: []const []const u8) !void {
    const input = try values(S, parts[4]);
    const array: [4]S = input[0..4].*;
    const vector: @Vector(4, S) = array;
    if (comptime @typeInfo(D) == .float) {
        switch (parts[0][0]) {
            'Q' => emitArray(D, 4, simd.intToFloat(D, &array, 4)),
            'V' => emitArray(D, 4, simd.intToFloat(D, &vector, 4)),
            'M', 'N' => emitArray(D, 4, simd.intToFloat(D, @as([*]const S, input.ptr), 4)),
            'X' => emitArray(D, 4, simd.intToFloat(D, @as(*const [4]S, &array), 4)),
            else => return error.InvalidPointerKind,
        }
    } else {
        switch (parts[0][0]) {
            'Q' => emitArray(D, 4, simd.floatToInt(D, &array, 4)),
            'V' => emitArray(D, 4, simd.floatToInt(D, &vector, 4)),
            'M', 'N' => emitArray(D, 4, simd.floatToInt(D, @as([*]const S, input.ptr), 4)),
            'X' => emitArray(D, 4, simd.floatToInt(D, @as(*const [4]S, &array), 4)),
            else => return error.InvalidPointerKind,
        }
    }
}
fn pointers(parts: []const []const u8) !void {
    if (parts[0][1] == 'I') {
        inline for (.{ u8, i8, u16, i16, u32, i32, u64, i64, usize, isize }) |S| {
            if (std.mem.eql(u8, parts[3], @typeName(S))) {
                if (std.mem.eql(u8, parts[1], "f32")) return pointerConvert(f32, S, parts);
                return pointerConvert(f64, S, parts);
            }
        }
    } else {
        inline for (.{ u8, i8, u16, i16, u32, i32, u64, i64, usize, isize }) |D| {
            if (std.mem.eql(u8, parts[1], @typeName(D))) {
                if (std.mem.eql(u8, parts[3], "f32")) return pointerConvert(D, f32, parts);
                return pointerConvert(D, f64, parts);
            }
        }
    }
    return error.InvalidPointerType;
}
fn record(parts: []const []const u8) !void {
    const N = try std.fmt.parseInt(usize, parts[2], 10);
    inline for (.{ 1, 2, 4, 8, 16 }) |lanes| {
        if (N == lanes) {
            if (parts[0][0] == 'I') {
                inline for (.{ u8, i8, u16, i16, u32, i32, u64, i64, usize, isize }) |S| {
                    if (std.mem.eql(u8, parts[3], @typeName(S))) {
                        if (std.mem.eql(u8, parts[1], "f32")) return convert(f32, S, lanes, 'I', parts[4]);
                        if (std.mem.eql(u8, parts[1], "f64")) return convert(f64, S, lanes, 'I', parts[4]);
                    }
                }
            } else if (parts[0][0] == 'F') {
                inline for (.{ u8, i8, u16, i16, u32, i32, u64, i64, usize, isize }) |D| {
                    if (std.mem.eql(u8, parts[1], @typeName(D))) {
                        if (std.mem.eql(u8, parts[3], "f32")) return convert(D, f32, lanes, 'F', parts[4]);
                        if (std.mem.eql(u8, parts[3], "f64")) return convert(D, f64, lanes, 'F', parts[4]);
                    }
                }
            } else {
                inline for (.{ u8, i8, u16, i16, u32, i32, u64, i64, usize, isize, f32, f64 }) |T| {
                    if (std.mem.eql(u8, parts[1], @typeName(T))) return operations(T, lanes, parts);
                }
            }
        }
    }
    return error.InvalidType;
}
const AliasU16 = u16;
const AliasI32 = i32;
const AliasUsize = usize;
const AliasF32 = f32;
const AliasF64 = f64;
fn aliasOperations(comptime T: type, parts: []const []const u8) !void {
    const length = try std.fmt.parseInt(u32, parts[3], 10);
    inline for (0..5) |L| {
        if (length == L) {
            switch (parts[0][1]) {
                'L' => {
                    const out = simd.load(T, try values(T, parts[4]), [4]T, L);
                    emit(std.mem.asBytes(&out));
                },
                'B' => {
                    const out = simd.loadBytes(try bytes(parts[4]), [4]T, L);
                    emit(std.mem.asBytes(&out));
                },
                'S' => {
                    const input: [4]T = (try values(T, parts[4]))[0..4].*;
                    const destination = try values(T, parts[5]);
                    simd.store(T, destination, input, L);
                    emit(std.mem.sliceAsBytes(destination));
                },
                else => return error.InvalidAliasOperation,
            }
            return;
        }
    }
    return error.InvalidAliasLength;
}
fn aliases(parts: []const []const u8) !void {
    if (parts[0][1] == 'I') {
        inline for (.{ .{ AliasU16, "u16" }, .{ AliasI32, "i32" }, .{ AliasUsize, "usize" } }) |entry| {
            if (std.mem.eql(u8, parts[3], entry[1])) {
                if (std.mem.eql(u8, parts[1], "f32")) return convert(AliasF32, entry[0], 4, 'I', parts[4]);
                return convert(AliasF64, entry[0], 4, 'I', parts[4]);
            }
        }
    } else if (parts[0][1] == 'F') {
        inline for (.{ .{ AliasU16, "u16" }, .{ AliasI32, "i32" }, .{ AliasUsize, "usize" } }) |entry| {
            if (std.mem.eql(u8, parts[1], entry[1])) {
                if (std.mem.eql(u8, parts[3], "f32")) return convert(entry[0], AliasF32, 4, 'F', parts[4]);
                return convert(entry[0], AliasF64, 4, 'F', parts[4]);
            }
        }
    } else {
        inline for (.{ .{ AliasU16, "u16" }, .{ AliasI32, "i32" }, .{ AliasUsize, "usize" }, .{ AliasF32, "f32" }, .{ AliasF64, "f64" } }) |entry| {
            if (std.mem.eql(u8, parts[1], entry[1])) return aliasOperations(entry[0], parts);
        }
    }
    return error.InvalidAliasType;
}
fn widen(comptime D: type, comptime S: type, parts: []const []const u8) !void {
    const input = try values(S, parts[4]);
    if (parts[0][parts[0].len - 1] == 'L') {
        emitArray(D, 4, simd.load(S, input, [4]D, 0));
    } else {
        var destination: [6]D = .{ 9, 9, 9, 9, 9, 9 };
        const array: [4]S = input[0..4].*;
        simd.store(D, &destination, array, 0);
        emit(std.mem.asBytes(&destination));
    }
}
fn widening(parts: []const []const u8) !void {
    inline for (.{ .{ u16, u8 }, .{ i16, u8 }, .{ u32, u16 }, .{ i32, u16 }, .{ u64, u32 }, .{ i64, u32 }, .{ i16, i8 }, .{ i32, i16 }, .{ i64, i32 }, .{ f64, f32 } }) |entry| {
        if (std.mem.eql(u8, parts[1], @typeName(entry[0])) and std.mem.eql(u8, parts[3], @typeName(entry[1]))) return widen(entry[0], entry[1], parts);
    }
    return error.InvalidWidening;
}
const StoreItem = struct { x: u16, y: u32 };
fn arbitraryStores(parts: []const []const u8) !void {
    const length = try std.fmt.parseInt(u32, parts[1], 10);
    const raw = try bytes(parts[2]);
    inline for (0..5) |L| {
        if (length == L) {
            if (parts[0][1] == 'B') {
                var input: [4]bool = undefined;
                for (0..4) |index| input[index] = raw[index] != 0;
                var destination: [6]bool = .{ false, false, false, false, false, false };
                simd.store(bool, &destination, input, L);
                for (destination) |flag| {
                    _ = printf("%u", @as(c_uint, @intFromBool(flag)));
                }
            } else {
                var input: [4]StoreItem = undefined;
                for (0..4) |index| {
                    input[index] = .{ .x = std.mem.readInt(u16, raw[index * 6 ..][0..2], .little), .y = std.mem.readInt(u32, raw[index * 6 + 2 ..][0..4], .little) };
                }
                var destination: [6]StoreItem = .{StoreItem{ .x = 9, .y = 99 }} ** 6;
                simd.store(StoreItem, &destination, input, L);
                for (destination) |item| {
                    _ = printf("%04x%08x", @as(c_uint, item.x), @as(c_uint, item.y));
                }
            }
            return;
        }
    }
    return error.InvalidStoreLength;
}
fn trap(name: []const u8) !void {
    const alloc = std.heap.page_allocator;
    if (std.mem.eql(u8, name, "load_short")) {
        _ = simd.load(u16, &.{ 1, 2 }, @Vector(4, u16), 0);
    } else if (std.mem.eql(u8, name, "bytes_short")) {
        _ = simd.loadBytes(&.{ 1, 2 }, @Vector(4, u16), 0);
    } else if (std.mem.eql(u8, name, "bytes_remainder")) {
        _ = simd.loadBytes(&.{ 1, 2, 3 }, @Vector(4, u16), 0);
    } else if (std.mem.eql(u8, name, "store_short")) {
        var destination = [_]u16{ 9, 9 };
        simd.store(u16, &destination, @Vector(4, u16){ 1, 2, 3, 4 }, 0);
    } else if (std.mem.eql(u8, name, "int_source_short")) {
        _ = simd.intToFloat(f32, @as([]const u16, &.{ 1, 2 }), 4);
    } else if (std.mem.eql(u8, name, "float_source_short")) {
        _ = simd.floatToInt(u16, @as([]const f32, &.{ 1, 2 }), 4);
    } else if (std.mem.eql(u8, name, "negative_unsigned")) {
        _ = simd.floatToInt(u8, [1]f64{-1}, 1);
    } else if (std.mem.eql(u8, name, "positive_unsigned")) {
        _ = simd.floatToInt(u8, [1]f64{256}, 1);
    } else if (std.mem.eql(u8, name, "negative_signed")) {
        _ = simd.floatToInt(i8, [1]f64{-129}, 1);
    } else if (std.mem.eql(u8, name, "positive_signed")) {
        _ = simd.floatToInt(i8, [1]f64{128}, 1);
    } else if (std.mem.eql(u8, name, "infinity")) {
        _ = simd.floatToInt(i64, [1]f64{std.math.inf(f64)}, 1);
    } else if (std.mem.eql(u8, name, "negative_infinity")) {
        _ = simd.floatToInt(i64, [1]f64{-std.math.inf(f64)}, 1);
    } else if (std.mem.eql(u8, name, "mask_negative")) {
        _ = simd.vpermd(@Vector(8, i32){ 0, 1, 2, 3, 4, 5, 6, 7 }, @Vector(8, i32){ 0, 1, 2, 3, 4, 5, 6, -1 });
    } else if (std.mem.eql(u8, name, "mask_high")) {
        _ = simd.vpermd(@Vector(8, i32){ 0, 1, 2, 3, 4, 5, 6, 7 }, @Vector(8, i32){ 0, 1, 2, 3, 4, 5, 6, 8 });
    } else if (std.mem.eql(u8, name, "box_x_add")) {
        _ = (Editor.Box{ .x = std.math.maxInt(usize), .width = 2 }).clamp(8, 8);
    } else if (std.mem.eql(u8, name, "box_y_add")) {
        _ = (Editor.Box{ .y = std.math.maxInt(usize), .height = 2 }).clamp(8, 8);
    } else if (std.mem.eql(u8, name, "box_x_sub")) {
        _ = (Editor.Box{ .x = 9, .width = 1 }).clamp(8, 8);
    } else if (std.mem.eql(u8, name, "box_y_sub")) {
        _ = (Editor.Box{ .y = 9, .height = 1 }).clamp(8, 8);
    } else if (std.mem.eql(u8, name, "managed_create")) {
        _ = Image.create(alloc, std.math.maxInt(usize), 2, .invalid) catch |err| {
            _ = printf("UNEXPECTED: error %s\n", @errorName(err).ptr);
            return;
        };
    } else if (std.mem.eql(u8, name, "unmanaged_create")) {
        _ = Unmanaged.create(alloc, std.math.maxInt(usize), 2, .invalid) catch |err| {
            _ = printf("UNEXPECTED: error %s\n", @errorName(err).ptr);
            return;
        };
    } else if (std.mem.eql(u8, name, "managed_crop")) {
        var image = Image.init(alloc);
        image.width = std.math.maxInt(usize);
        image.height = 2;
        _ = image.crop(alloc, .{ .width = std.math.maxInt(usize), .height = 2 }) catch |err| {
            _ = printf("UNEXPECTED: error %s\n", @errorName(err).ptr);
            return;
        };
    } else if (std.mem.eql(u8, name, "unmanaged_crop")) {
        var image = Unmanaged{};
        image.width = std.math.maxInt(usize);
        image.height = 2;
        _ = image.crop(alloc, .{ .width = std.math.maxInt(usize), .height = 2 }) catch |err| {
            _ = printf("UNEXPECTED: error %s\n", @errorName(err).ptr);
            return;
        };
    } else return error.InvalidTrap;
    _ = printf("UNEXPECTED: operation returned\n");
}
pub fn main() !void {
    const alloc = std.heap.page_allocator;
    const args = try std.process.argsAlloc(alloc);
    if (std.mem.startsWith(u8, args[1], "trap:")) return trap(args[1][5..]);
    const input = try std.fs.cwd().readFileAlloc(alloc, args[1], 64 * 1024 * 1024);
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    memory = arena.allocator();
    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| {
        var split = std.mem.splitScalar(u8, line, '|');
        var parts: [8][]const u8 = undefined;
        var count: usize = 0;
        while (split.next()) |part| {
            parts[count] = part;
            count += 1;
        }
        if (parts[0][0] == 'C') {
            const area = Editor.Box{
                .x = try std.fmt.parseInt(usize, parts[3], 10),
                .y = try std.fmt.parseInt(usize, parts[4], 10),
                .width = try std.fmt.parseInt(usize, parts[5], 10),
                .height = try std.fmt.parseInt(usize, parts[6], 10),
            };
            const box = area.clamp(try std.fmt.parseInt(usize, parts[1], 10), try std.fmt.parseInt(usize, parts[2], 10));
            emitArray(usize, 4, [4]usize{ box.x, box.y, box.width, box.height });
        } else if (parts[0][0] == 'Z') {
            const width = try std.fmt.parseInt(usize, parts[2], 10);
            const height = try std.fmt.parseInt(usize, parts[3], 10);
            if (std.mem.eql(u8, parts[1], "managed")) {
                var image = try Image.create(alloc, width, height, .invalid);
                defer image.deinit();
                emitArray(usize, 4, [4]usize{ image.width, image.height, image.imageByteSize(), image.pixels.len() });
            } else {
                var image = try Unmanaged.create(alloc, width, height, .invalid);
                defer image.deinit(alloc);
                emitArray(usize, 4, [4]usize{ image.width, image.height, image.imageByteSize(), image.pixels.len() });
            }
        } else if (parts[0][0] == 'O') {
            try arbitraryStores(parts[0..count]);
        } else if (parts[0][0] == 'W') {
            try widening(parts[0..count]);
        } else if (parts[0][0] == 'Q' or parts[0][0] == 'V' or parts[0][0] == 'M' or parts[0][0] == 'N' or parts[0][0] == 'X') {
            try pointers(parts[0..count]);
        } else if (parts[0][0] == 'H') {
            const storage = try values(u16, parts[1]);
            simd.store(u16, storage[1..5], storage[0..4].*, 0);
            emit(std.mem.sliceAsBytes(storage));
        } else if (std.mem.startsWith(u8, parts[0], "AW")) {
            try widening(parts[0..count]);
        } else if (parts[0][0] == 'A') {
            try aliases(parts[0..count]);
        } else if (parts[0][0] == 'P') {
            const value = try values(i32, parts[1]);
            const mask = try values(i32, parts[2]);
            emitArray(i32, 8, simd.vpermd(value[0..8].*, mask[0..8].*));
        } else try record(parts[0..count]);
        _ = printf("\n");
        _ = arena.reset(.retain_capacity);
    }
}
