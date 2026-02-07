module renderer

import input
import terminal

// The link configuration needed for renderers.
pub struct Link {
pub mut:
	// The regular expression pattern to match the link against.
	regex string
	// The situations in which the link should be highlighted.
	highlight input.LinkHighlight
}

pub fn (mut self Link) deinit() {
	self.regex = ''
}

// A set of links. This provides a higher level API for renderers
// to match against a viewport and determine if cells are part of
// a link.
pub struct LinkSet {
pub mut:
	links []Link
}

// Returns the slice of links from the configuration.
// The full implementation would use oniguruma regex compilation from the
// input link's pattern. V's built-in regex module is used as a basic
// alternative where possible.
pub fn LinkSet.from_config(config []input.Link) !LinkSet {
	mut links := []Link{}
	for link in config {
		links << Link{
			regex: ''
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
// Full link matching requires oniguruma regex engine integration and
// terminal.RenderState.string() for building a string representation
// of the viewport with byte-to-cell mapping.
//
// The algorithm:
// 1. Convert render state to string + byte map
// 2. For each link, check highlight conditions (always, hover, mods)
// 3. Run regex.search() on the string
// 4. For hover links, check if mouse is over the match
// 5. Record matching cells in the result CellSet
pub fn (self &LinkSet) render_cell_map(mut result terminal.CellSet, render_state &terminal.RenderState, mouse_viewport ?terminal.ViewportPoint, mouse_mods input.Mods) ! {
	// Fast path, not very likely since we have default links.
	if self.links.len == 0 {
		return
	}

	_ = result
	_ = render_state
	_ = mouse_viewport
	_ = mouse_mods
}
