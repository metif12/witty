module unicode

fn test_exact_generated_properties() {
	assert table_data.len == grapheme_break_offset + grapheme_break_len
	assert get(u32(`A`)).width == 1
	assert get(0x0301).width == 0
	assert get(0x00ad).width == 1
	assert get(0x1f1fa).width == 2
	assert get(0x1f3ff).width == 2
	assert get(0x200d).grapheme_break == .zwj
	assert get(0xfe0f).emoji_vs_base == false
	assert get(0x2764).emoji_vs_base
	assert get(0x1f469).emoji_vs_base == false
	assert get(0x110000).width == 1
}

fn test_all_generated_property_values() {
	mut properties_hash := u64(14695981039346656037)
	mut symbols_hash := u64(14695981039346656037)
	mut symbol_count := u32(0)
	for cp := u32(0); cp < 0x200000; cp++ {
		props := get(cp)
		packed := props.width | (u8(props.grapheme_break) << 2) | (if props.emoji_vs_base {
			u8(0x80)
		} else {
			u8(0)
		})
		properties_hash = (properties_hash ^ u64(packed)) * u64(1099511628211)

		symbol := is_symbol(cp)
		symbol_byte := if symbol { u8(1) } else { u8(0) }
		symbols_hash = (symbols_hash ^ u64(symbol_byte)) * u64(1099511628211)
		if symbol {
			symbol_count++
		}
	}
	assert properties_hash == u64(0x6af85fc939f28eb1)
	assert symbols_hash == u64(0x8244c0ac828f62b1)
	assert symbol_count == 139420
}

fn test_exact_generated_symbol_table() {
	assert is_symbol(0xe000)
	assert is_symbol(0x2190)
	assert is_symbol(0x1f600)
	assert !is_symbol(u32(`A`))
	assert !is_symbol(0x110000)
}

fn test_grapheme_break_emoji_modifier_tailoring() {
	mut state := BreakState.default
	assert !grapheme_break(0x261d, 0x1f3ff, &state)
	state = .default
	assert grapheme_break(0x22, 0x1f3ff, &state)
}

fn test_grapheme_break_long_emoji_zwj_sequence() {
	sequence := [u32(0x1f469), 0x200d, 0x1f469, 0x200d, 0x1f467, 0x200d, 0x1f466]
	mut state := BreakState.default
	for i := 1; i < sequence.len; i++ {
		assert !grapheme_break(sequence[i - 1], sequence[i], &state), 'break at ${i}: ${get(sequence[i - 1]).grapheme_break} ${get(sequence[i]).grapheme_break} ${state}'
	}
	assert grapheme_break(sequence.last(), u32(`_`), &state)
}

fn test_grapheme_break_regional_indicator_pairs() {
	mut state := BreakState.default
	assert !grapheme_break(0x1f1fa, 0x1f1f8, &state)
	assert grapheme_break(0x1f1f8, 0x1f1e8, &state)
	assert !grapheme_break(0x1f1e8, 0x1f1e6, &state)
}
