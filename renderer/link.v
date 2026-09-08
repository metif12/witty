module renderer

import input
import oniguruma
import terminal

// The link configuration needed for renderers.
pub struct Link {
pub mut:
	// The regular expression pattern to match the link against.
	regex oniguruma.Regex
	// The situations in which the link should be highlighted.
	highlight input.LinkHighlight
	mods      input.Mods
}

pub fn (mut self Link) deinit() {
	self.regex.deinit()
}

// A set of links. This provides a higher level API for renderers
// to match against a viewport and determine if cells are part of
// a link.
pub struct LinkSet {
pub mut:
	links []Link
}

// Returns the slice of links from the configuration.
pub fn LinkSet.from_config(config []input.Link) !LinkSet {
	mut links := []Link{}
	for link in config {
		regex := link.oni_regex() or {
			for mut compiled in links {
				compiled.deinit()
			}
			return err
		}
		links << Link{
			regex: regex
			highlight: link.highlight
			mods: link.mods
		}
	}
	return LinkSet{
		links: links
	}
}

pub fn (mut self LinkSet) deinit() {
	for mut link in self.links {
		link.deinit()
	}
	self.links = []
}

// Fills matches with the matches from regex link matches.
//
// The algorithm:
// 1. Convert render state to string + byte map
// 2. For each link, check highlight conditions (always, hover, mods)
// 3. Run regex.search() on the string
// 4. For hover links, check if mouse is over the match
// 5. Record matching cells in the result CellSet
pub fn (mut self LinkSet) render_cell_map(mut result terminal.CellSet, render_state &terminal.RenderState, mouse_viewport ?terminal.Coordinate, mouse_mods input.Mods) ! {
	// Fast path, not very likely since we have default links.
	if self.links.len == 0 {
		return
	}

	str, map_points := render_state.to_mapped_string()
	for mut link in self.links {
		match link.highlight {
			.always {}
			.always_mods {
				if !mouse_mods.equal(link.mods) {
					continue
				}
			}
			.hover {
				if mouse_viewport == none {
					continue
				}
			}
			.hover_mods {
				if mouse_viewport == none || !mouse_mods.equal(link.mods) {
					continue
				}
			}
		}

		mut offset := 0
		for offset < str.len {
			mut region := link.regex.search(str[offset..], oniguruma.Options{}) or {
				if err.msg() == oniguruma.mismatch_error {
					break
				}
				return err
			}
			starts := region.starts()
			ends := region.ends()
			start := offset + starts[0]
			end := offset + ends[0]
			offset = end
			mut record := true
			match link.highlight {
				.hover, .hover_mods {
					mouse := mouse_viewport or {
						record = false
						terminal.Coordinate{}
					}
					mut contains_mouse := false
					for point in map_points[start..end] {
						if point.x == mouse.x && point.y == mouse.y {
							contains_mouse = true
							break
						}
					}
					if !contains_mouse {
						record = false
					}
				}
				.always, .always_mods {}
			}
			if record {
				for point in map_points[start..end] {
					result[u64(point.y) << 32 | u64(point.x)] = true
				}
			}
			region.deinit()
		}
	}
}
