const std=@import("std");
const Bytes=@import("synthetic/Bytes.zig");
const Utf8=@import("synthetic/Utf8.zig");
const Osc=@import("synthetic/Osc.zig");
pub fn main() !void {
    for ([_]u64{0,1,0xc0ffeeeeeeeeeeee}) |seed| {
        for (0..3) |kind| {
            for (0..84) |capacity| {
                const cap=if(capacity<81) capacity else ([_]usize{128,256,512})[capacity-81];
                var prng=std.Random.DefaultPrng.init(seed);
                var buffer:[512]u8=@splat(0xa5);
                var writer:std.Io.Writer=.fixed(buffer[0..cap]);
                var status:[]const u8="ok";
                switch(kind) {
                    0=>{var generator:Bytes=.{.rand=prng.random(),.min_len=4,.max_len=40}; generator.next(&writer,256) catch |err| {status=@errorName(err);};},
                    1=>{var generator:Utf8=.{.rand=prng.random(),.min_len=4,.max_len=40}; generator.next(&writer,256) catch |err| {status=@errorName(err);};},
                    2=>{var generator:Osc=.{.rand=prng.random()}; generator.next(&writer,256) catch |err| {status=@errorName(err);};},
                    else=>unreachable,
                }
                std.debug.print("{d}|{d}|{d}|{s}|{x}|{x:0>16}\n",.{seed,kind,cap,status,writer.buffered(),prng.next()});
            }
        }
    }
}
