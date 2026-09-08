module terminal

import oniguruma

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

// search_iterator returns an iterator for an already compiled expression.
pub fn (self StringMap) search_iterator(regex oniguruma.Regex) StringSearchIterator {
	return StringSearchIterator{
		smap: self
		regex: regex
	}
}

// StringSearchIterator iterates over regular expression matches of the string.
pub struct StringSearchIterator {
pub mut:
	smap   StringMap
	regex  oniguruma.Regex
	offset int
}

// next returns the next regular expression match or none if there are
// no more matches.
pub fn (mut self StringSearchIterator) next() !StringMatchValue {
	if self.offset >= self.smap.str.len {
		return StringMatchValue{}
	}

	mut region := self.regex.search(self.smap.str[self.offset..], oniguruma.Options{}) or {
		if err.msg() == oniguruma.mismatch_error {
			self.offset = self.smap.str.len
			return StringMatchValue{}
		}
		return err
	}
	end_idx := region.ends()[0]
	match_offset := self.offset
	self.offset += end_idx
	return StringMatchValue{
		has_value: true
		value: StringMatch{
			smap: self.smap
			offset: match_offset
			region: region
		}
	}
}

// StringMatchValue preserves Ghostty's !?Match contract. V cannot nest an
// Option in a Result, so has_value represents the optional layer.
pub struct StringMatchValue {
pub:
	has_value bool
mut:
	value StringMatch
}

pub fn (v StringMatchValue) get() ?StringMatch {
	if !v.has_value {
		return none
	}
	return v.value
}

// StringMatch represents a single regular expression match.
// Contains the mapping back to screen positions via the StringMap.
pub struct StringMatch {
pub mut:
	smap   StringMap
	offset int
mut:
	region oniguruma.Region
}

// deinit releases the Oniguruma match region.
pub fn (mut self StringMatch) deinit() {
	self.region.deinit()
}

// selection returns the Selection containing the full match.
// Maps byte offsets back to screen positions via the pin map.
pub fn (self StringMatch) selection() Selection {
	starts := self.region.starts()
	ends := self.region.ends()
	start_idx := self.offset + starts[0]
	end_idx := self.offset + ends[0] - 1
	return Selection.init(self.smap.map_pin[start_idx], self.smap.map_pin[end_idx], false)
}
