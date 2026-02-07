module shaper

import font
import harfbuzz

// Shaper that uses HarfBuzz.
//
// HarfBuzz is the most widely used text shaping engine. It supports
// all OpenType features and complex scripts. Unlike CoreText, it works
// cross-platform (Linux, macOS, Windows).
pub struct HbShaper {
pub mut:
	// The buffer used for text shaping. We reuse it across multiple shaping
	// calls to prevent allocations.
	hb_buf harfbuzz.Buffer
	// The shared memory used for shaping results.
	cell_buf []font.ShapeCell
	// The features to use for shaping.
	hb_feats []harfbuzz.Feature
	// The codepoints added to the buffer before shaping. We need to keep
	// these separately because after shaping, HarfBuzz replaces codepoints
	// with glyph indices in the buffer.
	codepoints []HbCodepoint
	// Reference to the font grid, set during run_iterator().
	grid &font.SharedGrid = unsafe { nil }
}

// HbCodepoint associates a Unicode codepoint with a cluster (cell) index.
pub struct HbCodepoint {
pub:
	cluster   u32
	codepoint u32
}

// HbRunOffset tracks the current x and y offsets (sum of advances)
// and the furthest cluster we've seen so far (max).
struct HbRunOffset {
mut:
	cluster u32
	x       i32
	y       i32
}

// HbCellOffset tracks the cell starting x and cluster.
struct HbCellOffset {
mut:
	cluster u32
	x       i32
}

// Default features for HarfBuzz shaping.
// The HarfBuzz shaper enables standard ligatures by default.
const hb_default_features = [
	HbFeatureTag{
		tag: [u8(`l`), `i`, `g`, `a`]!
		value: 1
	},
]

// HbFeatureTag holds a font feature as a 4-byte tag and value,
// before conversion to the HarfBuzz wire format.
struct HbFeatureTag {
	tag   [4]u8
	value u32
}

// tag_to_u32 converts a 4-byte OpenType tag to a big-endian u32.
// HarfBuzz uses big-endian tag encoding: HB_TAG('l','i','g','a') =
// (l << 24) | (i << 16) | (g << 8) | a.
fn tag_to_u32(tag [4]u8) u32 {
	return (u32(tag[0]) << 24) | (u32(tag[1]) << 16) | (u32(tag[2]) << 8) | u32(tag[3])
}

// parse_hb_feature_string parses a feature string like "dlig", "+dlig", "-liga"
// into a harfbuzz.Feature. Returns none if the string is invalid.
//
// Supported formats:
//   "liga"  or "+liga" -> enable feature (value=1)
//   "-liga"            -> disable feature (value=0)
fn parse_hb_feature_string(s string) ?harfbuzz.Feature {
	mut str := s
	mut value := u32(1)

	if str.len == 0 {
		return none
	}

	// Handle +/- prefix
	if str[0] == `+` {
		str = str[1..]
		value = 1
	} else if str[0] == `-` {
		str = str[1..]
		value = 0
	}

	if str.len == 0 || str.len > 4 {
		return none
	}

	// Build the 4-byte tag, padding with spaces (HarfBuzz convention).
	mut tag := [u8(` `), ` `, ` `, ` `]!
	for i in 0 .. str.len {
		tag[i] = str[i]
	}

	return harfbuzz.Feature{
		tag: tag_to_u32(tag)
		value: value
		start: harfbuzz.feature_global_start
		end_: harfbuzz.feature_global_end
	}
}

// is_special_font checks if the font index refers to a built-in sprite font.
// Special fonts (sprites for cursors, underlines, etc.) don't need shaping
// because their codepoint == glyph_index.
fn is_special_font(font_index u32) bool {
	return font_index == font.sprite_index
}

// init creates a new HarfBuzz shaper.
//
// The cell_buf argument is the buffer to use for storing shaped results.
// This should be at least the number of columns in the terminal.
pub fn HbShaper.init(opts font.ShaperOptions) !HbShaper {
	// Parse all the features we want to use.
	// Start with the hardcoded default features, then append user features.
	mut feat_list := []harfbuzz.Feature{cap: hb_default_features.len + opts.features.len}

	for df in hb_default_features {
		feat_list << harfbuzz.Feature{
			tag: tag_to_u32(df.tag)
			value: df.value
			start: harfbuzz.feature_global_start
			end_: harfbuzz.feature_global_end
		}
	}

	for feature_str in opts.features {
		if feat := parse_hb_feature_string(feature_str) {
			feat_list << feat
		}
	}

	return HbShaper{
		hb_buf: harfbuzz.Buffer.create()!
		cell_buf: []font.ShapeCell{}
		hb_feats: feat_list
		codepoints: []HbCodepoint{}
	}
}

// deinit releases all resources held by the shaper.
pub fn (mut self HbShaper) deinit() {
	self.hb_buf.destroy()
	self.cell_buf = []
	self.hb_feats = []
	self.codepoints = []
}

