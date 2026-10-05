module main

import zigimg

type Input = u16
type Output = u8
type Lanes = [4]Output

fn main() {
	_ = zigimg.simd_load[Lanes, Input]([Input(1), 2, 3, 4], 0)
}
