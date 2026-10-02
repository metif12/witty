module osc

import lib_allocator

// Parse OSC 21 - Kitty color protocol.
// https://sw.kovidgoyal.net/kitty/color-stack/#id1
//
// The Kitty color protocol allows querying, setting, and resetting colors
// using a semicolon-separated list of key=value pairs.
//
// Keys can be:
// - Named special colors (foreground, background, cursor, etc.)
// - Palette indices (0-255)
//
// Values can be:
// - "?" to query the current color
// - A color specification (rgb:, rgbi:, #, or named color) to set
// - Empty or missing to reset

// KittyColorSpecial represents the named special colors in the kitty protocol.
pub enum KittyColorSpecial as u8 {
	foreground
	background
	selection_foreground
	selection_background
	cursor
	cursor_text
	visual_bell
	second_transparent_background
}

// KittyColorKind is either a palette index or a named special color.
pub type KittyColorKind = KittyColorSpecial | u8

// str formats the key as it appears in the protocol.
pub fn (self KittyColorKind) str() string {
	return match self {
		u8 { u8(self).str() }
		KittyColorSpecial { KittyColorSpecial(self).str() }
	}
}

// kitty_color_kind_max is the maximum number of distinct keys addressable in a
// single OSC 21. This mirrors ghostty's `kitty.color.Kind.max`, which is
// maxInt(u8) + number of special color names = 255 + 8 = 263.
const kitty_color_kind_max = 255 + 8

// parse_kitty_color_kind parses a key string into a KittyColorKind.
fn parse_kitty_color_kind(k string) ?KittyColorKind {
	// Try as a special color name
	special := match k {
		'foreground' { KittyColorSpecial.foreground }
		'background' { KittyColorSpecial.background }
		'selection_foreground' { KittyColorSpecial.selection_foreground }
		'selection_background' { KittyColorSpecial.selection_background }
		'cursor' { KittyColorSpecial.cursor }
		'cursor_text' { KittyColorSpecial.cursor_text }
		'visual_bell' { KittyColorSpecial.visual_bell }
		'second_transparent_background' { KittyColorSpecial.second_transparent_background }
		else {
			return KittyColorKind(u8(parse_unsigned_decimal(k, 255) or { return none }))
		}
	}
	return KittyColorKind(special)
}

// Query the current value of a color.
pub struct KittyColorQuery {
pub:
	key KittyColorKind
}

// Set a color.
pub struct KittyColorSet {
pub:
	key   KittyColorKind
	color RGB
}

// Reset a color to its default.
pub struct KittyColorReset {
pub:
	key KittyColorKind
}

// A single OSC 21 request.
pub type KittyColorRequest = KittyColorQuery | KittyColorReset | KittyColorSet

// KittyColorOSC represents a parsed OSC 21 command.
pub struct KittyColorOSC {
pub mut:
	// list of requests
	list []KittyColorRequest
	allocated lib_allocator.ArrayList[KittyColorRequest]
	// We must reply with the same string terminator (ST) as used in the
	// request.
	terminator Terminator = .st
}

// parse_kitty_color_protocol parses an OSC 21 kitty color protocol command.
fn parse_kitty_color_protocol(mut parser Parser, terminator_ch ?u8) ?Command {
	assert parser.state == .s_21
	if !parser.has_allocator || parser.writer == .none {
		parser.state = .invalid
		return none
	}
	mut request := KittyColorOSC{
		terminator: Terminator.init(terminator_ch)
	}
	defer { parser.command = request }
	data := parser.buffered().bytestr()
	for kv in data.split(';') {
		if request.list.len >= kitty_color_kind_max * 2 {
			// exceeded limit for number of keys in kitty color protocol, ignoring
			parser.state = .invalid
			return none
		}
		eq := kv.index_u8(`=`)
		k := if eq >= 0 { kv[..eq] } else { kv }
		if k.len == 0 {
			// zero length key in kitty color protocol
			continue
		}
		key := parse_kitty_color_kind(k) or {
			// unknown key in kitty color protocol
			continue
		}
		value := if eq >= 0 { kv[eq + 1..].trim(' ') } else { '' }
		if value.len == 0 {
			request.allocated.append(parser.allocator, KittyColorRequest(KittyColorReset{
				key: key
			})) or { continue }
		} else if value == '?' {
			request.allocated.append(parser.allocator, KittyColorRequest(KittyColorQuery{
				key: key
			})) or { continue }
		} else {
			request.allocated.append(parser.allocator, KittyColorRequest(KittyColorSet{
				key:   key
				color: parse_rgb(value) or {
					// invalid color format in kitty color protocol
					continue
				}
			})) or { continue }
		}
		request.list = request.allocated.items
	}
	parser.command = request
	return parser.command
}
