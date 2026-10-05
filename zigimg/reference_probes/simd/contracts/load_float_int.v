module main

import zigimg

type Lanes = [4]u16

fn main() {
	_ = zigimg.simd_load[Lanes, f32]([f32(1), 2, 3, 4], 0)
}
