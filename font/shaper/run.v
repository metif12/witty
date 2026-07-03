module shaper

import font
import hash

// run.v contains the TextRun and RunIterator types for iterating over
// text runs in a terminal row.
//
// Note: The TextRun struct is defined in font/font.v (as font.TextRun)
// so that it can be shared across all shaper backends. This file contains
// the RunIterator and associated logic.

// RunIterator is an iterator that yields text runs.
// It iterates over a row of terminal cells, grouping consecutive cells
// that share the same font into a single text run.
pub struct RunIterator2 {
pub mut:
	// The shaper-specific hooks for building up run state.
	// This is an opaque pointer to the shaper's RunIteratorHook.
	hooks voidptr = unsafe { nil }
	// The options controlling iteration (grid, cells, selection, cursor).
	opts font.RunOptions
	// Current position in the row.
	i int
}

// next returns the next text run, or none if iteration is complete.
//
// The main loop body that processes terminal cells, detects font changes,
// handles selections, cursors, style breaks, grapheme clustering,
// and presentation format detection is complex and deeply integrated
// with terminal internals.
pub fn (mut self RunIterator2) next() ?font.TextRun {
	// This is a simplified translation of ghostty's run.zig RunIterator.next.
	// The full ghostty version reads terminal.page.Cell values (codepoints,
	// graphemes, wide flags), compares terminal.Style values to split runs,
	// and resolves per-codepoint font indices through a font.SharedGrid.
	//
	// In witty this iterator currently operates over a plain []u8 slice of
	// codepoints (one byte == one cell) with a single fallback font
	// (font_index == 0). We still preserve the essential control flow so the
	// grouping, trimming, and hashing semantics match ghostty:
	//
	// 1. Trim the right side of a row that might be empty.
	// 2. Skip invisible cells (none in the byte model).
	// 3. Accumulate cells into a run, breaking when the font index changes.
	// 4. Hash each codepoint together with its relative cluster position so
	//    the resulting hash is position-independent within the row.
	// 5. Add the run length and font index to the hash to reduce collisions.

	cells := self.opts.cells

	// Trim the right side of a row that might be empty. A zero byte is
	// treated as an empty cell (mirrors cell.isEmpty()).
	mut max := 0
	for i in 0 .. cells.len {
		rev_i := cells.len - i - 1
		if cells[rev_i] != 0 {
			max = rev_i + 1
			break
		}
	}

	// Invisible cells don't render any glyphs, so we skip them. The byte
	// model has no styling, so this is currently a no-op, but we keep the
	// loop to mirror ghostty's structure.
	for self.i < max && is_invisible(cells[self.i]) {
		self.i++
	}

	// We're over at the max.
	if self.i >= max {
		return none
	}

	// Track the font for our current run. In the byte model every cell
	// resolves to the fallback font (index 0).
	current_font := u32(0)

	// Initialize the hasher for this run.
	mut hasher := RunHasher{}

	// Go through cell by cell and accumulate while we build our run.
	mut j := self.i
	for j < max {
		// Use relative cluster positions (offset from run start) to make
		// the shaping cache position-independent. This ensures that runs
		// with identical content but different starting positions in the
		// row produce the same hash, enabling cache reuse.
		cluster := u32(j - self.i)
		cp := u32(cells[j])

		// Determine the font index for this cell. All bytes resolve to the
		// fallback font, so the run never breaks on a font change here, but
		// we keep the comparison to remain faithful to ghostty.
		font_idx := index_for_byte(cp)

		// If our fonts are not equal, then we're done with our run.
		if font_idx != current_font {
			break
		}

		// Add the codepoint (using a space for a null codepoint, matching
		// ghostty) to the hasher and hooks.
		self.add_codepoint(mut hasher, if cp == 0 { u32(` `) } else { cp }, cluster)

		j++
	}

	// Add our length to the hash as an additional mechanism to avoid
	// collisions, then add our font index.
	hasher.add_u64(u64(j - self.i))
	hasher.add_u64(u64(current_font))

	// Compute the offset before advancing the cursor.
	offset := u32(self.i)
	run_cells := u32(j - self.i)

	// Move our cursor.
	self.i = j

	return font.TextRun{
		hash:       hasher.final()
		offset:     offset
		cells:      run_cells
		font_index: current_font
	}
}

