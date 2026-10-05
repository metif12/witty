module main

import zigimg

type FourBytes = [4]u8
type FourWords = [4]u16
type FourBools = [4]bool
type FourFloats = [4]f32

fn main() {
	mut dst := [u8(0), 0, 0, 0]
	zigimg.simd_store[u8, FourWords](mut dst, FourWords([u16(1), 2, 3, 4]!), 0)
}
