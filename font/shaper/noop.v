module shaper

import font

// Shaper that doesn't do any shaping. Each individual codepoint is mapped
// directly to the detected text run font's glyph index.
pub struct NoopShaper {
pub mut:
	// The string used for shaping the current run.
	run_state NoopRunState
	// The shared memory used for shaping results.
	cell_buf []font.ShapeCell
}

// NoopCodepoint associates a Unicode codepoint with a cluster (cell) index.
struct NoopCodepoint {
pub:
	codepoint u32
	cluster   u32
}

// NoopRunState holds the codepoints accumulated during run iteration.
struct NoopRunState {
pub mut:
	codepoints []NoopCodepoint
}

fn (mut self NoopRunState) deinit() {
	self.codepoints = []
}

fn (mut self NoopRunState) reset() {
	self.codepoints.clear()
}

// The cell_buf argument is the buffer to use for storing shaped results.
// This should be at least the number of columns in the terminal.
pub fn NoopShaper.init(opts font.ShaperOptions) !NoopShaper {
	_ = opts
	return NoopShaper{
		cell_buf: []font.ShapeCell{}
		run_state: NoopRunState{}
	}
}

pub fn (mut self NoopShaper) deinit() {
	self.cell_buf = []
	self.run_state.deinit()
}

pub fn (self &NoopShaper) end_frame() {
	// nothing to do
}

pub fn (mut self NoopShaper) run_iterator(opts font.RunOptions) font.RunIterator {
	return font.RunIterator.new(unsafe { &self })
}

// shape shapes the given text run. The text run must be the immediately
// previous text run that was iterated since the text run does share
// state with the NoopShaper struct.
//
// The return value is only valid until the next shape call is called.
//
// If there is not enough space in the cell buffer, an error is returned.
pub fn (mut self NoopShaper) shape(run font.TextRun) ![]font.ShapeCell {
	state := &self.run_state

	// Special fonts aren't shaped and their codepoint == glyph so we
	// can just return the codepoints as-is.
	if run.font_index == font.sprite_index {
		self.cell_buf.clear()
		for entry in state.codepoints {
			self.cell_buf << font.ShapeCell{
				x: entry.cluster
				glyph_index: entry.codepoint
			}
		}
		return self.cell_buf
	}

	// Go through the run and map each codepoint to a glyph index.
	self.cell_buf.clear()

	// Note: this is digging into some internal details, we should maybe
	// expose a public API for this.
	// XTODO: Need real font face to look up glyph indices.
	// In the full implementation:
	//   face := run.grid.resolver.collection.get_face(run.font_index)
	//   for entry in state.codepoints {
	//       glyph_index := face.glyph_index(entry.codepoint) or {
	//           // The run iterator shared logic should guarantee that
	//           // there is a glyph index for all codepoints in the run.
	//           // This is not well tested because we don't use the noop
	//           // shaper in any release builds.
	//           unreachable
	//       }
	//       self.cell_buf << font.ShapeCell{
	//           x: entry.cluster
	//           glyph_index: glyph_index
	//       }
	//   }

	// Stub: use codepoint as glyph index directly (no real font lookup).
	for entry in state.codepoints {
		self.cell_buf << font.ShapeCell{
			x: entry.cluster
			glyph_index: entry.codepoint
		}
	}

	return self.cell_buf
}

// The hooks for RunIterator.
pub struct NoopRunIteratorHook {
pub mut:
	shaper &NoopShaper = unsafe { nil }
}

// prepare resets the run state before starting a new run.
pub fn (mut self NoopRunIteratorHook) prepare() {
	self.shaper.run_state.reset()
}

// add_codepoint adds a codepoint and its associated cluster to the current run.
pub fn (mut self NoopRunIteratorHook) add_codepoint(cp u32, cluster u32) ! {
	self.shaper.run_state.codepoints << NoopCodepoint{
		codepoint: cp
		cluster: cluster
	}
}

// finalize completes the run (no-op for this shaper).
pub fn (self NoopRunIteratorHook) finalize() {
	// nothing to do
}
