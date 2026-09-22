module lib_allocator

fn test_scalar_convenience_allocations_are_writable_and_nullable_on_free() {
	opaque := alloc_opaque() or { panic('opaque allocation failed') }
	unsafe {
		*opaque = voidptr(usize(0x1234))
		assert usize(*opaque) == usize(0x1234)
	}
	free_opaque(opaque)
	free_opaque(none)

	byte := alloc_u8() or { panic('u8 allocation failed') }
	unsafe {
		*byte = 0xAB
		assert *byte == 0xAB
	}
	free_u8(byte)
	free_u8(none)

	word := alloc_usize() or { panic('usize allocation failed') }
	unsafe {
		*word = usize(0x12345678)
		assert *word == usize(0x12345678)
	}
	free_usize(word)
	free_usize(none)
}

fn test_array_convenience_allocations_preserve_element_width() {
	bytes := alloc_u8_array(3) or { panic('u8 array allocation failed') }
	unsafe {
		bytes[0] = 1
		bytes[1] = 2
		bytes[2] = 3
		assert bytes[0] == 1
		assert bytes[1] == 2
		assert bytes[2] == 3
	}
	free_u8_array(bytes, 3)

	words := alloc_u16_array(2) or { panic('u16 array allocation failed') }
	unsafe {
		words[0] = 0x1234
		words[1] = 0xABCD
		assert words[0] == 0x1234
		assert words[1] == 0xABCD
	}
	free_u16_array(words, 2)

	zero_bytes := alloc_u8_array(0) or { panic('zero-length u8 allocation failed') }
	free_u8_array(zero_bytes, 0)
	zero_words := alloc_u16_array(0) or { panic('zero-length u16 allocation failed') }
	free_u16_array(zero_words, 0)
	assert alloc_u16_array(allocator_max_usize) == none
}
