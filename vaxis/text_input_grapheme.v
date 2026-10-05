module vaxis

import unicode

// Shared byte decoder for unicode.zig and the widgets that use its iterators,
// including the locked uucode iterator's malformed-byte consumption.
struct TextInputGrapheme {
	start int
	limit int
}

struct TextInputGraphemeIterator {
mut:
	inner      InputUtf8Iterator
	next_cp    ?u32
	state      unicode.BreakState = .default
	start      int
	prev_break bool = true
}

fn text_input_grapheme_iterator(text string) TextInputGraphemeIterator {
	mut inner := InputUtf8Iterator{
		bytes: unsafe { text.str.vbytes(text.len) }
	}
	next_cp := inner.next()
	return TextInputGraphemeIterator{
		inner:   inner
		next_cp: next_cp
	}
}

fn (mut iter TextInputGraphemeIterator) next() ?TextInputGrapheme {
	for {
		cp := iter.next_cp or { return none }
		limit := iter.inner.i
		iter.next_cp = iter.inner.next()
		is_break := if next := iter.next_cp {
			vaxis_grapheme_break(cp, next, &iter.state)
		} else {
			true
		}
		if iter.prev_break && !is_break {
			cp_len := if cp < 0x80 {
				1
			} else if cp < 0x800 {
				2
			} else if cp < 0x10000 {
				3
			} else {
				4
			}
			if limit < cp_len { panic('integer overflow') }
			iter.start = limit - cp_len
		}
		if is_break {
			start := iter.start
			iter.start = limit
			iter.prev_break = true
			return TextInputGrapheme{
				start: start
				limit: limit
			}
		}
		iter.prev_break = false
	}
	return none
}

fn text_input_first_grapheme_byte_length(text string) int {
	mut iter := text_input_grapheme_iterator(text)
	value := iter.next() or { return 0 }
	return value.limit - value.start
}

fn text_input_last_grapheme_byte_length(text string) int {
	mut iter := text_input_grapheme_iterator(text)
	mut length := 0
	for {
		value := iter.next() or { break }
		length = value.limit - value.start
	}
	return length
}

fn text_input_checked_u16_add(a int, b int) int {
	if b > 0xffff - a { panic('integer overflow') }
	return a + b
}

// Width calculations use the same locked byte decoder as grapheme iteration.
fn text_input_gwidth(value string, method GWidthMethod) u16 {
	match method {
		.wcwidth {
			mut iter := InputUtf8Iterator{
				bytes: value.bytes()
			}
			mut total := 0
			for {
				cp := iter.next() or { break }
				width := if cp >= 0x1f3fb && cp <= 0x1f3ff { 2 } else { eaw_to_width(cp) }
				if width > 0 { total = text_input_checked_u16_add(total, width) }
			}
			return u16(total)
		}
		.no_zwj {
			mut total := 0
			for part in value.split('\u200d') {
				total = text_input_checked_u16_add(total, int(text_input_gwidth(part, .unicode)))
			}
			return u16(total)
		}
		.unicode {
			mut iter := text_input_grapheme_iterator(value)
			mut total := 0
			for {
				grapheme := iter.next() or { break }
				mut inner := InputUtf8Iterator{
					bytes: value[grapheme.start..grapheme.limit].bytes()
				}
				mut width := 0
				mut emoji_vs := false
				mut text_vs := false
				mut emoji_presentation := false
				mut ri_count := 0
				for {
					cp := inner.next() or { break }
					if cp == 0xfe0f {
						emoji_vs = true
						continue
					}
					if cp == 0xfe0e {
						text_vs = true
						continue
					}
					if width_property(cp, 2) { emoji_presentation = true }
					if cp >= 0x1f1e6 && cp <= 0x1f1ff {
						if ri_count == 0xff { panic('integer overflow') }
						ri_count++
					}
					cp_width := eaw_to_width(cp)
					if cp_width > width { width = cp_width }
				}
				if text_vs {
					if width < 1 { width = 1 }
				} else if emoji_vs || emoji_presentation || ri_count == 2 {
					if width < 2 { width = 2 }
				}
				total = text_input_checked_u16_add(total, width)
			}
			return u16(total)
		}
	}
}
