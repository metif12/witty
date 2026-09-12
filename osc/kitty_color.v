module osc

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

// KittyColorKindType represents whether a kitty color key is a special
// color name or a palette index.
pub enum KittyColorKindType as u8 {
	palette
	special
}

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

// KittyColorKind represents either a special color name or a palette index.
pub struct KittyColorKind {
pub:
	kind    KittyColorKindType
	special KittyColorSpecial
	palette u8
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
			idx := u8(parse_unsigned_decimal(k, 255) or { return none })
			return KittyColorKind{
				kind: .palette
				palette: idx
			}
		}
	}
	return KittyColorKind{
		kind: .special
		special: special
	}
}

// KittyColorItemType represents the operation type for a kitty color item.
pub enum KittyColorItemType as u8 {
	query
	set
	reset
}

// KittyColorItem represents a single operation in the kitty color protocol.
pub struct KittyColorItem {
pub:
	item_type KittyColorItemType
	key       KittyColorKind
	color     RGB // only used for set operations
}

// KittyColorOSC represents a parsed OSC 21 command.
pub struct KittyColorOSC {
pub mut:
	items      []KittyColorItem
	terminator Terminator = .st
}

// parse_kitty_color_protocol parses an OSC 21 kitty color protocol command.
fn parse_kitty_color_protocol(mut parser Parser, terminator_ch ?u8) ?Command {
	assert parser.state == .s_21
	if !parser.has_allocator || parser.writer == .none {
		parser.state = .invalid
		return none
	}
	data := parser.buffered()
	data_str := data.bytestr()

	mut items := []KittyColorItem{}

	// Split on semicolons
	kvs := data_str.split(';')
	for kv in kvs {
		if items.len >= kitty_color_kind_max * 2 {
			parser.state = .invalid
			return none
		}

		// Split on '='
		eq := kv.index_u8(`=`)
		mut k := ''
		mut value := ''
		if eq >= 0 {
			k = kv[..eq]
			value = kv[eq + 1..].trim(' ')
		} else {
			k = kv
			value = ''
		}

		if k.len == 0 {
			continue
		}

		key := parse_kitty_color_kind(k) or { continue }

		if value.len == 0 {
			// Reset
			items << KittyColorItem{
				item_type: .reset
				key: key
			}
		} else if value == '?' {
			// Query
			items << KittyColorItem{
				item_type: .query
				key: key
			}
		} else {
			// Set
			rgb := parse_rgb(value) or { continue }
			items << KittyColorItem{
				item_type: .set
				key: key
				color: rgb
			}
		}
	}

	parser.command = Command{
		cmd_type: .kitty_color_protocol
		terminator: Terminator.init(terminator_ch)
		str_value: data_str
		kitty_color_items: items
	}
	return parser.command
}
