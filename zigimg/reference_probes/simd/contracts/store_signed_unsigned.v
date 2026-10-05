module main

import zigimg

type Lanes = [4]i8

fn main() {
	mut dst := [u16(0), 0, 0, 0]
	zigimg.simd_store[u16, Lanes](mut dst, Lanes([i8(1), 2, 3, 4]!), 0)
}
