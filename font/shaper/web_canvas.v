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
	return font.RunIterator.new(unsafe { &self })
}

// Shape the given text run. The text run must be the immediately
// previous text run that was iterated since the text run does share
// state with the WebCanvasShaper struct.
//
// The return value is only valid until the next shape call is called.
//
// If there is not enough space in the cell buffer, an error is
// returned.
pub fn (mut self WebCanvasShaper) shape(run font.TextRun) ![]font.ShapeCell {
	// XTODO: The full implementation requires:
	// - Grapheme break detection using unicode tables
	// - UTF-8 encoding of multi-codepoint grapheme clusters
	// - Browser Canvas font face interaction (graphemeGlyphIndex)
	// - Wasm allocator for temporary buffers
	//
	// The algorithm:
	// 1. If 0 codepoints: return empty
	// 2. If 1 codepoint: return it directly as a single cell
	// 3. For 2+ codepoints: perform grapheme clustering
	//    a. Walk codepoints checking for grapheme breaks
	//    b. Single-codepoint clusters: use codepoint as glyph index directly
	//    c. Multi-codepoint clusters: UTF-8 encode the cluster,
	//       ask the font face for a grapheme glyph index
	//
	// Note that due to limitations of canvas, we can NOT support
	// font ligatures. However, we do support grapheme clustering.
	// This means we can render things like skin tone emoji but
	// we can't render things like single glyph "=>".

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

	// XTODO: For 2+ codepoints we need grapheme clustering.
	// We know we have at least two codepoints, so we now go through
	// each and perform grapheme clustering.
	//
	// var break_state = grapheme.BreakState.default
	// var cp1 = u21(codepoints[0])
	// var start = 0
	// var i = 1
	// var cur = 0
	// while i <= codepoints.len : i += 1 {
	//     // We loop to codepoints.len so that we can handle the end
	//     // case. In the end case, we always assume it is a grapheme
	//     // break. This isn't strictly true but its how terminals
	//     // work today.
	//     grapheme_break := i == codepoints.len || unicode.grapheme_break(cp1, cp2, &break_state)
	//     if !grapheme_break { continue }
	//     // ... render prior grapheme ...
	// }

	// Stub: pass codepoints through as individual glyphs.
	self.cell_buf.clear()
	for cp in codepoints {
		self.cell_buf << font.ShapeCell{
			x: cp.cluster
			glyph_index: cp.codepoint
		}
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

// The wasm-compatible API.
// XTODO: The Wasm struct provides exported functions for JavaScript interop:
// - shaper_new(cap) -> creates a new WebCanvasShaper
// - shaper_free(ptr) -> destroys a WebCanvasShaper
// - shaper_test(self, group, str, len) -> runs a shaping test
//
// These require:
// - os.wasm allocator
// - terminal.Terminal for creating test terminal
// - font.GroupCache for font resolution
// - std.unicode.Utf8View for iterating over UTF-8 strings
