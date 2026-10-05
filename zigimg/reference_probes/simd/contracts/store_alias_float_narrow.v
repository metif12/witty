module main

import zigimg

type Input = f64
type Output = f32
type Lanes = [4]Input

fn main() {
	mut dst := [Output(0), 0, 0, 0]
	zigimg.simd_store[Output, Lanes](mut dst, Lanes([Input(1), 2, 3, 4]!), 0)
}
