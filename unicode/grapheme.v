module unicode

// BreakState is uucode.grapheme.BreakState from Ghostty's pinned uucode.
pub enum BreakState as u8 {
	default
	regional_indicator
	extended_pictographic
	indic_conjunct_break_consonant
	indic_conjunct_break_linker
}

struct GraphemeKey {
	value u16
}

fn GraphemeKey.init(state BreakState, gb1 GraphemeBreak, gb2 GraphemeBreak) GraphemeKey {
	return GraphemeKey{
		value: u16(state) | (u16(gb1) << 3) | (u16(gb2) << 8)
	}
}

fn (key GraphemeKey) index() uint {
	return uint(key.value)
}

struct GraphemeValue {
	value u8
}

fn GraphemeValue.from_int(value u8) GraphemeValue {
	assert value & 0xf0 == 0
	return GraphemeValue{
		value: value
	}
}

fn (value GraphemeValue) result() bool {
	return value.value & 0x01 != 0
}

fn (value GraphemeValue) state() BreakState {
	return unsafe { BreakState((value.value >> 1) & 0x07) }
}

// grapheme_break is Ghostty's precomputed computeGraphemeBreakNoControl
// lookup. Control characters, CR, and LF are handled before this is called,
// so their generated property is other. The 8192-byte transition table was
// emitted directly from the pinned uucode implementation.
//
// Transition table SHA-256:
//   538fb7ce938f52b0a1ee7767530ea9d05a93e057f7dc8aa7bd8722da4a102e4
@[direct_array_access]
pub fn grapheme_break(cp1 u32, cp2 u32, state &BreakState) bool {
	gb1 := get(cp1).grapheme_break()
	gb2 := get(cp2).grapheme_break()
	state_ptr := unsafe { &u8(state) }
	key := GraphemeKey.init(unsafe { BreakState(*state_ptr) }, gb1, gb2)
	value := GraphemeValue.from_int(table_data[grapheme_break_offset + int(key.index())])
	unsafe { *state_ptr = u8(value.state()) }
	return value.result()
}
