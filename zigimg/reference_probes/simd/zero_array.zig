const simd=@import("src/simd.zig");pub fn main()void{const result=simd.load(u8,&.{},[0]u8,0);if(result.len!=0)@panic("UNEXPECTED: nonempty");}
