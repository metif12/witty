module shaper

import datastruct
import font

// This structure caches the shaped cells for a given text run.
//
// At one point, shaping was the most expensive part of rendering text
// (accounting for 96% of frame time on my machine). To speed it up, this
// was introduced so that shaping results can be cached depending on the
// run.
//
// The cache key is the text run. The text run builds its own hash value
// based on the font, style, codepoint, etc. This just utilizes the hash that
// the text run provides.

// ShaperCache caches shaped text runs to avoid re-shaping.
pub struct ShaperCache {
mut:
	// Cache table for run hash -> shaped cells.
	// The key is the text run hash (u64), the value is the shaped cells.
	//
	// Capacity is slightly arbitrary. These numbers are guesses.
	//
	// I'd expect then an average of 256 frequently cached runs is a
	// safe guess most terminal screens.
	entries datastruct.U64CacheTable[[]font.ShapeCell]
}

// init creates a new ShaperCache.
pub fn ShaperCache.init() ShaperCache {
	return ShaperCache{
		entries: datastruct.U64CacheTable.init[[]font.ShapeCell]()
	}
}

// deinit releases all resources held by the cache.
pub fn (mut self ShaperCache) deinit() {
	self.clear()
}

// get returns the shaped cells for the given text run,
// or none if they are not in the cache.
pub fn (mut self ShaperCache) get(run font.TextRun) ?[]font.ShapeCell {
	return self.entries.get(run.hash)
}

// put inserts the shaped cells for the given text run into the cache.
//
// The cells will be duplicated.
pub fn (mut self ShaperCache) put(run font.TextRun, cells []font.ShapeCell) {
	// Clone the cells so the cache owns its own copy.
	copy := cells.clone()
	self.entries.put(run.hash, copy)
}

// clear removes all entries from the cache and frees their memory.
fn (mut self ShaperCache) clear() {
	self.entries.clear()
}

// count returns the number of cached entries.
pub fn (self &ShaperCache) count() int {
	return self.entries.count()
}
