module vaxis

// Pinned vaxis GraphemeCache.zig: a wrapping 8 KiB store for event key text.
pub struct GraphemeCache {
mut:
	buf [8192]u8
	idx usize
}

pub fn GraphemeCache.new() GraphemeCache {
	return GraphemeCache{}
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
	// Direct fixed-array slices copy in V; this view borrows the source buffer.
	return unsafe { (&cache.buf[0] + int(start)).vbytes(bytes.len) }
}
