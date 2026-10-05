module main

import zigimg

type FourBytes = [4]u8
type FourWords = [4]u16
type FourBools = [4]bool
type FourFloats = [4]f32

fn main() {
	_ = zigimg.simd_load[[]u8, u8]([u8(1), 2, 3, 4], 0)
}
