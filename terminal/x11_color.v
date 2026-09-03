module terminal

// X11 color-name lookup translated from terminal/x11_color.zig.
//
// Ghostty builds a case-insensitive static map from this X.Org rgb.txt at
// compile time. V cannot construct a map with a compile-time parser, so this
// translation scans the same embedded data. Color lookup is configuration-path
// work, not render-path work, and retaining the canonical data avoids a large,
// hand-maintained duplicate table.

const x11_rgb_data = $embed_file('res/rgb.txt').to_string()

// x11_color_get looks up an X11 color name using ASCII-insensitive matching.
pub fn x11_color_get(name string) ?RGB {
	if name.len == 0 {
		return none
	}
	wanted := name.to_lower()
	for line in x11_rgb_data.split_into_lines() {
		// rgb.txt has three fixed-width decimal components followed by a name.
		if line.len < 13 {
			continue
		}
		candidate := line[12..].trim_space()
		if candidate.to_lower() != wanted {
			continue
		}
		return RGB{
			r: u8(line[0..3].trim_space().int())
			g: u8(line[4..7].trim_space().int())
			b: u8(line[8..11].trim_space().int())
		}
	}
	return none
}
