module main

import synthetic

fn main() {
	for seed in [u64(0), 1, 0xc0ffeeeeeeeeeeee] {
		for kind in 0 .. 3 {
			for capacity in 0 .. 84 {
				cap := if capacity < 81 { capacity } else { [128, 256, 512][capacity - 81] }
				mut rng := synthetic.new_source_random(seed)
				mut writer := synthetic.FixedWriter{
					buffer: []u8{len: cap, init: 0xa5}
				}
				mut status := 'ok'
				match kind {
					0 {
						mut generator := synthetic.Bytes.init(rng)
						generator.min_len = 4
						generator.max_len = 40
						generator.next_writer(mut writer, 256) or { status = err.msg() }
					}
					1 {
						mut generator := synthetic.Utf8.init(rng)
						generator.min_len = 4
						generator.max_len = 40
						generator.next_writer(mut writer, 256) or { status = err.msg() }
					}
					2 {
						mut generator := synthetic.Osc.init(rng)
						generator.next_writer(mut writer, 256) or { status = err.msg() }
					}
					else {
						panic('unreachable')
					}
				}

				println('${seed}|${kind}|${cap}|${status}|${writer.buffer[..writer.end].hex()}|${rng.u64():016x}')
			}
		}
	}
}
