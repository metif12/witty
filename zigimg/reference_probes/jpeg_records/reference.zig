const std = @import("std");
const F = @import("src/formats/jpeg/FrameHeader.zig");
const C = @typeInfo(@FieldType(F, "components")).pointer.child;
const J = @import("src/formats/jpeg/JFIFHeader.zig");
const Q = @import("src/formats/jpeg/quantization.zig");
const H = @import("src/formats/jpeg/huffman.zig");
const io = @import("src/io.zig");
const a = std.heap.page_allocator;
const W = std.Io.Writer;

fn component(out: *W, c: C) !void {
    try out.print("{d},{d},{d},{d}", .{ c.id, c.horizontal_sampling_factor, c.vertical_sampling_factor, c.quantization_table_id });
}
fn table(out: *W, t: Q.Table) !void {
    switch (t) {
        .q8 => |values| {
            try out.writeAll("0|");
            for (values) |v| try out.print("{d},", .{v});
        },
        .q16 => |values| {
            try out.writeAll("1|");
            for (values) |v| try out.print("{d},", .{v});
        },
    }
}
fn boxed(out: *W) !void {
    for ([_]u16{ 0, 1, 255, 256, 32768, 65535 }) |seed| {
        var q8: Q.Table = .{ .q8 = @splat(@truncate(seed)) };
        const copy8 = q8;
        q8.q8[0] = 33;
        try out.print("Q8|{d}|", .{seed});
        try table(out, q8);
        try out.writeByte('|');
        try table(out, copy8);
        try out.writeByte('\n');
        var q16: Q.Table = .{ .q16 = @splat(seed) };
        const copy16 = q16;
        q16.q16[0] = 33;
        try out.print("Q16|{d}|", .{seed});
        try table(out, q16);
        try out.writeByte('|');
        try table(out, copy16);
        try out.writeByte('\n');
        var h: Q.Header = .{ .table_precision = 0, .table_destination = 3, .table = .{ .q8 = @splat(@truncate(seed)) } };
        const h_copy = h;
        h.table.q8[1] = 17;
        try out.print("H|{d}|", .{seed});
        try table(out, h.table);
        try out.writeByte('|');
        try table(out, h_copy.table);
        try out.writeByte('\n');
    }
}
pub fn main() !void {
    var buffer: [8192]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&buffer);
    const out = &stdout.interface;
    const args = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args);
    if (args.len == 2 and std.mem.eql(u8, args[1], "--boxed")) {
        try boxed(out);
        try out.flush();
        return;
    }
    for ([_]u8{ 0, 1, 255 }) |id| {
        for (0..256) |sampling| {
            for ([_]u8{ 0, 3, 4, 255 }) |destination| {
                const bytes = [_]u8{ id, @intCast(sampling), destination };
                for (0..4) |length| {
                    var stream = io.ReadStream.initMemory(bytes[0..length]);
                    const c = C.read(stream.reader()) catch |e| {
                        try out.print("C|{d}|{d}|{d}|{d}|E{s}|{d}\n", .{ id, sampling, destination, length, @errorName(e), stream.getPos() });
                        continue;
                    };
                    try out.print("C|{d}|{d}|{d}|{d}|", .{ id, sampling, destination, length });
                    try component(out, c);
                    try out.print("|{d}\n", .{stream.getPos()});
                }
            }
        }
    }
    for ([_]u8{ 0, 1, 255 }) |id| {
        for (0..16) |horizontal| {
            for (0..16) |vertical| {
                for ([_]u8{ 0, 3, 4, 255 }) |destination| {
                    var c: C = .{ .id = id, .horizontal_sampling_factor = @intCast(horizontal), .vertical_sampling_factor = @intCast(vertical), .quantization_table_id = destination };
                    const c_copy = c;
                    c.id = 17;
                    var components = [_]C{ c, c_copy };
                    var h: F = .{ .allocator = a, .sample_precision = id, .height = 65535, .width = 1, .components = &components };
                    const h_copy = h;
                    components[0].horizontal_sampling_factor = 15;
                    h.components[1].vertical_sampling_factor = 14;
                    h.sample_precision = 8;
                    h.height = 7;
                    h.width = 9;
                    h.components = h.components[0..1];
                    try out.print("M|{d}|{d}|{d}|{d}|", .{ id, horizontal, vertical, destination });
                    try component(out, c_copy);
                    try out.print("|{d},{d},{d},{d},{d},{d}|{d},{d},{d},{d},{d},{d}|", .{ h.sample_precision, h.height, h.width, h.components.len, h.getMaxHorizontalSamplingFactor(), h.getMaxVerticalSamplingFactor(), h_copy.sample_precision, h_copy.height, h_copy.width, h_copy.components.len, h_copy.getMaxHorizontalSamplingFactor(), h_copy.getMaxVerticalSamplingFactor() });
                    try component(out, components[0]);
                    try out.writeByte('|');
                    try component(out, components[1]);
                    try out.writeByte('\n');
                }
            }
        }
    }
    for ([_]u16{ 0, 1, 255, 256, 32768, 65535 }) |seed| {
        for (0..64) |index| {
            var q8: Q.Table = .{ .q8 = @splat(@truncate(seed)) };
            q8.q8[index] = 33;
            const copy8 = q8;
            q8 = .{ .q16 = @splat(seed) };
            try out.print("Q8|{d}|{d}|", .{ seed, index });
            try table(out, copy8);
            try out.writeByte('|');
            try table(out, q8);
            try out.writeByte('\n');
            var q16: Q.Table = .{ .q16 = @splat(seed) };
            q16.q16[index] = 33;
            const copy16 = q16;
            q16 = .{ .q8 = @splat(@truncate(seed)) };
            try out.print("Q16|{d}|{d}|", .{ seed, index });
            try table(out, copy16);
            try out.writeByte('|');
            try table(out, q16);
            try out.writeByte('\n');
        }
        for (0..16) |precision| {
            for (0..16) |destination| {
                var h: Q.Header = .{ .table_precision = @intCast(precision), .table_destination = @intCast(destination), .table = .{ .q8 = @splat(@truncate(seed)) } };
                const copy = h;
                h.table_precision = 1;
                h.table_destination = 3;
                h.table = .{ .q16 = @splat(seed) };
                try out.print("H|{d}|{d}|{d}|{d},{d},", .{ seed, precision, destination, copy.table_precision, copy.table_destination });
                try table(out, copy.table);
                try out.print("|{d},{d},", .{ h.table_precision, h.table_destination });
                try table(out, h.table);
                try out.writeByte('\n');
            }
        }
        for (0..3) |unit| {
            var h: J = .{ .jfif_revision = seed, .density_unit = @enumFromInt(unit), .x_density = seed, .y_density = 65535 };
            const copy = h;
            h.jfif_revision = 0x102;
            h.density_unit = .dots_per_cm;
            h.x_density = 72;
            h.y_density = 96;
            try out.print("J|{d}|{d}|{d},{d},{d},{d}|{d},{d},{d},{d}\n", .{ seed, unit, copy.jfif_revision, @intFromEnum(copy.density_unit), copy.x_density, copy.y_density, h.jfif_revision, @intFromEnum(h.density_unit), h.x_density, h.y_density });
        }
    }
    for ([_]u8{ 0, 1, 17, 254 }) |value| {
        for (0..16) |length| {
            var t: H.Table = .{ .allocator = a, .code_counts = @splat(0), .code_map = .init(a), .fast_table = @splat(255), .fast_size = @splat(0), .table_class = 0 };
            defer t.deinit();
            t.code_counts[length] = 1;
            const Key = @typeInfo(@TypeOf(t.code_map.keys())).pointer.child;
            const key: Key = .{ .length_minus_one = @intCast(length), .code = 0 };
            try t.code_map.put(key, value);
            t.table_class = 1;
            const copy = t;
            t.code_counts[length] = 7;
            t.fast_table[0] = value;
            t.fast_size[0] = 9;
            t.table_class = 0;
            var stream = io.ReadStream.initMemory(&.{ 0, 0 });
            var reader = H.Reader.init(&stream);
            reader.setHuffmanTable(&t);
            try t.code_map.put(key, 42);
            t.fast_table[0] = 77;
            const decoded = try reader.readCode();
            try out.print("T|{d}|{d}|{d},{d},{d},{d},{d}|{d},{d},{d},{d}|{d},{d},{d}\n", .{ value, length, copy.code_counts[length], copy.fast_table[0], copy.fast_size[0], copy.table_class, copy.code_map.get(key).?, t.code_counts[length], t.fast_table[0], t.fast_size[0], t.table_class, decoded, reader.bit_count, stream.getPos() });
        }
    }
    var empty: F = .{ .allocator = a, .sample_precision = 0, .height = 0, .width = 0, .components = try a.alloc(C, 0) };
    try out.print("E|{d},{d}\n", .{ empty.getMaxHorizontalSamplingFactor(), empty.getMaxVerticalSamplingFactor() });
    empty.deinit();
    try out.flush();
}
