module main

import zigimg

type Floats = [4]f32

fn main() {
	n := u16(1)
	p := &n
	_ = zigimg.simd_int_to_float[Floats, &&u16](&p)
}
