module lib_allocator

fn test_scalar_convenience_allocations_are_writable_and_nullable_on_free() {
	assert sizeof(Opaque) == sizeof(voidptr)
	opaque := alloc_opaque()
	assert !isnil(opaque)
	unsafe {
		opaque.value = voidptr(uint(0x1234))
		assert uint(opaque.value) == uint(0x1234)
	}
	free_opaque(opaque)
	free_opaque(unsafe { nil })

	byte := alloc_u8()
	assert !isnil(byte)
	unsafe {
		*byte = 0xAB
		assert *byte == 0xAB
	}
	free_u8(byte)
	free_u8(unsafe { nil })

	word := alloc_usize()
	assert !isnil(word)
	unsafe {
		*word = uint(0x12345678)
		assert *word == uint(0x12345678)
	}
	free_usize(word)
	free_usize(unsafe { nil })
}

fn test_array_convenience_allocations_preserve_element_width() {
	bytes := alloc_u8_array(3)
	assert !isnil(bytes)
	unsafe {
		bytes[0] = 1
		bytes[1] = 2
		bytes[2] = 3
		assert bytes[0] == 1
		assert bytes[1] == 2
		assert bytes[2] == 3
	}
	free_u8_array(bytes, 3)

	words := alloc_u16_array(2)
	assert !isnil(words)
	unsafe {
		words[0] = 0x1234
		words[1] = 0xABCD
		assert words[0] == 0x1234
		assert words[1] == 0xABCD
	}
	free_u16_array(words, 2)

	zero_bytes := alloc_u8_array(0)
	assert !isnil(zero_bytes)
	free_u8_array(zero_bytes, 0)
	zero_words := alloc_u16_array(0)
	assert !isnil(zero_words)
	free_u16_array(zero_words, 0)
	assert isnil(alloc_u16_array(allocator_max_usize))
}
