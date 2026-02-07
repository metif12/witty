module terminal

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
	map_pin []PagePin
}

// deinit frees the string and pin map.
pub fn (mut self StringMap) deinit() {
	self.str = ''
	self.map_pin = []
}

// SearchIterator iterates over regular expression matches of the string.
// XTODO: Regex matching requires oniguruma bindings which are not yet
// available. The search_iterator and SearchIterator are stubbed out.

// search_iterator returns a SearchIterator for the given regex pattern.
// XTODO: This is a stub. Requires oniguruma regex support.
pub fn (self StringMap) search_iterator(pattern string) StringSearchIterator {
	return StringSearchIterator{
		smap: self
		pattern: pattern
	}
}

// StringSearchIterator iterates over regular expression matches of the string.
// XTODO: This is a stub. Requires oniguruma regex support.
pub struct StringSearchIterator {
pub mut:
	smap    StringMap
	pattern string
	offset  int
}

// next returns the next regular expression match or none if there are
// no more matches.
// XTODO: This is a stub. Always returns none until oniguruma is integrated.
pub fn (mut self StringSearchIterator) next() ?StringMatch {
	// XTODO: Implement using oniguruma regex library.
	// When implemented, this should:
	// 1. Search self.smap.str[self.offset..] using the compiled regex
	// 2. On match, create a StringMatch with the match region
	// 3. Advance self.offset by the end of the match
	// 4. Return none on no more matches
	return none
}

// StringMatch represents a single regular expression match.
// Contains the mapping back to screen positions via the StringMap.
pub struct StringMatch {
pub mut:
	smap       StringMap
	offset     int
	start_byte int
	end_byte   int
}

// deinit cleans up the match resources.
// XTODO: When oniguruma is integrated, this should free the region.
pub fn (mut self StringMatch) deinit() {
	// XTODO: Free oniguruma region
}

// selection returns the Selection containing the full match.
// Maps byte offsets back to screen positions via the pin map.
pub fn (self StringMatch) selection() Selection {
	start_pt := self.smap.map_pin[self.offset + self.start_byte]
	end_pt := self.smap.map_pin[self.offset + self.end_byte]
	return Selection.init(start_pt, end_pt, false)
}
