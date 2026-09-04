module x11rgb

// The canonical X.Org rgb.txt data shipped by Ghostty. This module is kept
// dependency-neutral so both the terminal and OSC modules can use the same
// table without introducing a module cycle.
const rgb_data = $embed_file('@VMODROOT/terminal/res/rgb.txt').to_string()

pub struct RGB {
pub:
	r u8
	g u8
	b u8
}

pub struct Entry {
pub:
	name string
	rgb  RGB
}

pub fn entries() []Entry {
	mut result := []Entry{}
	for line in rgb_data.split_into_lines() {
		if line.len < 13 {
			continue
		}
		name := line[12..].trim_space()
		if name.len == 0 {
			continue
		}
		result << Entry{
			name: name
			rgb: RGB{
				r: u8(line[0..3].trim_space().int())
				g: u8(line[4..7].trim_space().int())
				b: u8(line[8..11].trim_space().int())
			}
		}
	}
	return result
}

// get performs the ASCII-insensitive lookup used by Ghostty's static map.
pub fn get(name string) ?RGB {
	if name.len == 0 {
		return none
	}
	wanted := name.to_lower()
	for entry in entries() {
		if entry.name.to_lower() == wanted {
			return entry.rgb
		}
	}
	return none
}
