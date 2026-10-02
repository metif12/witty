const std=@import("std");
const A=std.mem.Allocator;
const State=struct {
    calls:usize=0, fail_at:usize=std.math.maxInt(usize),
    fn allocator(self:*State) A {return .{.ptr=self,.vtable=&.{.alloc=alloc,.resize=resize,.remap=remap,.free=free}};}
    fn alloc(ctx:*anyopaque,n:usize,a:std.mem.Alignment,_:usize) ?[*]u8 {
        const self:*State=@ptrCast(@alignCast(ctx));const call=self.calls;self.calls+=1;
        std.debug.print("alloc {d} {d} {d}\n",.{call,n,a.toByteUnits()});
        if(call==self.fail_at)return null;
        return (std.heap.c_allocator.alignedAlloc(u8,.fromByteUnits(4096),n) catch return null).ptr;
    }
    fn resize(_: *anyopaque,_:[]u8,_:std.mem.Alignment,_:usize,_:usize) bool{return false;}
    fn remap(_: *anyopaque,_:[]u8,_:std.mem.Alignment,_:usize,_:usize) ?[*]u8{return null;}
    fn free(_: *anyopaque,m:[]u8,a:std.mem.Alignment,_:usize) void{
        std.debug.print("free {d} {d}\n",.{m.len,a.toByteUnits()});std.heap.c_allocator.free(@as([*]align(4096)u8,@alignCast(m.ptr))[0..m.len]);
    }
};
pub fn main() !void {
    var s:State=.{};const a=s.allocator();
    var pool=try std.heap.MemoryPool(u32).initPreheated(a,4);
    const p1=try pool.create();const p2=try pool.create();const p3=try pool.create();
    pool.destroy(p2);std.debug.print("reuse {d}\n",.{@intFromBool(try pool.create()==p2)});
    pool.destroy(p1);pool.destroy(p3);std.debug.print("lifo {d} {d}\n",.{@intFromBool(try pool.create()==p3),@intFromBool(try pool.create()==p1)});
    pool.deinit();
    var arena=std.heap.ArenaAllocator.init(a);
    _=try arena.allocator().alloc(u8,1);_=try arena.allocator().alloc(u8,1000);
    std.debug.print("capacity {d}\n",.{arena.queryCapacity()});s.fail_at=s.calls;
    std.debug.print("reset {d}\n",.{@intFromBool(arena.reset(.retain_capacity))});
    std.debug.print("capacity {d}\n",.{arena.queryCapacity()});s.fail_at=std.math.maxInt(usize);
    std.debug.print("limit {d}\n",.{@intFromBool(arena.reset(.{.retain_with_limit=1}))});arena.deinit();
    var set:std.AutoArrayHashMapUnmanaged(*u8,void)=.{};
    for(1..300)|i|try set.putNoClobber(a,@ptrFromInt(i*16),{});
    for(1..300)|i|if(i%3==0){_=set.swapRemove(@ptrFromInt(i*16));};
    var digest:u64=0;for(set.keys(),0..)|key,i|digest+%=@as(u64,@intFromPtr(key))*@as(u64,i+1);
    std.debug.print("set {d} {d}\n",.{set.count(),digest});set.deinit(a);
    var map=std.AutoHashMap(*u8,*u8).init(a);
    for(1..300)|i|try map.putNoClobber(@ptrFromInt(i*16),@ptrFromInt(i*32));
    digest=0;for(1..300)|i|digest+%=@intFromPtr(map.get(@ptrFromInt(i*16)).?);
    std.debug.print("map {d} {d} {d}\n",.{map.count(),map.capacity(),digest});map.deinit();
}
