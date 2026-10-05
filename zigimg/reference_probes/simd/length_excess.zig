const simd=@import("src/simd.zig");pub fn main()void{_=simd.load(u16,&.{1,2,3,4,5},@Vector(4,u16),5);}
