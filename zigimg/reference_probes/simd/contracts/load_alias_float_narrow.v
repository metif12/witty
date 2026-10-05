module main

import zigimg

type Input = f64
type Output = f32
type Lanes = [4]Output

fn main() {
	_ = zigimg.simd_load[Lanes, Input]([Input(1), 2, 3, 4], 0)
}
