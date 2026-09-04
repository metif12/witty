module unicode

// BreakState is uucode.grapheme.BreakState from Ghostty's pinned uucode.
pub enum BreakState as u8 {
	default
	regional_indicator
	extended_pictographic
	indic_conjunct_break_consonant
	indic_conjunct_break_linker
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
	gb1 := u32(get(cp1).grapheme_break)
	gb2 := u32(get(cp2).grapheme_break)
	state_value := unsafe { u32(*state) }
	index := state_value | (gb1 << 3) | (gb2 << 8)
	value := table_data[grapheme_break_offset + int(index)]
	unsafe { *state = BreakState((value >> 1) & 0x07) }
	return value & 0x01 != 0
}
