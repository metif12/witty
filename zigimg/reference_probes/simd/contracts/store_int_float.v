module main

import zigimg

type Lanes = [4]u16

fn main() {
	mut dst := [f32(0), 0, 0, 0]
	zigimg.simd_store[f32, Lanes](mut dst, Lanes([u16(1), 2, 3, 4]!), 0)
}
