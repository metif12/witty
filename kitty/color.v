module kitty

import strconv

// Kitty color protocol types.
//
// Source: kitty/color.zig
//
// The Kitty color protocol allows terminal applications to query, set,
// and reset foreground, background, selection, cursor, and palette
// colors using OSC sequences.

// ============================================================
// Special - special color kinds beyond palette indices
// ============================================================

pub enum Special {
	foreground
	background
	selection_foreground
	selection_background
	cursor
	cursor_text
	visual_bell
	second_transparent_background
}

// ============================================================
// Kind - identifies a color by palette index or special name
// ============================================================

// Kind represents a color that can be addressed by the Kitty color
// protocol. It is either a palette index (0-255) or a special named
// color (foreground, background, etc.).
pub type Kind = KindPalette | KindSpecial

pub struct KindPalette {
pub:
	index u8
}

pub struct KindSpecial {
pub:
	special Special
}

// The maximum number of addressable colors: 256 palette + special names.
pub const kind_max = 255 + 8 // maxInt(u8) + Special enum count

// Parse a string into a Kind. Returns none if the string cannot be
// parsed as either a special name or a palette index.
pub fn Kind.parse(key string) ?Kind {
	// Try to match as a special name first.
	if key == 'foreground' {
		return Kind(KindSpecial{ special: .foreground })
	}
	if key == 'background' {
		return Kind(KindSpecial{ special: .background })
	}
	if key == 'selection_foreground' {
		return Kind(KindSpecial{ special: .selection_foreground })
	}
	if key == 'selection_background' {
		return Kind(KindSpecial{ special: .selection_background })
	}
	if key == 'cursor' {
		return Kind(KindSpecial{ special: .cursor })
	}
	if key == 'cursor_text' {
		return Kind(KindSpecial{ special: .cursor_text })
	}
	if key == 'visual_bell' {
		return Kind(KindSpecial{ special: .visual_bell })
	}
	if key == 'second_transparent_background' {
		return Kind(KindSpecial{ special: .second_transparent_background })
	}

	// Try to parse as a palette index.
	index := strconv.parse_uint(key, 10, 8) or { return none }
	return Kind(KindPalette{ index: u8(index) })
}

// Format the kind as a string suitable for the protocol.
pub fn (self Kind) str() string {
	return match self {
		KindPalette {
			'${self.index}'
		}
		KindSpecial {
			match self.special {
				.foreground { 'foreground' }
				.background { 'background' }
				.selection_foreground { 'selection_foreground' }
				.selection_background { 'selection_background' }
				.cursor { 'cursor' }
				.cursor_text { 'cursor_text' }
				.visual_bell { 'visual_bell' }
				.second_transparent_background { 'second_transparent_background' }
			}
		}
	}
}

// ============================================================
// RGB - simple RGB color for set requests
// ============================================================

pub struct RGB {
pub:
	r u8
	g u8
	b u8
}

// ============================================================
// OSC - Kitty color protocol OSC request
// ============================================================

// Represents a single request within a Kitty color protocol OSC sequence.
pub type ColorRequest = ColorQuery | ColorSet | ColorReset

pub struct ColorQuery {
pub:
	kind Kind
}

pub struct ColorSet {
pub:
	kind  Kind
	color RGB
}

pub struct ColorReset {
pub:
	kind Kind
}

// Terminator represents the string terminator used in the original
// OSC sequence. We must reply with the same terminator.
pub enum Terminator {
	st // ESC backslash (\x1b\\)
	bel // BEL character (\x07)
}

// OSC holds a list of color protocol requests parsed from a single
// OSC sequence, along with the terminator that was used.
pub struct ColorOSC {
pub mut:
	// List of requests in this OSC sequence.
	list []ColorRequest

	// We must reply with the same string terminator (ST) as used in the
	// request.
	terminator Terminator = .st
}

// Free the request list.
pub fn (mut self ColorOSC) deinit() {
	self.list = []
}
