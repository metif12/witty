module shaper

import ascii
import strconv

// Represents an OpenType font feature setting, which consists of a tag and
// a numeric parameter >= 0. Most features are boolean, so only parameters
// of 0 and 1 make sense for them, but some (e.g. 'cv01'..'cv99') can take
// parameters to choose between multiple variants of a given character or
// characters.
//
// Ref:
// - https://learn.microsoft.com/en-us/typography/opentype/spec/chapter2#features-and-lookups
// - https://harfbuzz.github.io/shaping-opentype-features.html
pub struct Feature {
pub:
	tag   [4]u8
	value u32
}

// from_string parses a single font feature setting from a string, with a
// version of the syntax of HarfBuzz's font feature strings.
//
// This parsing aims to be as error-tolerant as possible while avoiding any
// assumptions in ambiguous scenarios.
//
// Supported formats:
//   "kern"           -> tag=kern, value=1 (just a tag turns it on)
//   "+kern"          -> tag=kern, value=1
//   "-kern"          -> tag=kern, value=0
//   "kern=1"         -> tag=kern, value=1
//   "kern=0"         -> tag=kern, value=0
//   "aalt=2"         -> tag=aalt, value=2
//   "'kern' = 1"     -> tag=kern, value=1 (quotes around tag are stripped)
//   "\"kern\" = 1"   -> tag=kern, value=1 (double quotes also stripped)
//   "kern on"        -> tag=kern, value=1
//   "kern off"       -> tag=kern, value=0
//
// Returns none if the string is invalid or ambiguous.
//
// Ref: https://harfbuzz.github.io/harfbuzz-hb-common.html#hb-feature-from-string
pub fn Feature.from_string(str string) ?Feature {
	// Feature.fromReader in the source stops at the first comma. Keeping the
	// boundary separate also lets this parser preserve its exact whitespace
	// rules: only spaces and tabs are ignored.
	comma_idx := str.index_u8(`,`)
	end := if comma_idx >= 0 { comma_idx } else { str.len }
	mut pos := 0
	for pos < end && (str[pos] == ` ` || str[pos] == `\t`) {
		pos++
	}
	if pos == end {
		return none
	}

	mut value_set := false
	mut value := u32(0)
	if str[pos] == `+` || str[pos] == `-` {
		value_set = true
		value = if str[pos] == `+` { u32(1) } else { u32(0) }
		pos++
	}

	mut tag_buf := [4]u8{}
	mut tag_len := 0
	for tag_len < 4 {
		if pos == end {
			return none
		}
		byte := str[pos]
		pos++
		// The source deliberately ignores quote marks anywhere in the tag.
		if byte == `"` || byte == `'` {
			continue
		}
		tag_buf[tag_len] = byte
		tag_len++
	}

	// This is the source's `space` state. Multiple '=' bytes are accepted when
	// no +/- prefix supplied a value, because every '=' remains in this state.
	for pos < end {
		byte := str[pos]
		if byte == ` ` || byte == `\t` || byte == `"` || byte == `'` {
			pos++
			continue
		}
		if byte == `=` {
			if value_set {
				return none
			}
			pos++
			continue
		}
		if byte >= `0` && byte <= `9` {
			if value_set {
				return none
			}
			start := pos
			for pos < end && str[pos] >= `0` && str[pos] <= `9` {
				pos++
			}
			if pos != end {
				return none
			}
			parsed := strconv.parse_uint(str[start..pos], 10, 32) or { return none }
			value = u32(parsed)
			value_set = true
			break
		}
		if byte == `o` || byte == `O` {
			if value_set {
				return none
			}
			pos++
			bool_start := pos
			for pos < end && str[pos] != ` ` && str[pos] != `\t` {
				pos++
			}
			keyword := str[bool_start..pos]
			if ascii.eql_ignore_case(keyword, 'n') {
				value = 1
			} else if ascii.eql_ignore_case(keyword, 'ff') {
				value = 0
			} else {
				return none
			}
			value_set = true
			for pos < end && (str[pos] == ` ` || str[pos] == `\t`) {
				pos++
			}
			if pos != end {
				return none
			}
			break
		}
		return none
	}

	if !value_set {
		value = 1
	}
	return Feature{
		tag: tag_buf
		value: value
	}
}

// str formats the feature as a string suitable for parsing back.
// Boolean options are formatted as "+tag" for on and "-tag" for off.
// Non-boolean tags are formatted as "tag=value".
pub fn (self Feature) str() string {
	tag_str := [self.tag[0], self.tag[1], self.tag[2], self.tag[3]].bytestr()
	if self.value <= 1 {
		// Format boolean options as "+tag" for on and "-tag" for off.
		prefix := if self.value == 1 { u8(`+`) } else { u8(`-`) }
		return [prefix].bytestr() + tag_str
	} else {
		// Format non-boolean tags as "tag=value".
		return '${tag_str}=${self.value}'
	}
}

// A list of font feature settings (see Feature for more documentation).
pub struct FeatureList {
pub mut:
	features []Feature
}

// from_string parses a comma separated list of features.
// See Feature.from_string for more docs.
pub fn FeatureList.from_string(str string) FeatureList {
	mut list := FeatureList{}
	list.append_from_string(str)
	return list
}

// append_from_string appends features to this list from a string with a
// comma separated list. See Feature.from_string for more docs.
pub fn (mut self FeatureList) append_from_string(str string) {
	parts := str.split(',')
	for part in parts {
		if feat := Feature.from_string(part) {
			self.features << feat
		}
	}
}

// deinit releases all resources held by the feature list.
pub fn (mut self FeatureList) deinit() {
	self.features = []
}

// str formats the feature list as a comma separated string.
pub fn (self FeatureList) str() string {
	mut parts := []string{cap: self.features.len}
	for feat in self.features {
		parts << feat.str()
	}
	return parts.join(', ')
}

// These features are hardcoded to always be on by default. Users
// can turn them off by setting the features to "-liga" for example.
pub const default_features = [
	Feature{
		tag: [u8(`l`), u8(`i`), u8(`g`), u8(`a`)]!
		value: 1
	},
]
