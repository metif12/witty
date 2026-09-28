module vaxis

// Pinned vaxis GraphemeCache.zig: a wrapping 8 KiB store for event key text.
pub struct GraphemeCache {
mut:
	buf []u8
	idx usize
}

pub fn GraphemeCache.new() GraphemeCache {
	return GraphemeCache{
		buf: []u8{len: 8192}
	}
}

pub fn (mut cache GraphemeCache) put(bytes []u8) []u8 {
	if cache.idx + usize(bytes.len) > usize(cache.buf.len) {
		cache.idx = 0
	}
	assert bytes.len <= cache.buf.len
	start := cache.idx
	for i, byte in bytes {
		cache.buf[int(start) + i] = byte
	}
	cache.idx += usize(bytes.len)
	return cache.buf[int(start)..int(cache.idx)]
}
