module renderer

import input
import oniguruma
import strings
import terminal

// The link configuration needed for renderers.
pub struct Link {
pub mut:
	// The regular expression pattern to match the link against.
	regex oniguruma.Regex
	// The situations in which the link should be highlighted.
	highlight input.LinkHighlight
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

	mut builder := strings.new_builder(int(render_state.rows) * int(render_state.cols))
	mut string_map := terminal.RenderStringMap{}
	render_state.string(mut builder, terminal.RenderStringOptions{
		map: &string_map
	})
	str := builder.str()
	for mut link in self.links {
		match link.highlight {
			input.LinkHighlightAlways {}
			input.LinkHighlightAlwaysMods {
				if !mouse_mods.equal(link.highlight.mods) {
					continue
				}
			}
			input.LinkHighlightHover {
				if mouse_viewport == none {
					continue
				}
			}
			input.LinkHighlightHoverMods {
				if mouse_viewport == none || !mouse_mods.equal(link.highlight.mods) {
					continue
				}
			}
		}

		mut offset := 0
		for offset < str.len {
			mut region := link.regex.search(str[offset..], oniguruma.Options{}) or {
				if oniguruma.is_error(err, .mismatch) {
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
				input.LinkHighlightHover, input.LinkHighlightHoverMods {
					mouse := mouse_viewport or {
						record = false
						terminal.Coordinate{}
					}
					mut contains_mouse := false
					for point in string_map.points[start..end] {
						if point.x == mouse.x && point.y == mouse.y {
							contains_mouse = true
							break
						}
					}
					if !contains_mouse {
						record = false
					}
				}
				input.LinkHighlightAlways, input.LinkHighlightAlwaysMods {}
			}
			if record {
				for point in string_map.points[start..end] {
					result[u64(point.y) << 32 | u64(point.x)] = true
				}
			}
			region.deinit()
		}
	}
}
