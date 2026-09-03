module terminal

import regex

// A string along with the mapping of each individual byte in the string
// to the point in the screen.
//
// This is used for operations like regex matching where we need to map
// byte offsets in a string back to screen positions (Pins).

// StringMap holds a string and an array of Pins, where each Pin corresponds
// to one byte in the string, mapping it back to a screen position.
pub struct StringMap {
pub mut:
	str     string
	map_pin []Pin
}

// deinit frees the string and pin map.
pub fn (mut self StringMap) deinit() {
	self.str = ''
	self.map_pin = []
}

// search_iterator returns a SearchIterator for the given regex pattern.
//
// Ghostty receives an already compiled Oniguruma expression. Witty compiles
// the equivalent V regex here and returns its parse error to the caller.
pub fn (self StringMap) search_iterator(pattern string) !StringSearchIterator {
	re := regex.regex_opt(pattern)!
	return StringSearchIterator{
		smap: self
		regex: re
	}
}

// StringSearchIterator iterates over regular expression matches of the string.
pub struct StringSearchIterator {
pub mut:
	smap   StringMap
	regex  regex.RE
	offset int
}

// next returns the next regular expression match or none if there are
// no more matches.
pub fn (mut self StringSearchIterator) next() ?StringMatch {
	if self.offset >= self.smap.str.len {
		return none
	}

	base := self.offset
	start_idx, end_idx := self.regex.find_from(self.smap.str, base)
	if start_idx < 0 || end_idx < start_idx {
		self.offset = self.smap.str.len
		return none
	}

	// Match offsets are byte offsets, just like Oniguruma's region offsets.
	// Advance by the end of the match. Guard an empty match so iteration can
	// never get stuck at the same byte.
	self.offset = if end_idx > base { end_idx } else { base + 1 }
	return StringMatch{
		smap: self.smap
		start_byte: start_idx
		end_byte: end_idx
	}
}

// StringMatch represents a single regular expression match.
// Contains the mapping back to screen positions via the StringMap.
pub struct StringMatch {
pub mut:
	smap       StringMap
	start_byte int
	end_byte   int // exclusive
}

// V's regex matcher stores match offsets in the iterator and does not allocate
// a per-match region, so there is no owned match resource to release.
pub fn (mut self StringMatch) deinit() {
	_ = self
}

// selection returns the Selection containing the full match.
// Maps byte offsets back to screen positions via the pin map.
pub fn (self StringMatch) selection() Selection {
	assert self.start_byte >= 0
	assert self.end_byte > self.start_byte
	assert self.end_byte <= self.smap.map_pin.len
	return Selection.init(self.smap.map_pin[self.start_byte], self.smap.map_pin[self.end_byte - 1], false)
}
