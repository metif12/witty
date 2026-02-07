module shaper

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
	// Trim the input to just the first feature (up to comma or end).
	mut s := str
	comma_idx := s.index_u8(`,`)
	if comma_idx >= 0 {
		s = s[..comma_idx]
	}
	// Trim whitespace
	s = s.trim_space()
	if s.len == 0 {
		return none
	}

	mut pos := 0
	mut prefix_value := ?u32(none)

	// Check for '+' or '-' prefix to explicitly enable/disable feature.
	if s[pos] == `+` {
		prefix_value = 1
		pos++
	} else if s[pos] == `-` {
		prefix_value = 0
		pos++
	}

	// Strip quote marks from the tag portion.
	// Collect exactly 4 tag bytes, skipping any quote characters.
	mut tag_buf := [4]u8{}
	mut tag_len := 0

	for pos < s.len && tag_len < 4 {
		ch := s[pos]
		pos++
		// Ignore quote marks. This does technically ignore cases like
		// "'k'e'r'n' = 0", but it's unambiguous so if someone really
		// wants to do that in their config then... sure why not.
		if ch == `"` || ch == `'` {
			continue
		}
		// If the tag is interrupted by a comma it's invalid.
		if ch == `,` {
			return none
		}
		tag_buf[tag_len] = ch
		tag_len++
	}

	// Tag must be exactly 4 characters.
	if tag_len != 4 {
		return none
	}

	// Skip any trailing quote marks after the tag.
	for pos < s.len && (s[pos] == `"` || s[pos] == `'`) {
		pos++
	}

	// Now parse what remains after the tag.
	remaining := s[pos..].trim_space()

	if remaining.len == 0 {
		// Specifying only a tag turns a feature on.
		val := prefix_value or { 1 }
		return Feature{
			tag: tag_buf
			value: val
		}
	}

	// If we have a prefix (+/-) then having additional value is an error
	// (redundant/conflicting).
	// Exception: '=' is allowed to separate tag from value.
	mut value_str := remaining

	if value_str[0] == `=` {
		// Allow an '=' only if we don't already have a value due
		// to a '+' or '-' prefix.
		if prefix_value != none {
			return none
		}
		value_str = value_str[1..].trim_space()
	}

	if value_str.len == 0 {
		val := prefix_value or { 1 }
		return Feature{
			tag: tag_buf
			value: val
		}
	}

	// Try parsing a boolean keyword parameter ("on"/"off").
	lower := value_str.to_lower()
	if lower == 'on' {
		if prefix_value != none {
			return none
		}
		return Feature{
			tag: tag_buf
			value: 1
		}
	}
	if lower == 'off' {
		if prefix_value != none {
			return none
		}
		return Feature{
			tag: tag_buf
			value: 0
		}
	}

	// Try parsing an integer parameter directly.
	if prefix_value != none {
		// If we already have value because of a '+' or '-' prefix
		// then this is an error.
		return none
	}

	// Validate that all characters are digits.
	for ch in value_str {
		if ch < `0` || ch > `9` {
			return none
		}
	}
	// Parse the integer value.
	parsed := value_str.u32()
	return Feature{
		tag: tag_buf
		value: parsed
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
		trimmed := part.trim_space()
		if trimmed.len == 0 {
			continue
		}
		if feat := Feature.from_string(trimmed) {
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
