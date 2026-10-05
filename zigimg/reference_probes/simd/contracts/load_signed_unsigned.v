module main

import zigimg

type Lanes = [4]u16

fn main() {
	_ = zigimg.simd_load[Lanes, i8]([i8(1), 2, 3, 4], 0)
}
