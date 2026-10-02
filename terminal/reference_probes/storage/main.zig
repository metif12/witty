const std = @import("std");
const RCS = @import("terminal/ref_counted_set.zig").RefCountedSet;
const HashMap = @import("terminal/hash_map.zig").OffsetHashMap;
const OffsetBuf = @import("terminal/size.zig").OffsetBuf;
const Key = struct { value: u32 };
const Value = struct { number: i64 };
const MapContext = struct {
    mask: u32,
    pub fn hash(ctx: @This(), key: Key) u64 { return key.value & ctx.mask; }
    pub fn eql(ctx: @This(), a: Key, b: Key) bool { return a.value & ctx.mask == b.value & ctx.mask; }
};
const SetContext = struct {
    count: *u32,
    sum: *u32,
    pub fn hash(_: *const @This(), value: u32) u64 { return value & 3; }
    pub fn eql(_: *const @This(), a: u32, b: u32) bool { return a == b; }
    pub fn deleted(ctx: *const @This(), value: u32) void { ctx.count.* += 1; ctx.sum.* += value; }
};
pub fn main() !void {
    const Map = HashMap(Key, Value, MapContext);
    const ml = Map.layout(16);
    const alloc = std.heap.c_allocator;
    const mb = try alloc.alignedAlloc(u8, .fromByteUnits(64), ml.total_size + 64);
    defer alloc.free(mb);
    @memset(mb, 0);
    const ctx = MapContext{ .mask = 255 };
    const offsets = Map.init(OffsetBuf.init(mb).add(64), ml);
    var map = offsets.map(mb);
    try map.putContext(.{ .value = 7 }, .{ .number = 42 }, ctx);
    try map.putContext(.{ .value = 263 }, .{ .number = 99 }, ctx);
    const copy = try alloc.alignedAlloc(u8, .fromByteUnits(64), mb.len);
    defer alloc.free(copy);
    @memcpy(copy, mb);
    var moved = offsets.map(copy);
    std.debug.print("map layout={d}/{d}/{d} count={d} value={d} moved={d}\n", .{ ml.total_size, ml.keys_start, ml.vals_start, map.count(), map.getContext(.{ .value = 7 }, ctx).?.number, moved.getContext(.{ .value = 263 }, ctx).?.number });
    _ = moved.removeContext(.{ .value = 7 }, ctx);
    std.debug.print("map counts={d}/{d}\n", .{ map.count(), moved.count() });
    const Set = RCS(u32, u8, u32, SetContext);
    const sl = Set.Layout.init(16);
    const sb = try alloc.alignedAlloc(u8, .fromByteUnits(64), sl.total_size + 64);
    defer alloc.free(sb);
    var count: u32 = 0;
    var sum: u32 = 0;
    var set = Set.init(OffsetBuf.init(sb).add(64), sl, .{ .count = &count, .sum = &sum });
    const id = try set.add(sb, 100);
    const duplicate = try set.add(sb, 100);
    set.useMultiple(sb, id, 100000);
    std.debug.print("set layout={d}/{d}/{d} ids={d}/{d} ref={d}\n", .{ sl.total_size, sl.items_start, sl.cap, id, duplicate, set.refCount(sb, id) });
    const sc = try alloc.alignedAlloc(u8, .fromByteUnits(64), sb.len);
    defer alloc.free(sc);
    @memcpy(sc, sb);
    var relocated = set;
    for (0..400) |_| relocated.releaseMultiple(sc, id, 250);
    relocated.releaseMultiple(sc, id, 2);
    const reused = try relocated.add(sc, 200);
    std.debug.print("set reused={d} values={d}/{d} deleted={d}/{d}\n", .{ reused, set.get(sb, id).*, relocated.get(sc, reused).*, count, sum });
}
