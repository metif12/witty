module tmux

// Tests for tmux layout parsing.
//
// Source: terminal/tmux/layout.zig (tests)

fn test_simple_single_pane() {
	layout := Layout.parse('80x24,0,0,42') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert layout.width == 80
	assert layout.height == 24
	assert layout.x == 0
	assert layout.y == 0
	if layout.content is ContentPane {
		assert layout.content.pane_id == 42
	} else {
		assert false, 'expected ContentPane'
	}
}

fn test_single_pane_with_offset() {
	layout := Layout.parse('40x12,10,5,7') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert layout.width == 40
	assert layout.height == 12
	assert layout.x == 10
	assert layout.y == 5
	if layout.content is ContentPane {
		assert layout.content.pane_id == 7
	} else {
		assert false, 'expected ContentPane'
	}
}

fn test_single_pane_large_values() {
	layout := Layout.parse('1920x1080,100,200,999') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert layout.width == 1920
	assert layout.height == 1080
	assert layout.x == 100
	assert layout.y == 200
	if layout.content is ContentPane {
		assert layout.content.pane_id == 999
	} else {
		assert false, 'expected ContentPane'
	}
}

fn test_horizontal_split_two_panes() {
	layout := Layout.parse('80x24,0,0{40x24,0,0,1,40x24,40,0,2}') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert layout.width == 80
	assert layout.height == 24
	assert layout.x == 0
	assert layout.y == 0

	if layout.content is ContentHorizontal {
		children := layout.content.children
		assert children.len == 2

		assert children[0].width == 40
		assert children[0].height == 24
		assert children[0].x == 0
		assert children[0].y == 0
		if children[0].content is ContentPane {
			assert children[0].content.pane_id == 1
		} else {
			assert false, 'expected ContentPane for child 0'
		}

		assert children[1].width == 40
		assert children[1].height == 24
		assert children[1].x == 40
		assert children[1].y == 0
		if children[1].content is ContentPane {
			assert children[1].content.pane_id == 2
		} else {
			assert false, 'expected ContentPane for child 1'
		}
	} else {
		assert false, 'expected ContentHorizontal'
	}
}

fn test_vertical_split_two_panes() {
	layout := Layout.parse('80x24,0,0[80x12,0,0,1,80x12,0,12,2]') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert layout.width == 80
	assert layout.height == 24

	if layout.content is ContentVertical {
		children := layout.content.children
		assert children.len == 2

		assert children[0].width == 80
		assert children[0].height == 12
		if children[0].content is ContentPane {
			assert children[0].content.pane_id == 1
		} else {
			assert false, 'expected ContentPane for child 0'
		}

		assert children[1].width == 80
		assert children[1].height == 12
		assert children[1].y == 12
		if children[1].content is ContentPane {
			assert children[1].content.pane_id == 2
		} else {
			assert false, 'expected ContentPane for child 1'
		}
	} else {
		assert false, 'expected ContentVertical'
	}
}

fn test_horizontal_split_three_panes() {
	layout := Layout.parse('120x24,0,0{40x24,0,0,1,40x24,40,0,2,40x24,80,0,3}') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert layout.width == 120
	assert layout.height == 24

	if layout.content is ContentHorizontal {
		children := layout.content.children
		assert children.len == 3
		if children[0].content is ContentPane {
			assert children[0].content.pane_id == 1
		}
		if children[1].content is ContentPane {
			assert children[1].content.pane_id == 2
		}
		if children[2].content is ContentPane {
			assert children[2].content.pane_id == 3
		}
	} else {
		assert false, 'expected ContentHorizontal'
	}
}

fn test_nested_horizontal_in_vertical() {
	// Vertical split with top pane and bottom horizontal split.
	layout := Layout.parse('80x24,0,0[80x12,0,0,1,80x12,0,12{40x12,0,12,2,40x12,40,12,3}]') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert layout.width == 80
	assert layout.height == 24

	if layout.content is ContentVertical {
		vert_children := layout.content.children
		assert vert_children.len == 2

		// First child is a simple pane.
		if vert_children[0].content is ContentPane {
			assert vert_children[0].content.pane_id == 1
		} else {
			assert false, 'expected ContentPane for first child'
		}

		// Second child is a horizontal split.
		if vert_children[1].content is ContentHorizontal {
			horiz_children := vert_children[1].content.children
			assert horiz_children.len == 2
			if horiz_children[0].content is ContentPane {
				assert horiz_children[0].content.pane_id == 2
			}
			if horiz_children[1].content is ContentPane {
				assert horiz_children[1].content.pane_id == 3
			}
		} else {
			assert false, 'expected ContentHorizontal for second child'
		}
	} else {
		assert false, 'expected ContentVertical'
	}
}

