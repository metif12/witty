module osc

// Specialized encodings used in some OSC protocols.

// Kitty defines "Escape code safe UTF-8" as valid UTF-8 with the
// additional requirement of not containing any C0 escape codes
// (0x00-0x1f), DEL (0x7f) and C1 escape codes (0x80-0x9f).
//
// Used by OSC 66 (text sizing) and OSC 99 (Kitty notifications).
//
// See: https://sw.kovidgoyal.net/kitty/desktop-notifications/#safe-utf8
pub fn is_safe_utf8(s string) bool {
	// First check that it's valid UTF-8 by trying to iterate
	for c in s.runes() {
		cp := u32(c)
		if cp <= 0x1f || cp == 0x7f || (cp >= 0x80 && cp <= 0x9f) {
			return false
		}
	}
	return true
}
