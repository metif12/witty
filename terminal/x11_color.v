module terminal

import x11rgb

// X11 color-name lookup translated from terminal/x11_color.zig.
//
// Ghostty builds a case-insensitive static map from this X.Org rgb.txt at
// compile time. V cannot construct a map with a compile-time parser, so this
// translation scans the same embedded data. Color lookup is configuration-path
// work, not render-path work, and retaining the canonical data avoids a large,
// hand-maintained duplicate table.

pub struct NamedRGB {
pub:
	name string
	rgb  RGB
}

// x11_color_entries returns every entry in the embedded X.Org rgb.txt file.
// Ghostty exposes this complete table through `+list-colors`.
pub fn x11_color_entries() []NamedRGB {
	mut result := []NamedRGB{}
	for entry in x11rgb.entries() {
		result << NamedRGB{
			name: entry.name
			rgb: RGB{
				r: entry.rgb.r
				g: entry.rgb.g
				b: entry.rgb.b
			}
		}
	}
	return result
}

// x11_color_get looks up an X11 color name using ASCII-insensitive matching.
pub fn x11_color_get(name string) ?RGB {
	rgb := x11rgb.get(name) or { return none }
	return RGB{
		r: rgb.r
		g: rgb.g
		b: rgb.b
	}
}
