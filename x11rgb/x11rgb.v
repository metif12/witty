module x11rgb

import ascii
import cli_args

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
		if line.len == 0 {
			continue
		}
		r := cli_args.parse_unsigned_int_base(line[0..3].trim(' '), 8, 10) or {
			panic(err)
		}
		g := cli_args.parse_unsigned_int_base(line[4..7].trim(' '), 8, 10) or {
			panic(err)
		}
		b := cli_args.parse_unsigned_int_base(line[8..11].trim(' '), 8, 10) or {
			panic(err)
		}
		result << Entry{
			name: line[12..].trim(' \t\n')
			rgb: RGB{
				r: u8(r)
				g: u8(g)
				b: u8(b)
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
	for entry in entries() {
		if ascii.eql_ignore_case(entry.name, name) {
			return entry.rgb
		}
	}
	return none
}
