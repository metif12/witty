const std = @import("std");
const v = @import("vaxis");
const a = std.heap.page_allocator;
pub const panic = std.debug.FullPanic(observePanic);
var observed: ?*const v.GraphemeCache = null;
var observed_path: ?[]const u8 = null;

fn hash(bytes: []const u8) u64 {
    var value: u64 = 14695981039346656037;
    for (bytes) |byte| value = (value ^ byte) *% 1099511628211;
    return value;
}
fn observePanic(message: []const u8, address: ?usize) noreturn {
    if (observed) |cache| if (observed_path) |path| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var bytes: [128]u8 = undefined;
            var writer = file.writer(&bytes);
            writer.interface.print("{d}|{x}\n", .{ cache.idx, hash(&cache.buf) }) catch {};
            writer.interface.flush() catch {};
        } else |_| {}
    };
    std.debug.defaultPanic(message, address);
}
fn pattern(cache: *v.GraphemeCache, seed: u8) void {
    for (&cache.buf, 0..) |*byte, index| byte.* = @truncate(index * 17 + seed);
}
fn num(fields: []const []const u8, index: usize) !usize {
    return std.fmt.parseInt(usize, fields[index], 10);
}
fn trap(name: []const u8, path: []const u8) !void {
    var cache: v.GraphemeCache = .{};
    pattern(&cache, 7);
    observed = &cache;
    observed_path = path;
    var external: [8193]u8 = @splat(99);
    if (std.mem.eql(u8, name, "trap_overflow1")) {
        cache.idx = std.math.maxInt(usize);
        _ = cache.put(external[0..1]);
    } else if (std.mem.eql(u8, name, "trap_overflow2")) {
        cache.idx = std.math.maxInt(usize) - 1;
        _ = cache.put(external[0..2]);
    } else if (std.mem.startsWith(u8, name, "trap_large")) {
        cache.idx = if (std.mem.endsWith(u8, name, "reset")) 17 else 0;
        _ = cache.put(&external);
    } else if (std.mem.eql(u8, name, "trap_same_end")) {
        cache.idx = 8191;
        _ = cache.put(cache.buf[8191..8192]);
    } else if (std.mem.eql(u8, name, "trap_after")) {
        cache.idx = 1;
        _ = cache.put(cache.buf[0..3]);
    } else if (std.mem.eql(u8, name, "trap_before")) {
        _ = cache.put(cache.buf[1..4]);
    } else if (std.mem.eql(u8, name, "trap_reset")) {
        cache.idx = 8191;
        _ = cache.put(cache.buf[0..2]);
    } else if (std.mem.eql(u8, name, "trap_full")) {
        _ = cache.put(&cache.buf);
    } else if (std.mem.eql(u8, name, "trap_same")) {
        _ = cache.put(cache.buf[0..1]);
    } else return error.UnknownTrap;
    var bytes: [128]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&bytes);
    try stdout.interface.writeAll("UNEXPECTED: operation returned\n");
    try stdout.interface.flush();
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    if (std.mem.startsWith(u8, args[1], "trap_")) return trap(args[1], args[2]);
    const input = try std.fs.cwd().readFileAlloc(a, args[1], 16 * 1024 * 1024);
    var output: [65536]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&output);
    const out = &stdout.interface;
    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var fields: std.ArrayList([]const u8) = .empty;
        defer fields.deinit(a);
        var parts = std.mem.splitScalar(u8, line, '|');
        while (parts.next()) |part| try fields.append(a, part);
        const p = fields.items;
        var cache: v.GraphemeCache = .{};
        const seed: u8 = @intCast(try num(p, 3));
        pattern(&cache, seed);
        cache.idx = try num(p, 1);
        const length = try num(p, 2);
        const start = cache.idx;
        if (std.mem.eql(u8, p[0], "E") or std.mem.eql(u8, p[0], "A")) {
            var external: [8192]u8 = undefined;
            for (&external, 0..) |*byte, i| byte.* = @truncate(i * 31 + seed);
            const source = if (std.mem.eql(u8, p[0], "A")) cache.buf[try num(p, 4) ..][0..length] else external[0..length];
            const result = cache.put(source);
            const offset = @intFromPtr(result.ptr) - @intFromPtr(&cache.buf);
            try out.print("{s}|{d},{d},{d}|{x}|{x}\n", .{ p[0], start, cache.idx, offset, hash(result), hash(&cache.buf) });
        } else if (std.mem.eql(u8, p[0], "B")) {
            const old = cache.put("abc");
            const old_offset = @intFromPtr(old.ptr) - @intFromPtr(&cache.buf);
            old[1] = 'Q';
            const first_hash = hash(old);
            cache.idx = 8192;
            const wrapped = cache.put("Z");
            try out.print("B|{d},{d},{d}|{x}|{x}|{x}\n", .{ old_offset, cache.idx, @intFromPtr(wrapped.ptr) - @intFromPtr(&cache.buf), first_hash, hash(old), hash(&cache.buf) });
        } else if (std.mem.eql(u8, p[0], "C")) {
            var copied = cache;
            const result = copied.put("xy");
            cache.buf[0] = 42;
            try out.print("C|{d},{d},{d}|{x}|{x}|{x}\n", .{ cache.idx, copied.idx, @intFromPtr(result.ptr) - @intFromPtr(&copied.buf), hash(result), hash(&cache.buf), hash(&copied.buf) });
        } else return error.UnknownKind;
    }
    try out.flush();
}
