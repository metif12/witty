module vaxis

fn test_vaxis_grapheme_cache_wraps_and_returns_stable_slice() {
	mut cache := GraphemeCache.new()
	first := cache.put('abc'.bytes())
	assert first.bytestr() == 'abc'
	assert cache.idx == 3
	cache.put([]u8{len: 8189, init: `x`})
	assert cache.idx == 8192
	assert first.bytestr() == 'abc'
	wrapped := cache.put('z'.bytes())
	assert cache.idx == 1
	assert wrapped.bytestr() == 'z'
	assert first.bytestr() == 'zbc'
}
