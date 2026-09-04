module synthetic

import osc
import rand

fn test_osc_generator_produces_wrapped_sequences() {
	mut rng := rand.new_default(seed_: [u32(0xc0ffeeee), 0xeeeeeeee])
	defer { rng.free() }
	mut generator := Osc.init(rng)
	for _ in 0 .. 50 {
		result := generator.next(256)!
		assert result.len > 0
		assert result[0] == 0x1b
		assert result[1] == `]`
		assert result.last() == 0x07
	}
}

fn test_osc_generator_valid_output_parses() {
	mut rng := rand.new_default(seed_: [u32(0xc0ffeeee), 0xeeeeeeee])
	defer { rng.free() }
	mut generator := Osc.init(rng)
	generator.p_valid = 1
	for _ in 0 .. 50 {
		sequence := generator.next(256)!
		mut parser := osc.Parser.init(unsafe { nil })
		for byte in sequence[2..sequence.len - 1] {
			parser.next(byte)
		}
		assert parser.end(0x07) != none
	}
}

fn test_osc_generator_exact_kind_selection() {
	mut rng := rand.new_default(seed_: [u32(7), 0])
	defer { rng.free() }
	mut generator := Osc.init(rng)
	for kind in int(OscValidKind.change_window_title) .. int(OscValidKind.iterm2_notification) + 1 {
		mut weights := [13]f64{}
		weights[kind] = 1
		generator.p_valid_kind = weights
		sequence := generator.next(256)!
		mut parser := osc.Parser.init(unsafe { nil })
		for byte in sequence[2..sequence.len - 1] {
			parser.next(byte)
		}
		assert parser.end(0x07) != none, 'valid OSC kind ${kind} did not parse: ${sequence.bytestr()}'
	}
}

fn test_osc_generator_invalid_output_is_rejected() {
	mut rng := rand.new_default(seed_: [u32(0xc0ffeeee), 0xeeeeeeee])
	defer { rng.free() }
	mut generator := Osc.init(rng)
	generator.p_valid = 0
	for _ in 0 .. 50 {
		sequence := generator.next(256)!
		mut parser := osc.Parser.init(unsafe { nil })
		for byte in sequence[2..sequence.len - 1] {
			parser.next(byte)
		}
		assert parser.end(0x07) == none
	}
}
