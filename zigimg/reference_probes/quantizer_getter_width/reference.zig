const std = @import("std");
const p = @import("src/OctTreeQuantizer.zig");
const c = @import("src/color.zig");
const a = std.heap.page_allocator;
const W = std.Io.Writer;
const Node = @TypeOf(@as(p, undefined).root_node);
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_trace: *Trace = undefined;
var observed_node: *const Node = undefined;
fn state(out: *W) !void {
    try traceOutput(out, observed_trace.*);
    try tree(out, observed_node, 1);
}
fn observe(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var buffer: [4096]u8 = undefined;
            var writer = file.writer(&buffer);
            state(&writer.interface) catch {};
            writer.interface.flush() catch {};
        } else |_| {}
    }
    std.debug.defaultPanic(message, address);
}
const Trace = struct { words: [256]u32 = @splat(0), len: usize = 0 };
fn Getter(comptime Width: type) type {
    return struct {
        word: u32,
        mode: u32,
        trace: *Trace,
        pub fn u32Rgb(value: *const @This()) Width {
            const n: u32 = @intCast(value.trace.len);
            const raw = switch (value.mode) {
                0 => value.word,
                1 => value.word ^ (n * 0x010101),
                else => value.word +% (n * 0x010307),
            };
            const result: Width = @truncate(raw);
            value.trace.words[value.trace.len] = result;
            value.trace.len += 1;
            return result;
        }
    };
}
fn WordColor(comptime Width: type) type {
    return struct { to: Getter(Width) };
}
fn traceOutput(out: *W, trace: Trace) !void {
    try out.print("{d}:", .{trace.len});
    for (trace.words[0..trace.len]) |word| try out.print("{d},", .{word});
    try out.writeByte('|');
}
fn tree(out: *W, node: anytype, path: u32) !void {
    try out.print("{d}:{d}:{d}:{d}:{d}:{d};", .{ path, node.red, node.green, node.blue, node.reference_count, node.palette_index });
    for (node.children, 0..) |child, index| {
        if (child) |n| try tree(out, n, path * 8 + @as(u32, @intCast(index)));
    }
}
fn wordAt(seed: u32, i: usize) u32 {
    return seed +% (@as(u32, @intCast(i)) * 0x00130711);
}
fn run(out: *W, prototype: anytype, count: usize, budget: u32) !void {
    const trace = prototype.to.trace;
    var q = p{ .area_allocator = std.heap.ArenaAllocator.init(a) };
    defer q.deinit();
    q.root_node.init(0, &q);
    var value = prototype;
    for (0..count) |i| {
        value.to.word = wordAt(prototype.to.word, i);
        try q.addColor(value);
    }
    try traceOutput(out, trace.*);
    try tree(out, &q.root_node, 1);
    try out.writeByte('|');
    var palette: [16]c.Rgba32 = @splat(.{ .r = 17, .g = 18, .b = 19, .a = 20 });
    const result = q.makePalette(budget, &palette);
    try out.print("{d}:", .{result.len});
    for (palette) |color| try out.print("{d},{d},{d},{d};", .{ color.r, color.g, color.b, color.a });
    try out.writeByte('|');
    for (0..count + 1) |i| {
        value.to.word = wordAt(prototype.to.word, i);
        const index = q.getPaletteIndex(value) catch |err| {
            try out.print("{s},", .{@errorName(err)});
            continue;
        };
        try out.print("{d},", .{index});
    }
    try out.writeByte('|');
    try traceOutput(out, trace.*);
    try tree(out, &q.root_node, 1);
    try out.print("|{d}:{d}\n", .{ prototype.to.word, value.to.word });
}
fn nodeRun(out: *W, value: anytype, f: [11][]const u8) !void {
    var q = p{ .area_allocator = std.heap.ArenaAllocator.init(a) };
    defer q.deinit();
    q.root_node.init(0, &q);
    q.root_node.red = try std.fmt.parseInt(u32, f[6], 10);
    q.root_node.green = try std.fmt.parseInt(u32, f[7], 10);
    q.root_node.blue = try std.fmt.parseInt(u32, f[8], 10);
    q.root_node.reference_count = try std.fmt.parseInt(u32, f[9], 10);
    q.root_node.palette_index = try std.fmt.parseInt(u32, f[10], 10);
    observed_trace = value.to.trace;
    observed_node = &q.root_node;
    const level = try std.fmt.parseInt(i32, f[5], 10);
    if (std.mem.eql(u8, f[4], "1")) {
        try q.root_node.addColor(value, level, &q);
        try out.writeAll("ok");
    } else {
        if (q.root_node.getPaletteIndex(value, level)) |index| {
            try out.print("index:{d}", .{index});
        } else |err| {
            try out.writeAll(@errorName(err));
        }
    }
    try out.writeByte('|');
    try state(out);
    try out.writeByte('\n');
}
fn lineCase(out: *W, line: []const u8) !void {
    var parts = std.mem.splitScalar(u8, line, '|');
    var f: [11][]const u8 = undefined;
    var count: usize = 0;
    while (parts.next()) |part| {
        f[count] = part;
        count += 1;
    }
    const node = std.mem.eql(u8, f[0], "N");
    const offset: usize = if (node) 1 else 0;
    const kind = try std.fmt.parseInt(u32, f[offset], 10);
    var trace = Trace{};
    const getter = .{ .word = try std.fmt.parseInt(u32, f[offset + 1], 10), .mode = try std.fmt.parseInt(u32, f[offset + 2], 10), .trace = &trace };
    switch (kind % 3) {
        inline 0...2 => |width| {
            const Wt = switch (width) {
                0 => u8,
                1 => u16,
                else => u32,
            };
            const value = WordColor(Wt){ .to = .{ .word = getter.word, .mode = getter.mode, .trace = &trace } };
            if (node) try nodeRun(out, value, f) else try run(out, value, try std.fmt.parseInt(usize, f[3], 10), try std.fmt.parseInt(u32, f[4], 10));
        },
        else => unreachable,
    }
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args);
    var buffer: [8192]u8 = undefined;
    var out = std.fs.File.stdout().writer(&buffer);
    if (std.mem.eql(u8, args[1], "--case")) {
        observed_path = args[2];
        try lineCase(&out.interface, args[3]);
    } else {
        const text = try std.fs.cwd().readFileAlloc(a, args[1], 16 * 1024 * 1024);
        defer a.free(text);
        var lines = std.mem.tokenizeScalar(u8, text, '\n');
        while (lines.next()) |line| try lineCase(&out.interface, line);
    }
    try out.interface.flush();
}
