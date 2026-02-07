module shaper

import font

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
	// XTODO: The full implementation requires deep integration with:
	// - terminal.page.Cell for reading cell content (codepoints, graphemes, wide chars)
	// - terminal.Style for style comparison and run splitting
	// - font.Collection.Index for font lookups
	// - font.SharedGrid for resolving codepoints to font indices
	// - Unicode grapheme/presentation detection
	// - hash.Wyhash for computing run hashes
	//
	// The algorithm:
	// 1. Trim right side of row that might be empty
	// 2. Skip invisible cells
	// 3. For each cell:
	//    a. Break at selection boundaries
	//    b. Skip spacer_head and spacer_tail cells
	//    c. Break when cell style attributes change (except background color)
	//    d. Break on "bad ligatures" (fl, fi, st combinations)
	//    e. Break around cursor position
	//    f. Determine font style (regular/bold/italic/bold_italic)
	//    g. Determine presentation format (text/emoji) from VS15/VS16
	//    h. Find font index for the cell's codepoint(s)
	//    i. Break when font index changes
	//    j. Add codepoints to hasher and hook
	// 4. Finalize the run
	// 5. Return TextRun with hash, offset, cells, grid, font_index
	//
	// The original uses a Wyhash for hashing, adding:
	// - Each codepoint and its relative cluster position
	// - The run length
	// - The font index
	//
	// Use relative cluster positions (offset from run start) to make
	// the shaping cache position-independent. This ensures that runs
	// with identical content but different starting positions in the
	// row produce the same hash, enabling cache reuse.

	if self.i >= self.opts.cells.len {
		return none
	}

	// Stub: return none (no cells to iterate).
	return none
}

// add_codepoint adds a codepoint with its cluster to the hasher and hooks.
// XTODO: The hasher parameter needs to be hash.Wyhash once integrated.
// fn (mut self RunIterator2) add_codepoint(mut hasher hash.Wyhash, cp u32, cluster u32) ! {
//     // Hash the codepoint and cluster for cache key generation.
//     hasher.write(cp.bytes())
//     hasher.write(cluster.bytes())
//
//     // Call hooks.add_codepoint(cp, cluster)
//     // The hooks pointer needs to be cast to the correct RunIteratorHook type
//     // and the add_codepoint method called on it.
// }

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
