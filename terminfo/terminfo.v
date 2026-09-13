// Package terminfo provides functionality related to terminfo/termcap files.
//
// Translated from ghostty/src/terminfo/main.zig and
// ghostty/src/terminfo/Source.zig.
//
// At the time of writing this comment, the focus is on generating terminfo
// files so that we can maintain our terminfo in V instead of hand-writing the
// archaic (imo) terminfo format by hand. But eventually we may want to extract
// this into a more full-featured library on its own.
//
// Background: https://invisible-island.net/ncurses/man/terminfo.5.html
module terminfo

// CapabilityValueTag is the tag of `Source.Capability.Value`. The source's
// union payloads are flattened into the fields below, since V has no tagged
// union with per-arm payload storage.
pub enum CapabilityValueTag as u8 {
	// Canceled value, i.e. suffixed with @
	canceled
	// Boolean values are always true if they exist so there is no value.
	boolean
	// Numeric values are always "unsigned decimal integers". The size of the
	// integer is unspecified in terminfo(5). Ghostty chose 32-bits because it
	// is a common integer size but this may be wrong.
	numeric
	string
}

// CapabilityValue is `Source.Capability.Value`.
pub struct CapabilityValue {
pub:
	tag     CapabilityValueTag @[required]
	numeric u32
	str     string
}

pub fn CapabilityValue.canceled() CapabilityValue {
	return CapabilityValue{
		tag: .canceled
	}
}

pub fn CapabilityValue.boolean() CapabilityValue {
	return CapabilityValue{
		tag: .boolean
	}
}

pub fn CapabilityValue.numeric(value u32) CapabilityValue {
	return CapabilityValue{
		tag: .numeric
		numeric: value
	}
}

pub fn CapabilityValue.string(value string) CapabilityValue {
	return CapabilityValue{
		tag: .string
		str: value
	}
}

// Capability is a capability in a terminfo file. This also includes any "use"
// capabilities since they behave just like other capabilities as documented in
// terminfo(5).
pub struct Capability {
pub:
	// The name of capability. This is the "Cap-name" value in terminfo(5).
	name  string          @[required]
	value CapabilityValue @[required]
}

// Source is the terminfo source format. This can be used to encode terminfo
// files. This cannot parse terminfo source files yet because it isn't
// something Ghostty needs to do, but this can be added later.
pub struct Source {
pub:
	// The set of names for the terminal. These match the TERM environment
	// variable and are used to look up this terminal. Historically, the final
	// name in the list was the most common name for the terminal and contains
	// spaces and other characters. See terminfo(5) for details.
	names []string @[required]
	// The set of capabilities in this terminfo file.
	capabilities []Capability @[required]
}

// encode returns this source as a terminfo source file. The encoding is always
// done in a human-readable format with whitespace. Fields are always written in
// the order of the slices on this struct; this will not do any reordering.
pub fn (self &Source) encode() string {
	mut out := []u8{}

	// Encode the names in the order specified
	for i, name in self.names {
		if i != 0 {
			out << `|`
		}
		out << name.bytes()
	}
	out << `,`
	out << `\n`

	// Encode each of the capabilities in the order specified
	for cap in self.capabilities {
		out << `\t`
		out << cap.name.bytes()
		match cap.value.tag {
			.canceled { out << `@` }
			.boolean {}
			.numeric { out << '#${cap.value.numeric}'.bytes() }
			.string { out << '=${cap.value.str}'.bytes() }
		}
		out << `,`
		out << `\n`
	}

	return out.bytestr()
}

// xtgettcap_map returns the map of all the capabilities in this terminfo,
// keyed by the hex-encoded capability name. The value is the value that should
// be sent as a response to XTGETTCAP.
//
// Important: the value is the FULL response including the escape sequences.
//
// Ghostty builds this as a comptime `StaticStringMap`; V has no comptime map,
// so it is built on demand from the same inputs in the same order.
pub fn (self &Source) xtgettcap_map() map[string]string {
	mut result := map[string]string{}

	// We have all of our capabilities plus TN, Co, and RGB which aren't in the
	// capabilities list but are query-able.
	mut pairs := [][2]string{cap: self.capabilities.len + 3}
	pairs << ['TN', self.names[0]]!
	pairs << ['Co', '256']!
	pairs << ['RGB', '8']!

	for cap in self.capabilities {
		pairs << [cap.name, xtgettcap_raw_value(cap.value)]!
	}

	for pair in pairs {
		key := hexencode(pair[0])
		value := pair[1]
		result[key] = if value == '' {
			'\x1bP1+r${key}\x1b\\'
		} else {
			'\x1bP1+r${key}=${hexencode(value)}\x1b\\'
		}
	}

	return result
}

// xtgettcap_raw_value is the pre-hex-encoding XTGETTCAP payload for a value.
fn xtgettcap_raw_value(value CapabilityValue) string {
	return match value.tag {
		.canceled {
			// Ghostty raises a compile error here; nothing in its terminfo is
			// canceled, so reaching this means the data changed.
			panic('canceled not handled yet')
		}
		.boolean {
			''
		}
		.numeric {
			value.numeric.str()
		}
		.string {
			decode_capability_string(value.str)
		}
	}
}

// decode_capability_string converts a terminfo-source string to the form
// XTGETTCAP reports it in.
//
// If a string contains parameters, then we do not escape anything within the
// string. I BELIEVE the history here is xterm initially only supported specific
// capabilities and none had parameters so it returned the tcap encoded form.
// Later, Kitty added support for more capabilities some of which have
// parameters. But Kitty returned them in terminfo source format. So we need to
// handle both cases.
fn decode_capability_string(value string) string {
	if value.contains('%') {
		return value
	}

	// No-parameters. Encode and return. First replace \E with the escape char
	// (0x1B).
	mut result := value.replace('\\E', '\x1b')

	// Replace '^' with the control char version of that char.
	for {
		idx := result.index_u8(`^`)
		if idx < 0 {
			break
		}
		if idx > 0 {
			panic('handle control-char in middle of string')
		}
		replacement := if result[idx + 1] == `?` {
			// DEL, special cased from ncurses
			u8(0x7f)
		} else {
			result[idx + 1] - 64
		}
		result = result.replace(result[idx..idx + 2], replacement.ascii_str())
	}

	return result
}

// hexencode returns the upper-case hex encoding of a string.
fn hexencode(input string) string {
	mut out := []u8{cap: input.len * 2}
	for b in input.bytes() {
		out << hex_digits[b >> 4]
		out << hex_digits[b & 0x0f]
	}
	return out.bytestr()
}

const hex_digits = '0123456789ABCDEF'.bytes()