fn test_nested_vertical_in_horizontal() {
	// Horizontal split with left pane and right vertical split.
	layout := Layout.parse('80x24,0,0{40x24,0,0,1,40x24,40,0[40x12,40,0,2,40x12,40,12,3]}') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert layout.width == 80
	assert layout.height == 24

	if layout.content is ContentHorizontal {
		horiz_children := layout.content.children
		assert horiz_children.len == 2

		// First child is a simple pane.
		if horiz_children[0].content is ContentPane {
			assert horiz_children[0].content.pane_id == 1
		}

		// Second child is a vertical split.
		if horiz_children[1].content is ContentVertical {
			vert_children := horiz_children[1].content.children
			assert vert_children.len == 2
			if vert_children[0].content is ContentPane {
				assert vert_children[0].content.pane_id == 2
			}
			if vert_children[1].content is ContentPane {
				assert vert_children[1].content.pane_id == 3
			}
		}
	}
}

fn test_deeply_nested_layout() {
	// Three levels deep.
	layout := Layout.parse('80x24,0,0{40x24,0,0[40x12,0,0,1,40x12,0,12,2],40x24,40,0,3}') or {
		assert false, 'parse failed: ${err}'
		return
	}

	if layout.content is ContentHorizontal {
		horiz := layout.content.children
		assert horiz.len == 2

		if horiz[0].content is ContentVertical {
			vert := horiz[0].content.children
			assert vert.len == 2
			if vert[0].content is ContentPane {
				assert vert[0].content.pane_id == 1
			}
			if vert[1].content is ContentPane {
				assert vert[1].content.pane_id == 2
			}
		}

		if horiz[1].content is ContentPane {
			assert horiz[1].content.pane_id == 3
		}
	}
}

fn test_syntax_error_empty_string() {
	Layout.parse('') or {
		assert err.msg().contains('SyntaxError')
		return
	}
	assert false, 'expected SyntaxError'
}

fn test_syntax_error_no_x_separator() {
	Layout.parse('8024,0,0,1') or {
		assert err.msg().contains('SyntaxError') || err.msg().contains('missing')
		return
	}
	assert false, 'expected SyntaxError'
}

fn test_syntax_error_no_content_delimiter() {
	Layout.parse('80x24,0,0') or {
		assert err.msg().contains('SyntaxError') || err.msg().contains('missing')
		return
	}
	assert false, 'expected SyntaxError'
}

fn test_syntax_error_missing_width() {
	Layout.parse('x24,0,0,1') or {
		assert err.msg().contains('SyntaxError')
		return
	}
	assert false, 'expected SyntaxError for missing width'
}

fn test_syntax_error_missing_height() {
	Layout.parse('80x,0,0,1') or {
		assert err.msg().contains('SyntaxError')
		return
	}
	assert false, 'expected SyntaxError for missing height'
}

fn test_syntax_error_missing_x() {
	Layout.parse('80x24,,0,1') or {
		assert err.msg().contains('SyntaxError')
		return
	}
	assert false, 'expected SyntaxError for missing x'
}

fn test_syntax_error_missing_y() {
	Layout.parse('80x24,0,,1') or {
		assert err.msg().contains('SyntaxError')
		return
	}
	assert false, 'expected SyntaxError for missing y'
}

fn test_syntax_error_missing_pane_id() {
	Layout.parse('80x24,0,0,') or {
		assert err.msg().contains('SyntaxError')
		return
	}
	assert false, 'expected SyntaxError for missing pane id'
}

fn test_syntax_error_non_numeric_width() {
	Layout.parse('abcx24,0,0,1') or {
		assert err.msg().contains('SyntaxError')
		return
	}
	assert false, 'expected SyntaxError for non-numeric width'
}

fn test_syntax_error_non_numeric_pane_id() {
	Layout.parse('80x24,0,0,abc') or {
		assert err.msg().contains('SyntaxError')
		return
	}
	assert false, 'expected SyntaxError for non-numeric pane id'
}

fn test_syntax_error_trailing_data() {
	Layout.parse('80x24,0,0,1extra') or {
		assert err.msg().contains('SyntaxError') || err.msg().contains('trailing')
		return
	}
	assert false, 'expected SyntaxError'
}

fn test_syntax_error_unclosed_horizontal_bracket() {
	Layout.parse('80x24,0,0{40x24,0,0,1') or {
		assert err.msg().contains('SyntaxError') || err.msg().contains('unexpected')
		return
	}
	assert false, 'expected SyntaxError'
}

fn test_syntax_error_unclosed_vertical_bracket() {
	Layout.parse('80x24,0,0[40x24,0,0,1') or {
		assert err.msg().contains('SyntaxError') || err.msg().contains('unexpected')
		return
	}
	assert false, 'expected SyntaxError'
}

