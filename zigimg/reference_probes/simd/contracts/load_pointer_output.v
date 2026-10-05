module main

import zigimg

type Pointer = &u16
type Lanes = [4]Pointer

fn main() {
	_ = zigimg.simd_load[Lanes, u16]([u16(1), 2, 3, 4], 0)
}
