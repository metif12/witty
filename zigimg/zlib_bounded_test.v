module zigimg

import compress.zlib

fn test_bounded_zlib_uses_source_limit_and_header_contract() {
	plain := 'bounded source reader'.bytes()
	mut compressed := zlib.compress(plain)!
	assert decode_zlib_bounded(compressed, usize(plain.len + 1))! == plain
	decode_zlib_bounded(compressed, usize(plain.len)) or { assert err.msg() == 'StreamTooLong' }
	decode_zlib_bounded(compressed, 1) or { assert err.msg() == 'StreamTooLong' }
	decode_zlib_bounded(compressed, 0) or { assert err.msg() == 'StreamTooLong' }
	// Container.Header checks CM/CINFO, but deliberately ignores FCHECK/FDICT
	// and the footer checksum, unlike V's zlib implementation.
	compressed[1] = 0xff
	compressed[compressed.len - 1] ^= 0xff
	assert decode_zlib_bounded(compressed, usize(plain.len + 1))! == plain
	compressed[0] = 0x79
	decode_zlib_bounded(compressed, usize(plain.len + 1)) or { assert err.msg() == 'ReadFailed' }
}

fn test_bounded_zlib_does_not_decode_unbounded_output() {
	plain := []u8{len: 200000, init: `a`}
	// Stored blocks exercise repeated history-window fills independently of
	// the source fixed-Huffman writer's checked match-at-window-end invariant.
	mut compressed := [u8(0x78), 0x01]
	mut offset := 0
	for offset < plain.len {
		count := if plain.len - offset < 32768 { plain.len - offset } else { 32768 }
		last := offset + count == plain.len
		compressed << u8(if last { 1 } else { 0 })
		compressed << [u8(count), u8(count >> 8), u8(~u16(count)), u8(~u16(count) >> 8)]
		compressed << plain[offset..offset + count]
		offset += count
	}
	compressed << [u8(0), 0, 0, 0]
	decode_zlib_bounded(compressed, 32) or { assert err.msg() == 'StreamTooLong' }
	assert decode_zlib_bounded(compressed, usize(plain.len + 1))! == plain
}
