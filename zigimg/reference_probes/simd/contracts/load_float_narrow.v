module main

import zigimg

type Lanes = [4]f32

fn main() {
	_ = zigimg.simd_load[Lanes, f64]([f64(1), 2, 3, 4], 0)
}
