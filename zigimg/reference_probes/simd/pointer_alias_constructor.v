module main

import zigimg

type Words = [4]u16
type Pointer = &Words
type Floats = [4]f32

fn main() {
	words := Words([u16(1), 2, 3, 4]!)
	aliased_pointer := Pointer(unsafe { &words })
	floats := zigimg.simd_int_to_float[Floats, Pointer](aliased_pointer)
	assert floats[3] == 4
}