// end_frame signals that we're done processing the current frame.
// For HarfBuzz, this is a no-op (unlike CoreText which has release pools).
pub fn (self &HbShaper) end_frame() {
	// nothing to do
}

// run_iterator returns an iterator that returns one text run at a time for the
// given terminal row. Note that text runs are only valid one at a time
// for an HbShaper struct since they share state.
//
// The selection must be a row-only selection (height = 1). See
// Selection.containedRow. The run iterator will ONLY look at X values
// and assume the y value matches.
pub fn (mut self HbShaper) run_iterator(opts font.RunOptions) font.RunIterator {
	self.grid = opts.grid
	return font.RunIterator.new(unsafe { &self })
}

// shape shapes the given text run. The text run must be the immediately previous
// text run that was iterated since the text run does share state with the
// HbShaper struct.
//
// The return value is only valid until the next shape call is called.
//
// If there is not enough space in the cell buffer, an error is returned.
pub fn (mut self HbShaper) shape(run font.TextRun) ![]font.ShapeCell {
	// We only do shaping if the font is not a special-case. For special-case
	// fonts, the codepoint == glyph_index so we don't need to run any shaping.
	if !is_special_font(run.font_index) {
		// XTODO: We have to lock the grid to get the face and unfortunately
		// freetype faces (typically used with harfbuzz) are not thread
		// safe so this has to be an exclusive lock.
		//
		// In the full implementation:
		//   run.grid.lock.lock()
		//   defer { run.grid.lock.unlock() }
		//   face := run.grid.resolver.collection.get_face(run.font_index)
		//   i := if !face.quirks_disable_default_font_features { 0 } else {
		//       hb_default_features.len
		//   }
		//   harfbuzz.shape(face.hb_font, mut self.hb_buf, self.hb_feats[i..])

		// Stub: shape with all features using an empty font handle.
		harfbuzz.shape(&harfbuzz.Font{}, mut self.hb_buf, self.hb_feats)
	}

	// If our buffer is empty, we short-circuit the rest of the work
	// return nothing.
	if self.hb_buf.get_length() == 0 {
		return []font.ShapeCell{}
	}
	info := self.hb_buf.get_glyph_infos()
	pos := self.hb_buf.get_glyph_positions() or { return error('HarfbuzzFailed') }

	// This is perhaps not true somewhere, but we currently assume it is true.
	// If it isn't true, I'd like to catch it and learn more.
	assert info.len == pos.len

	// This keeps track of the current x and y offsets (sum of advances)
	// and the furthest cluster we've seen so far (max).
	mut run_offset := HbRunOffset{}

	// This keeps track of the cell starting x and cluster.
	mut cell_offset := HbCellOffset{}

	// Convert all our info/pos to cells and set it.
	self.cell_buf.clear()
	for idx in 0 .. info.len {
		info_v := info[idx]
		pos_v := pos[idx]

		// info_v.cluster is the index into our codepoints array. We use it
		// to get the original cluster.
		index := info_v.cluster

		// Our cluster is also our cell X position. If the cluster changes
		// then we need to reset our current cell offsets.
		cluster := self.codepoints[index].cluster
		if cell_offset.cluster != cluster {
			is_after_glyph_from_current_or_next_clusters :=
				cluster <= run_offset.cluster

			is_first_codepoint_in_cluster := if index > 0 {
				// Check if the previous codepoint belongs to a different cluster.
				self.codepoints[index - 1].cluster != cluster
			} else {
				true
			}

			// We need to reset the `cell_offset` at the start of a new
			// cluster, but we do that conditionally if the codepoint
			// `is_first_codepoint_in_cluster` and the cluster is not
			// `is_after_glyph_from_current_or_next_clusters`, which is
			// a heuristic to detect ligatures and avoid positioning
			// glyphs that mark ligatures incorrectly. The idea is that
			// if the first codepoint in a cluster doesn't appear in
			// the stream, it's very likely that it combined with
			// codepoints from a previous cluster into a ligature.
			// Then, the subsequent codepoints are very likely marking
			// glyphs that are placed relative to that ligature, so if
			// we were to reset the `cell_offset` to align it with the
			// grid, the positions would be off. The
			// `!is_after_glyph_from_current_or_next_clusters` check is
			// needed in case these marking glyphs come from a later
			// cluster but are rendered first (see the Chakma and
			// Bengali tests). In that case when we get to the
			// codepoint that `is_first_codepoint_in_cluster`, but in a
			// cluster that
			// `is_after_glyph_from_current_or_next_clusters`, we don't
			// want to reset to the grid and cause the positions to be
			// off. (Note that we could go back and align the cells to
			// the grid starting from the one from the cluster that
			// rendered out of order, but that is more complicated so
			// we don't do that for now. Also, it's TBD if there are
			// exceptions to this heuristic for detecting ligatures,
			// but using the logging below seems to show it works
			// well.)
			if is_first_codepoint_in_cluster
				&& !is_after_glyph_from_current_or_next_clusters {
				cell_offset = HbCellOffset{
					cluster: cluster
					x: run_offset.x
				}
			}
		}

		// Under both FreeType and CoreText the harfbuzz scale is
		// in 26.6 fixed point units, so we round to the nearest
		// whole value here.
		x_offset := run_offset.x - cell_offset.x + ((pos_v.x_offset + 32) >> 6)
		y_offset := run_offset.y + ((pos_v.y_offset + 32) >> 6)

		// For debugging positions, turn this on:
		// self.debug_positions(run_offset, cell_offset, pos_v, index)

		self.cell_buf << font.ShapeCell{
			x: cell_offset.cluster
			x_offset: x_offset
			y_offset: y_offset
			glyph_index: info_v.codepoint
		}

		// Add our advances to keep track of our run offsets.
		// Advances apply to the NEXT cell.
		// Under both FreeType and CoreText the harfbuzz scale is
		// in 26.6 fixed point units, so we round to the nearest
		// whole value here.
		run_offset.x += (pos_v.x_advance + 32) >> 6
		run_offset.y += (pos_v.y_advance + 32) >> 6
		if cluster > run_offset.cluster {
			run_offset.cluster = cluster
		}

		// const i = self.cell_buf.items.len - 1;
		// log.warn("i={} info={} pos={} cell={}", .{ i, info_v, pos_v, self.cell_buf.items[i] });
	}
	// log.warn("----------------", .{});

	return self.cell_buf
}

