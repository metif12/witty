module main

import zigimg

#flag -I @VMODROOT/zigimg/reference_probes/simd
#include "store_prefix.h"

fn C.witty_simd_observe(&u16)

type FourWords = [4]u16

fn main() {
	mut destination := [u16(9), 9, 9, 9]
	C.witty_simd_observe(unsafe { &destination[0] })
	mut prefix := unsafe { destination[..2] }
	zigimg.simd_store[u16, FourWords](mut prefix, FourWords([u16(1), 2, 3, 4]!), 0)
	println('UNEXPECTED: store returned')
}
