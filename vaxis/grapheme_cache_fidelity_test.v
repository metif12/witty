module vaxis

fn test_grapheme_cache_public_inline_storage_and_successful_index_state() {
	mut cache := GraphemeCache{
		idx: 8191
	}
	cache.buf[8191] = 7
	result := cache.put([u8(42)])
	assert result.data == unsafe { &cache.buf[0] + 8191 }
	assert result == [u8(42)]
	assert cache.idx == 8192
	empty := cache.put([]u8{})
	assert empty.len == 0 && empty.data == unsafe { &cache.buf[0] + 8192 }
	assert cache.idx == 8192
	cache.idx = ~uint(0)
	wrapped_empty := cache.put([]u8{})
	assert wrapped_empty.len == 0 && wrapped_empty.data == &cache.buf[0]
	assert cache.idx == 0
}

fn test_grapheme_cache_mutable_return_borrows_bytes_after_wrap() {
	mut cache := GraphemeCache.new()
	mut old := cache.put('abc'.bytes())
	old[1] = `Q`
	assert cache.buf[1] == `Q`
	cache.idx = 8192
	wrapped := cache.put('Z'.bytes())
	assert wrapped.data == old.data && wrapped == [u8(`Z`)]
	assert old.bytestr() == 'ZQc'
	cache.buf[2] = `R`
	assert old.bytestr() == 'ZQR'
}

fn test_grapheme_cache_value_copy_has_independent_inline_bytes() {
	mut cache := GraphemeCache{}
	for i in 0 .. cache.buf.len {
		cache.buf[i] = 17
	}
	cache.buf[0] = 42
	cache.idx = 1
	mut copied := cache
	result := copied.put('xy'.bytes())
	assert result.data == unsafe { &copied.buf[0] + 1 }
	assert cache.idx == 1 && copied.idx == 3
	assert cache.buf[0] == 42 && copied.buf[0] == 42
	cache.buf[0] = 99
	assert copied.buf[0] == 42
	assert cache.buf[1] == 17 && copied.buf[1] == `x`
	assert sizeof(GraphemeCache) == 8192 + sizeof(uint)
}

fn test_grapheme_cache_disjoint_adjacent_views_copy_without_alias_trap() {
	mut cache := GraphemeCache{}
	cache.buf[0] = 1
	cache.buf[1] = 2
	cache.idx = 2
	source := unsafe { (&cache.buf[0]).vbytes(2) }
	result := cache.put(source)
	assert result == [u8(1), 2]
	assert result.data == unsafe { &cache.buf[0] + 2 }
	assert cache.idx == 4
	cache.idx = 0
	reversed_source := unsafe { (&cache.buf[0] + 2).vbytes(2) }
	assert cache.put(reversed_source) == [u8(1), 2]
	assert cache.idx == 2
}
