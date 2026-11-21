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
	string string
	map    []Pin
}

// deinit frees the string and pin map.
pub fn (mut self StringMap) deinit() {
	self.string = ''
	self.map = []
}

// text returns the mapped string. V 0.5.2 master reads a `.string` field
// followed by indexing as the `string` type, so slicing goes through here.
fn (self StringMap) text() string {
	return self.string
}

// search_iterator returns an iterator for an already compiled expression.
pub fn (self StringMap) search_iterator(regex oniguruma.Regex) SearchIterator {
	return SearchIterator{
		map: self
		regex: regex
	}
}

// SearchIterator iterates over regular expression matches of the string.
pub struct SearchIterator {
pub mut:
	map    StringMap
	regex  oniguruma.Regex
	offset usize
}

// next returns the next regular expression match or none if there are
// no more matches.
pub fn (mut self SearchIterator) next() !MatchValue {
	if self.offset >= self.map.string.len {
		return MatchValue{}
	}

	mut region := self.regex.search(self.map.text()[self.offset..], oniguruma.Options{}) or {
		if oniguruma.is_error(err, .mismatch) {
			self.offset = usize(self.map.string.len)
			return MatchValue{}
		}
		return err
	}
	end_idx := usize(region.ends()[0])
	match_offset := self.offset
	self.offset += end_idx
	return MatchValue{
		has_value: true
		value: Match{
			map: self.map
			offset: match_offset
			region: region
		}
	}
}

// MatchValue preserves Ghostty's !?Match contract. V cannot nest an
// Option in a Result, so has_value represents the optional layer.
pub struct MatchValue {
pub:
	has_value bool
mut:
	value Match
}

pub fn (v MatchValue) get() ?Match {
	if !v.has_value {
		return none
	}
	return v.value
}

// Match represents a single regular expression match.
// Contains the mapping back to screen positions via the StringMap.
pub struct Match {
pub mut:
	map    StringMap
	offset usize
mut:
	region oniguruma.Region
}

// deinit releases the Oniguruma match region.
pub fn (mut self Match) deinit() {
	self.region.deinit()
}

// selection returns the Selection containing the full match.
// Maps byte offsets back to screen positions via the pin map.
pub fn (self Match) selection() Selection {
	starts := self.region.starts()
	ends := self.region.ends()
	start_idx := usize(starts[0])
	end_idx := usize(ends[0] - 1)
	return Selection.init(self.map.map[self.offset + start_idx], self.map.map[self.offset + end_idx], false)
}
