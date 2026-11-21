module vaxis

fn test_unicode_iterator_borrows_complete_clusters_and_exhausts() {
	text := 'é界👩‍🚀'
	mut iter := GraphemeIterator.init(text)
	mut factory := grapheme_iterator(text)
	for expected in ['é', '界', '👩‍🚀'] {
		span := iter.next() or { panic('missing grapheme') }
		alt := factory.next() or { panic('missing factory grapheme') }
		assert span == alt
		bytes := span.bytes(text)
		assert bytes == expected
		assert unsafe { uint(bytes.str) == uint(text.str) + span.start }
	}
	for _ in 0 .. 3 {
		assert iter.next() == none
		assert factory.next() == none
	}
	assert first_grapheme_byte_length(text) == 'é'.len
}

fn test_unicode_iterator_preserves_malformed_source_bytes() {
	text := '\xe1\x80ab'
	mut iter := grapheme_iterator(text)
	first := iter.next() or { panic('missing malformed grapheme') }
	assert first.start == 0
	assert first.len == 3
	assert first.bytes(text) == '\xe1\x80a'
	second := iter.next() or { panic('missing trailing grapheme') }
	assert second.start == 3
	assert second.len == 1
	assert second.bytes(text) == 'b'
	assert iter.next() == none
	assert first_grapheme_byte_length(text) == 3
	for method in [GWidthMethod.unicode, .wcwidth, .no_zwj] {
		assert gwidth(text, method) == 2
	}
}

fn test_width_methods_keep_emoji_and_selector_rules() {
	assert gwidth('👩‍🚀', .unicode) == 2
	assert gwidth('👩‍🚀', .wcwidth) == 4
	assert gwidth('👩‍🚀', .no_zwj) == 4
	assert gwidth('👋🏿', .unicode) == 2
	assert gwidth('👋🏿', .wcwidth) == 4
	assert gwidth('❤︎', .unicode) == 1
	assert gwidth('❤️', .unicode) == 2
	assert gwidth('❤️', .wcwidth) == 1
	assert gwidth('1️⃣', .unicode) == 2
	assert gwidth('🇺🇸', .unicode) == 2
	for method in [GWidthMethod.unicode, .wcwidth, .no_zwj] {
		assert gwidth('\x00\x1b\u0301\u200b\u200c\u200d', method) == 0
	}
}

fn test_grapheme_bytes_accepts_arbitrary_borrowed_spans() {
	text := 'aé界'
	for start in 0 .. text.len + 1 {
		for length in 0 .. text.len - start + 1 {
			span := Grapheme{
				start: uint(start)
				len:   uint(length)
			}
			bytes := span.bytes(text)
			assert bytes == text[start..start + length]
			assert unsafe { uint(bytes.str) == uint(text.str) + span.start }
		}
	}
}

fn test_width_checked_limit_returns_last_representable_total() {
	for method in [GWidthMethod.unicode, .wcwidth, .no_zwj] {
		assert gwidth('a'.repeat(65535), method) == 65535
		assert gwidth('界'.repeat(32767), method) == 65534
	}
}

fn test_unicode_iterator_prefetches_first_codepoint_and_borrows_later_bytes() {
	mut backing := 'abc'.bytes()
	text := unsafe { tos(backing.data, backing.len) }
	mut iter := grapheme_iterator(text)
	backing[1] = 0xcc
	backing[2] = 0x81
	span := iter.next() or { panic('missing mutated grapheme') }
	assert span.start == 0
	assert span.len == 3
	bytes := span.bytes(text)
	backing[0] = `x`
	assert bytes == 'x́'
	assert iter.next() == none

	mut control := '\r\nb'.bytes()
	control_text := unsafe { tos(control.data, control.len) }
	mut prefetched := GraphemeIterator.init(control_text)
	control[0] = `a`
	first := prefetched.next() or { panic('missing prefetched control pair') }
	assert first.len == 2
	assert first.bytes(control_text) == 'a\n'
}
