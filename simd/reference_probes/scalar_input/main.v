module main

import os
import simd

// Compile with -d no_simd. Empty/all-padding input reproduces the reference
// scalarInput checked-build bounds trap; a one-byte input logs InvalidPadding.
fn main() {
	payload := if os.args.len > 1 { os.args[1] } else { '' }
	println(simd.max_len(payload.bytes()))
}
