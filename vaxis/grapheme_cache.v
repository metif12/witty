module vaxis

// Pinned vaxis GraphemeCache.zig: a wrapping 8 KiB store for event key text.
pub struct GraphemeCache {
pub mut:
	buf [8192]u8
	idx uint
}

pub fn GraphemeCache.new() GraphemeCache {
	return GraphemeCache{}
}

pub fn (mut cache GraphemeCache) put(bytes []u8) []u8 {
	length := uint(bytes.len)
	if grapheme_cache_add(cache.idx, length) > uint(cache.buf.len) {
		cache.idx = 0
	}
	start := cache.idx
	limit := grapheme_cache_add(start, length)
	if start > uint(cache.buf.len) || limit > uint(cache.buf.len) {
		panic('index out of bounds')
	}
	destination := unsafe { &cache.buf[0] + int(start) }
	if length > 0 {
		source_address := uint(bytes.data)
		destination_address := uint(destination)
		if (destination_address <= source_address && source_address - destination_address < length)
			|| (source_address < destination_address
			&& destination_address - source_address < length) {
			panic('@memcpy arguments alias')
		}
		unsafe { vmemcpy(destination, bytes.data, bytes.len) }
	}
	// Source advances in a defer after the copy and borrowed return expression.
	cache.idx = grapheme_cache_add(cache.idx, length)
	// Direct fixed-array slices copy in V; this view borrows the source buffer.
	return unsafe { destination.vbytes(bytes.len) }
}

fn grapheme_cache_add(first uint, second uint) uint {
	if second > ~uint(0) - first { panic('integer overflow') }
	return first + second
}