fn test_syntax_error_mismatched_brackets() {
	Layout.parse('80x24,0,0{40x24,0,0,1]') or {
		// First mismatch case failed as expected; check the second.
		Layout.parse('80x24,0,0[40x24,0,0,1}') or { return }
		assert false, 'expected SyntaxError for mismatched brackets [ }'
		return
	}
	assert false, 'expected SyntaxError for mismatched brackets { ]'
}

// parseWithChecksum tests

fn test_parse_with_checksum_valid() {
	layout := Layout.parse_with_checksum('f8f9,80x24,0,0{40x24,0,0,1,40x24,40,0,2}') or {
		assert false, 'parse_with_checksum failed: ${err}'
		return
	}
	assert layout.width == 80
	assert layout.height == 24
}

fn test_parse_with_checksum_mismatch() {
	Layout.parse_with_checksum('0000,80x24,0,0{40x24,0,0,1,40x24,40,0,2}') or {
		assert err.msg().contains('ChecksumMismatch')
		return
	}
	assert false, 'expected ChecksumMismatch'
}

fn test_parse_with_checksum_too_short() {
	Layout.parse_with_checksum('bb62') or {
		assert err.msg().contains('SyntaxError')
		return
	}
	assert false, 'expected SyntaxError for too short'
}

fn test_parse_with_checksum_missing_comma() {
	Layout.parse_with_checksum('bb62x159x48,0,0') or {
		assert err.msg().contains('SyntaxError')
		return
	}
	assert false, 'expected SyntaxError for missing comma'
}

// Checksum tests

fn test_checksum_empty_string() {
	checksum := Checksum.calculate('')
	assert checksum.value == 0
	assert checksum.as_string() == '0000'
}

fn test_checksum_single_character() {
	// 'A' = 65, first iteration: csum = 0 >> 1 | 0 = 0, then 0 + 65 = 65
	checksum := Checksum.calculate('A')
	assert checksum.value == 65
	assert checksum.as_string() == '0041'
}

fn test_checksum_two_characters() {
	// 'A' (65): csum = 0, rotate = 0, add 65 => 65
	// 'B' (66): csum = 65, rotate => (65 >> 1) | ((65 & 1) << 15) = 32 | 32768 = 32800
	//           add 66 => 32800 + 66 = 32866
	checksum := Checksum.calculate('AB')
	assert checksum.value == 32866
	assert checksum.as_string() == '8062'
}

fn test_checksum_simple_layout() {
	checksum := Checksum.calculate('80x24,0,0,42')
	assert checksum.as_string() == 'd962'
}

fn test_checksum_horizontal_split_layout() {
	checksum := Checksum.calculate('80x24,0,0{40x24,0,0,1,40x24,40,0,2}')
	assert checksum.as_string() == 'f8f9'
}

fn test_checksum_as_string_zero_padding() {
	// Value 0x000f should produce "000f".
	checksum := Checksum{ value: 0x000f }
	assert checksum.as_string() == '000f'
}

fn test_checksum_as_string_all_digits() {
	// Value 0x1234 should produce "1234".
	checksum := Checksum{ value: 0x1234 }
	assert checksum.as_string() == '1234'
}

fn test_checksum_as_string_with_letters() {
	// Value 0xabcd should produce "abcd".
	checksum := Checksum{ value: 0xabcd }
	assert checksum.as_string() == 'abcd'
}

fn test_checksum_as_string_max_value() {
	// Value 0xffff should produce "ffff".
	checksum := Checksum{ value: 0xffff }
	assert checksum.as_string() == 'ffff'
}

fn test_checksum_wraparound() {
	// Eight 0xff bytes exercise the u16 rotate + wrapping add.
	input := []u8{len: 8, init: 0xff}.bytestr()
	checksum := Checksum.calculate(input)
	assert checksum.as_string() == '03fc'
}

fn test_checksum_deterministic() {
	// Same input should always produce same output.
	str := '159x48,0,0{79x48,0,0,79x48,80,0}'
	checksum1 := Checksum.calculate(str)
	checksum2 := Checksum.calculate(str)
	assert checksum1.value == checksum2.value
}

fn test_checksum_different_inputs() {
	checksum1 := Checksum.calculate('80x24,0,0,1')
	checksum2 := Checksum.calculate('80x24,0,0,2')
	assert checksum1.value != checksum2.value
}

fn test_checksum_known_tmux_layout_bb62() {
	// From tmux documentation: "bb62,159x48,0,0{79x48,0,0,79x48,80,0}"
	checksum := Checksum.calculate('159x48,0,0{79x48,0,0,79x48,80,0}')
	assert checksum.as_string() == 'bb62'
}
