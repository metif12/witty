module main

import zigimg

type Input = i8
type Output = u16
type Lanes = [4]Output

fn main() {
	_ = zigimg.simd_load[Lanes, Input]([Input(1), 2, 3, 4], 0)
}
