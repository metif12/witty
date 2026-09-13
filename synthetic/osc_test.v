module synthetic

import osc
import rand

fn test_osc_kind_layout_and_source_order() {
	assert sizeof(OscValidKind) == 1
	mut valid_index := 0
	$for value in OscValidKind.values {
		assert u8(value.value) == u8(valid_index)
		valid_index++
	}
	assert valid_index == 13

	assert sizeof(OscInvalidKind) == 1
	mut invalid_index := 0
	$for value in OscInvalidKind.values {
		assert u8(value.value) == u8(invalid_index)
		invalid_index++
	}
	assert invalid_index == 2
}

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

fn test_osc_generator_tracks_remaining_payload_space() {
	mut rng := rand.new_default(seed_: [u32(0xc0ffeeee), 0xeeeeeeee])
	defer { rng.free() }
	mut generator := Osc.init(rng)
	// Ghostty subtracts four bytes for the five-byte "133;A" prefix, so the
	// prompt form may exceed the nominal limit by exactly one byte.
	for _ in 0 .. 100 {
		payload := generator.next_unwrapped_valid_exact(.prompt_start, 20)!
		assert payload.len <= 21
	}
	for _ in 0 .. 100 {
		payload := generator.next_unwrapped_valid_exact(.report_pwd, 100)!
		assert payload.len <= 100
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

fn test_osc_generator_reports_fixed_writer_overflow() {
	mut rng := rand.new_default(seed_: [u32(0xc0ffeeee), 0xeeeeeeee])
	defer { rng.free() }
	mut generator := Osc.init(rng)
	generator.p_valid = 0
	generator.p_invalid_kind = [f64(0), 1]!
	generator.next(3) or {
		assert err.msg() == 'WriteFailed'
		return
	}
	assert false, 'expected the fixed OSC writer boundary to fail'
}
