module shaper

import font

// Shaper that uses the browser Canvas API for text shaping.
//
// This shaper is designed for the web/wasm target where we can use the
// browser's built-in text rendering capabilities through the Canvas 2D API.
// Unlike HarfBuzz or CoreText, this doesn't support font ligatures, but it
// does support grapheme clustering. This means we can render things like
// skin tone emoji but we can't render things like single glyph "=>".
pub struct WebCanvasShaper {
pub mut:
	// The shared memory used for shaping results.
	cell_buf []font.ShapeCell
	// The shared memory used for storing information about a run.
	// In the Zig version this is a MultiArrayList of {codepoint, cluster}.
	run_codepoints []WebCanvasCodepoint
}

// WebCanvasCodepoint holds a codepoint and its cluster (cell X position).
struct WebCanvasCodepoint {
pub:
	// The codepoint for this cell. This must be used in conjunction
	// with cluster to find the total set of codepoints for a given
	// cell. See cluster for more information.
	codepoint u32
	// Cluster is set to the X value of the cell that this codepoint
	// is part of. Note that a cell can have multiple codepoints
	// with zero-width joiners (ZWJ) and such. Note that terminals
	// do NOT handle full extended grapheme clustering well so it
	// is possible a single grapheme extends multiple clusters.
	// For example, skin tone emoji thumbs up may show up as two
	// clusters: one with thumbs up and the ZWJ, and a second
	// cluster with the tone block. It is up to the shaper to handle
	// shaping these together into a single glyph, if it wishes.
	cluster u32
}

// The cell_buf argument is the buffer to use for storing shaped results.
// This should be at least the number of columns in the terminal.
pub fn WebCanvasShaper.init(opts font.ShaperOptions) !WebCanvasShaper {
	// Note: we do not support opts.features (font features are not
	// available through the Canvas API).
	_ = opts
	return WebCanvasShaper{
		cell_buf: []font.ShapeCell{}
		run_codepoints: []WebCanvasCodepoint{}
	}
}

pub fn (mut self WebCanvasShaper) deinit() {
	self.cell_buf = []
	self.run_codepoints = []
}

pub fn (self &WebCanvasShaper) end_frame() {
	// nothing to do
}

// Returns an iterator that returns one text run at a time for the
// given terminal row. Note that text runs are are only valid one at a time
// for a Shaper struct since they share state.
pub fn (mut self WebCanvasShaper) run_iterator(opts font.RunOptions) font.RunIterator {
	return font.RunIterator.new_with_hooks(unsafe { &self }, opts, font.RunIteratorHooks{
		prepare: web_canvas_run_prepare
		add: web_canvas_run_add
		finalize: web_canvas_run_finalize
	})
}

fn web_canvas_run_prepare(shaper_ptr voidptr) {
	mut shaper := unsafe { &WebCanvasShaper(shaper_ptr) }
	shaper.run_codepoints.clear()
}

fn web_canvas_run_add(shaper_ptr voidptr, cp u32, cluster u32) ! {
	mut shaper := unsafe { &WebCanvasShaper(shaper_ptr) }
	shaper.run_codepoints << WebCanvasCodepoint{
		codepoint: cp
		cluster: cluster
	}
}

fn web_canvas_run_finalize(_ voidptr) {}

// Shape the given text run. The text run must be the immediately
// previous text run that was iterated since the text run does share
// state with the WebCanvasShaper struct.
//
// The return value is only valid until the next shape call is called.
//
// If there is not enough space in the cell buffer, an error is
// returned.
pub fn (mut self WebCanvasShaper) shape(run font.TextRun) ![]font.ShapeCell {
	codepoints := self.run_codepoints

	if codepoints.len == 0 {
		// Special cases: if we have no codepoints (is this possible?)
		// then our result is also an empty cell run.
		return []font.ShapeCell{}
	}

	if codepoints.len == 1 {
		// If we have only 1 codepoint, then we assume that it is
		// a single grapheme and just let it through. At this point,
		// we can't have any more information to do anything else.
		self.cell_buf.clear()
		self.cell_buf << font.ShapeCell{
			x: codepoints[0].cluster
			glyph_index: codepoints[0].codepoint
		}
		return self.cell_buf
	}

	// V's string.graphemes() uses the Unicode grapheme-break property tables
	// and state machine, providing the same UAX #29 boundary decisions as
	// Ghostty's uucode.grapheme.BreakState.
	mut encoded := ''
	for entry in codepoints {
		if entry.codepoint > 0x10ffff || (entry.codepoint >= 0xd800 && entry.codepoint <= 0xdfff) {
			return error('invalid Unicode codepoint in WebCanvas run')
		}
		encoded += rune(entry.codepoint).str()
	}
	graphemes := encoded.graphemes()
	self.cell_buf.clear()
	mut start := 0
	for grapheme in graphemes {
		cluster_points := grapheme.runes()
		if cluster_points.len == 0 || start + cluster_points.len > codepoints.len {
			return error('invalid grapheme segmentation result')
		}
		glyph_index := if cluster_points.len == 1 {
			codepoints[start].codepoint
		} else {
			if run.web_canvas_face == unsafe { nil } {
				return error('WebCanvas run has no face for grapheme glyph allocation')
			}
			mut face := unsafe { run.web_canvas_face }
			face.grapheme_glyph_index(grapheme.bytes())!
		}
		self.cell_buf << font.ShapeCell{
			x: codepoints[start].cluster
			glyph_index: glyph_index
		}
		start += cluster_points.len
	}
	if start != codepoints.len {
		return error('WebCanvas grapheme segmentation did not consume the run')
	}
	return self.cell_buf
}

// The hooks for RunIterator.
pub struct WebCanvasRunIteratorHook {
pub mut:
	shaper &WebCanvasShaper = unsafe { nil }
}

// prepare resets the buffer for our current run.
pub fn (mut self WebCanvasRunIteratorHook) prepare() {
	// Reset the buffer for our current run
	self.shaper.run_codepoints.clear()
}

// add_codepoint adds a codepoint with its cluster to the current run.
pub fn (mut self WebCanvasRunIteratorHook) add_codepoint(cp u32, cluster u32) ! {
	self.shaper.run_codepoints << WebCanvasCodepoint{
		codepoint: cp
		cluster: cluster
	}
}

// finalize completes the run (no-op for this shaper).
pub fn (self WebCanvasRunIteratorHook) finalize() {
	// nothing to do
}

// shaper_new creates an owned shaper for browser hosts.
pub fn shaper_new(cap uint) ?&WebCanvasShaper {
	mut shaper := WebCanvasShaper.init(font.ShaperOptions{}) or { return none }
	shaper.cell_buf = []font.ShapeCell{cap: int(cap)}
	mut result := &WebCanvasShaper{}
	unsafe { *result = shaper }
	return result
}

// shaper_free releases a shaper returned by shaper_new.
pub fn shaper_free(shaper ?&WebCanvasShaper) {
	if mut value := shaper {
		value.deinit()
		unsafe { free(value) }
	}
}
