module main

import zigimg

type Pointer = &u16
type Lanes = [4]Pointer

fn main() {
	_ = zigimg.simd_load_bytes[Lanes]([]u8{len: 32}, 0)
}
