module main

import zigimg

type Input = u16
type Output = bool
type FourInput = [4]Input

fn main() {
	mut d := [Output(false), false, false, false]
	zigimg.simd_store[Output, FourInput](mut d, FourInput([Input(1), 2, 3, 4]!), 0)
}