// is_invisible reports whether a byte cell should be skipped because it
// renders no glyph. The byte model has no styling flags, so no cell is
// invisible, but this mirrors ghostty's styles[i].flags.invisible check.
fn is_invisible(_ u8) bool {
	return false
}

// index_for_byte resolves a codepoint to a font index. In the byte model
// every codepoint resolves to the single fallback font (index 0).
fn index_for_byte(_ u32) u32 {
	return 0
}

// RunHasher is a small deterministic hasher used to build the run hash.
// It mirrors ghostty's use of std.hash.Wyhash: values are appended in order
// and combined into a single u64 seed. We accumulate into a byte buffer and
// fold it through hash.sum64 so identical content produces identical hashes.
struct RunHasher {
mut:
	seed u64
}

// add_u64 folds a 64-bit value into the running hash.
fn (mut h RunHasher) add_u64(v u64) {
	mut buf := [8]u8{}
	for i in 0 .. 8 {
		buf[i] = u8((v >> (u64(i) * 8)) & 0xff)
	}
	h.seed = hash.sum64(buf[..], h.seed)
}

// final returns the accumulated hash value. We fold a non-zero salt so that
// even an all-zero sequence of inputs produces a non-zero hash.
fn (mut h RunHasher) final() u64 {
	return hash.sum64_string('witty.shaper.run', h.seed) ^ 0x9e3779b97f4a7c15
}

// add_codepoint adds a codepoint with its cluster to the hasher and hooks.
fn (mut self RunIterator2) add_codepoint(mut hasher RunHasher, cp u32, cluster u32) {
	// Hash the codepoint and cluster for cache key generation.
	hasher.add_u64(u64(cp))
	hasher.add_u64(u64(cluster))

	// The full ghostty version also forwards the codepoint to the shaper's
	// RunIteratorHook (hooks.addCodepoint) so the backend can build its
	// shaping buffer. In the byte model there is no attached hook yet.
}

// index_for_cell finds a font index that supports the grapheme for the
// given cell, or none if no such font exists.
//
// This is used to find a font that supports the entire grapheme.
// We look for fonts that support each individual codepoint and then
// find the common font amongst all candidates.
//
// XTODO: Requires terminal.page.Cell, font.Collection.Index, font.SharedGrid
// fn (mut self RunIterator2) index_for_cell(
//     cell voidptr,       // *terminal.page.Cell
//     graphemes []u32,    // []u21 in Zig
//     style font.FontStyle,
//     presentation ?font.Presentation,
// ) ?u32 {
//     // If cell is empty or codepoint is 0 or kitty placeholder,
//     // return index for space.
//     //
//     // Get the font index for the primary codepoint.
//     // Easy, and common: we aren't a multi-codepoint grapheme, so
//     // we just return whatever index for the cell codepoint.
//     //
//     // If this is a grapheme, we need to find a font that supports
//     // all of the codepoints in the grapheme.
//     // - Build candidate list from each codepoint
//     // - Ignore Emoji ZWJs (0xFE0E, 0xFE0F, 0x200D)
//     // - Find candidate that has ALL codepoints
//     return none
// }

// Returns a style that when compared must be identical for a run to
// continue.
// XTODO: Requires terminal.Style type.
// fn comparable_style(style terminal.Style) terminal.Style {
//     mut s := style
//     // We allow background colors to differ because we'll just paint the
//     // cell background whatever the style is, and wherever the glyph
//     // lands on top of it will be the color of the glyph.
//     s.bg_color = .none_
//     return s
// }