// The hooks for RunIterator.
pub struct HbRunIteratorHook {
pub mut:
	shaper &HbShaper = unsafe { nil }
}

// prepare resets the buffer for our current run.
pub fn (mut self HbRunIteratorHook) prepare() {
	// Reset the buffer for our current run
	self.shaper.hb_buf.reset()
	self.shaper.hb_buf.set_content_type(.unicode)

	// We set the cluster level to `characters` to give us the most
	// granularity, matching the CoreText shaper, and allowing us
	// to use our same ligature detection heuristics.
	self.shaper.hb_buf.set_cluster_level(.characters)

	self.shaper.codepoints.clear()

	// We don't support RTL text because RTL in terminals is messy.
	// Its something we want to improve. For now, we force LTR because
	// our renderers assume a strictly increasing X value.
	self.shaper.hb_buf.set_direction(.ltr)
}

// add_codepoint adds a codepoint with its cluster to the current run.
pub fn (mut self HbRunIteratorHook) add_codepoint(cp u32, cluster u32) ! {
	// log.warn("cluster={} cp={x}", .{ cluster, cp });

	// We pass the index into codepoints as the cluster value to HarfBuzz.
	// After shaping, we use info.cluster to get back the index, which
	// lets us look up the original cluster value from codepoints.
	index := u32(self.shaper.codepoints.len)
	self.shaper.hb_buf.add(cp, index)
	self.shaper.codepoints << HbCodepoint{
		cluster: cluster
		codepoint: cp
	}
}

// finalize completes the run by guessing segment properties.
pub fn (mut self HbRunIteratorHook) finalize() {
	self.shaper.hb_buf.guess_segment_properties()
}

// debug_positions logs detailed position/advance debug info for a glyph.
// Normally this is not called; enable it by uncommenting calls in shape().
fn (self &HbShaper) debug_positions(run_offset HbRunOffset, cell_offset HbCellOffset, pos_v harfbuzz.GlyphPosition, index u32) {
	// XTODO: Full debug logging requires unicode.table access for grapheme
	// boundary class detection and formatted codepoint display.
	//
	// The original code:
	// 1. Computes x_offset and y_offset from run_offset, cell_offset, and pos_v
	// 2. Checks if positions differ from advances
	// 3. Checks if run_offset.y differs from zero
	// 4. Checks if cell_offset.cluster differs from the current cluster
	//    (potential ligature detected)
	// 5. For each discrepancy, formats the surrounding codepoints using
	//    Python-style escape sequences and logs them
	// 6. Optionally checks if the previous codepoint has grapheme_boundary_class
	//    == .prepend (requires unicode tables)

	x_offset := run_offset.x - cell_offset.x + ((pos_v.x_offset + 32) >> 6)
	y_offset := run_offset.y + ((pos_v.y_offset + 32) >> 6)
	advance_x_offset := run_offset.x - cell_offset.x
	advance_y_offset := run_offset.y
	x_offset_diff := x_offset - advance_x_offset
	y_offset_diff := y_offset - advance_y_offset
	_ = x_offset_diff
	_ = y_offset_diff

	cluster := self.codepoints[index].cluster
	cluster_differs := cluster != cell_offset.cluster
	_ = cluster_differs

	// To debug every loop, flip this to true:
	// extra_debugging := false

	// XTODO: would check is_previous_codepoint_prepend via unicode table
	// XTODO: would format codepoints for display
	// XTODO: would log position differences, y-offset differences,
	//        and cluster differences (potential ligature detection)
}
