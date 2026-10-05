module main

import zigimg

type Pointer = &u16
type Lanes = [4]Pointer

fn main() {
	_ = zigimg.simd_float_to_int[Lanes, []f32]([f32(1), 2, 3, 4])
}
