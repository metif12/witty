module osc

import encoding.utf8.validate

// Specialized encodings used in some OSC protocols.

// Kitty defines "Escape code safe UTF-8" as valid UTF-8 with the
// additional requirement of not containing any C0 escape codes
// (0x00-0x1f), DEL (0x7f) and C1 escape codes (0x80-0x9f).
//
// Used by OSC 66 (text sizing) and OSC 99 (Kitty notifications).
//
// See: https://sw.kovidgoyal.net/kitty/desktop-notifications/#safe-utf8
pub fn is_safe_utf8(s string) bool {
	// First check that the whole string is valid UTF-8. Ghostty relies on
	// Utf8View.init failing for invalid input; V's `runes()` instead
	// substitutes U+FFFD for invalid bytes, which would let lone
	// continuation bytes (e.g. 0x9f) slip through. So validate explicitly.
	if !validate.utf8_string(s) {
		return false
	}

	for c in s.runes() {
		cp := u32(c)
		if cp <= 0x1f || cp == 0x7f || (cp >= 0x80 && cp <= 0x9f) {
			return false
		}
	}
	return true
}
