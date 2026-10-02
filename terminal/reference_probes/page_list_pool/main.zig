const std=@import("std");
const List=@import("terminal/PageList.zig");
const Page=@import("terminal/page.zig");
pub fn main() !void {
 var pool=try List.MemoryPool.init(std.heap.c_allocator,std.heap.page_allocator,4);
 var buffers:[4]*align(std.heap.page_size_min)[Page.Page.layout(Page.std_capacity).total_size]u8=undefined;
 for(&buffers)|*p|p.*=try pool.pages.create();
 pool.pages.destroy(buffers[2]);std.debug.print("reuse={d} aligned={d}\n",.{@intFromBool(try pool.pages.create()==buffers[2]),@intFromBool(@intFromPtr(buffers[0])%std.heap.page_size_min==0)});
 std.debug.print("capacity={d}\n",.{pool.pages.arena.queryCapacity()});pool.deinit();
 var list=try List.init(std.heap.c_allocator,80,24,null);defer list.deinit();
 const p=try list.trackPin(list.pin(.{.active=.{.x=7,.y=3}}).?);
 const viewport=list.viewport_pin;const serial=list.page_serial;
 list.reset();
 std.debug.print("reset={d}/{d}/{d}/{d}/{d}\n",.{list.total_rows,@intFromBool(p.garbage),@intFromBool(!viewport.garbage),@intFromBool(list.viewport_pin==viewport),@intFromBool(list.page_serial>serial)});
 list.untrackPin(p);const p2=try list.trackPin(list.pin(.{.active=.{.x=1,.y=1}}).?);
 std.debug.print("pinreuse={d} tracked={d}\n",.{@intFromBool(p2==p),list.countTrackedPins()});list.untrackPin(p2);
 var remap=List.Clone.TrackedPinsRemap.init(std.heap.c_allocator);defer remap.deinit();
 var cloned=try list.clone(std.heap.c_allocator,.{.top=.{.screen=.{}},.tracked_pins=&remap});defer cloned.deinit();
 std.debug.print("clone={d}/{d}/{d}\n",.{cloned.total_rows,cloned.countTrackedPins(),remap.count()});
}
