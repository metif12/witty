module osc

fn test_rgb_parse_named_red() {
	rgb := parse_rgb('red') or {
		assert false, 'expected rgb'
		return
	}
	assert rgb.r == 255
	assert rgb.g == 0
	assert rgb.b == 0
}

fn test_rgb_parse_named_blue() {
	rgb := parse_rgb('blue') or {
		assert false, 'expected rgb'
		return
	}
	assert rgb.r == 0
	assert rgb.g == 0
	assert rgb.b == 255
}

fn test_rgb_parse_hash_6() {
	rgb := parse_rgb('#aabbcc') or {
		assert false, 'expected rgb'
		return
	}
	assert rgb.r == 0xaa
	assert rgb.g == 0xbb
	assert rgb.b == 0xcc
}

fn test_rgb_parse_hash_3() {
	rgb := parse_rgb('#abc') or {
		assert false, 'expected rgb'
		return
	}
	assert rgb.r == 0xaa
	assert rgb.g == 0xbb
	assert rgb.b == 0xcc
}

fn test_rgb_parse_rgb_colon() {
	rgb := parse_rgb('rgb:f0/f8/ff') or {
		assert false, 'expected rgb'
		return
	}
	assert rgb.r == 0xf0
	assert rgb.g == 0xf8
	assert rgb.b == 0xff
}

fn test_rgb_parse_rgbi() {
	rgb := parse_rgb('rgbi:1.0/1.0/1.0') or {
		assert false, 'expected rgb'
		return
	}
	assert rgb.r == 0xff
	assert rgb.g == 0xff
	assert rgb.b == 0xff
}

fn test_rgb_parse_invalid() {
	assert parse_rgb('#xxxyyzz') == none
	assert parse_rgb('') == none
	assert parse_rgb('notacolor') == none
}

fn test_osc4_set_palette_color() {
	result := parse_get_set_ansi_color(.osc_4, '0;red')
	assert result.len == 1
	req := result[0]
	if req is ColorRequestSet {
		if req.target is ColorTargetPalette {
			assert req.target.index == 0
		} else {
			assert false, 'expected palette target'
		}
		assert req.color.r == 255
		assert req.color.g == 0
		assert req.color.b == 0
	} else {
		assert false, 'expected set request'
	}
}

fn test_osc4_query_palette_color() {
	result := parse_get_set_ansi_color(.osc_4, '0;?')
	assert result.len == 1
	req := result[0]
	if req is ColorRequestQuery {
		if req.target is ColorTargetPalette {
			assert req.target.index == 0
		} else {
			assert false, 'expected palette target'
		}
	} else {
		assert false, 'expected query request'
	}
}

fn test_osc4_multiple_requests() {
	result := parse_get_set_ansi_color(.osc_4, '0;red;1;blue')
	assert result.len == 2

	req0 := result[0]
	if req0 is ColorRequestSet {
		if req0.target is ColorTargetPalette {
			assert req0.target.index == 0
		}
		assert req0.color.r == 255
		assert req0.color.g == 0
		assert req0.color.b == 0
	}

	req1 := result[1]
	if req1 is ColorRequestSet {
		if req1.target is ColorTargetPalette {
			assert req1.target.index == 1
		}
		assert req1.color.r == 0
		assert req1.color.g == 0
		assert req1.color.b == 255
	}
}

fn test_osc104_reset_palette() {
	result := parse_reset_ansi_color(.osc_104, '')
	assert result.len == 1
	req := result[0]
	assert req is ColorRequestResetPalette
}

fn test_osc104_reset_specific() {
	result := parse_reset_ansi_color(.osc_104, '0')
	assert result.len == 1
	req := result[0]
	if req is ColorRequestReset {
		if req.target is ColorTargetPalette {
			assert req.target.index == 0
		} else {
			assert false, 'expected palette target'
		}
	} else {
		assert false, 'expected reset request'
	}
}

fn test_osc104_reset_multiple() {
	result := parse_reset_ansi_color(.osc_104, '0;;1')
	assert result.len == 2
}

fn test_osc104_reset_invalid_index() {
	result := parse_reset_ansi_color(.osc_104, 'ffff;1')
	assert result.len == 1
	req := result[0]
	if req is ColorRequestReset {
		if req.target is ColorTargetPalette {
			assert req.target.index == 1
		}
	}
}

fn test_osc105_reset_all() {
	result := parse_reset_ansi_color(.osc_105, '')
	assert result.len == 1
	req := result[0]
	assert req is ColorRequestResetSpecial
}

fn test_osc10_set_dynamic_color() {
	result := parse_get_set_dynamic_color(.foreground, 'red')
	assert result.len == 1
	req := result[0]
	if req is ColorRequestSet {
		if req.target is ColorTargetDynamic {
			assert req.target.color == .foreground
		} else {
			assert false, 'expected dynamic target'
		}
		assert req.color.r == 255
		assert req.color.g == 0
		assert req.color.b == 0
	} else {
		assert false, 'expected set request'
	}
}

fn test_osc11_set_dynamic_multiple() {
	result := parse_get_set_dynamic_color(.background, 'red;blue')
	assert result.len == 2
	req0 := result[0]
	if req0 is ColorRequestSet {
		if req0.target is ColorTargetDynamic {
			assert req0.target.color == .background
		}
		assert req0.color.r == 255
	}
	req1 := result[1]
	if req1 is ColorRequestSet {
		if req1.target is ColorTargetDynamic {
			assert req1.target.color == .cursor
		}
		assert req1.color.b == 255
	}
}

fn test_osc110_reset_dynamic() {
	result := parse_reset_dynamic_color(.foreground, '')
	assert result.len == 1
	req := result[0]
	if req is ColorRequestReset {
		if req.target is ColorTargetDynamic {
			assert req.target.color == .foreground
		}
	}
}

fn test_osc110_reset_trailing_semicolon() {
	result := parse_reset_dynamic_color(.foreground, ';')
	assert result.len == 1
}

fn test_osc110_reset_whitespace() {
	result := parse_reset_dynamic_color(.foreground, ' ')
	assert result.len == 0
}

fn test_osc4_empty_param() {
	// Empty param should return no results
	mut p := Parser.init(unsafe { nil })
	input := '4;;'
	for ch in input.bytes() {
		p.next(ch)
	}
	// This should either return none or an empty color operation
	_ = p.end(0x1b)
}
