module osc

// Kitty's text sizing protocol (OSC 66)
// Specification: https://sw.kovidgoyal.net/kitty/text-sizing-protocol/

const kitty_text_sizing_max_payload = 4096

// KittyTextSizingVAlign represents vertical alignment for text sizing.
pub enum KittyTextSizingVAlign {
	top // 0
	bottom // 1
	center // 2
}

// KittyTextSizingHAlign represents horizontal alignment for text sizing.
pub enum KittyTextSizingHAlign {
	left // 0
	right // 1
	center // 2
}

// KittyTextSizing represents a parsed OSC 66 command.
pub struct KittyTextSizing {
pub mut:
	scale       u8 = 1 // 1 - 7
	width       u8 // 0 - 7 (0 means default)
	numerator   u8 // 0 - 15
	denominator u8 // 0 - 15
	valign      KittyTextSizingVAlign = .top
	halign      KittyTextSizingHAlign = .left
	text        string
}

// update sets a key-value pair on the KittyTextSizing.
fn (mut self KittyTextSizing) update(key u8, value string) bool {
	// All values are numeric, so we can do a small hack here
	v := parse_int_unsigned_decimal(value, 15) or { return false }

	match key {
		`s` {
			if v == 0 || v > 7 {
				return false
			}
			self.scale = u8(v)
		}
		`w` {
			if v > 7 {
				return false
			}
			self.width = u8(v)
		}
		`n` {
			if v > 15 {
				return false
			}
			self.numerator = u8(v)
		}
		`d` {
			if v > 15 {
				return false
			}
			self.denominator = u8(v)
		}
		`v` {
			match v {
				0 {
					self.valign = .top
				}
				1 {
					self.valign = .bottom
				}
				2 {
					self.valign = .center
				}
				else {
					return false
				}
			}
		}
		`h` {
			match v {
				0 {
					self.halign = .left
				}
				1 {
					self.halign = .right
				}
				2 {
					self.halign = .center
				}
				else {
					return false
				}
			}
		}
		else {
			return false
		}
	}
	return true
}

// parse_kitty_text_sizing parses an OSC 66 command.
fn parse_kitty_text_sizing(mut parser Parser, terminator_ch ?u8) ?Command {
	data := parser.finish_zero_terminated() or { return none }
	data_str := data.bytestr()

	// Find the semicolon separating params from payload
	payload_start := data_str.index_u8(`;`)
	if payload_start < 0 {
		parser.state = .invalid
		return none
	}

	payload := data_str[payload_start + 1..]

	// Payload has to be an escape-code-safe UTF-8 string,
	// and be under the size limit.
	if payload.len > kitty_text_sizing_max_payload {
		parser.state = .invalid
		return none
	}
	if !is_safe_utf8(payload) {
		parser.state = .invalid
		return none
	}

	mut result := KittyTextSizing{
		text: payload
	}

	// Parse any arguments if given
	if payload_start > 0 {
		params := data_str[..payload_start]
		kvs := params.split(':')
		for kv in kvs {
			parts := kv.split('=')
			if parts.len < 2 {
				continue
			}
			k := parts[0]
			if k.len != 1 {
				continue
			}
			v := parts[1]
			result.update(k[0], v)
		}
	}

	parser.command = Command{
		cmd_type: .kitty_text_sizing
		terminator: Terminator.init(terminator_ch)
		kitty_text_sizing: result
	}
	return parser.command
}
