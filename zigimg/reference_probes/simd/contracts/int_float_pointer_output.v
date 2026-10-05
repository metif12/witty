module main

import zigimg

type Pointer = &u16
type Lanes = [4]Pointer

fn main() {
	_ = zigimg.simd_int_to_float[Lanes, []u16]([u16(1), 2, 3, 4])
}
