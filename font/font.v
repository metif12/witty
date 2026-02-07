module font

import math

// Default DPI used as the base for scaling calculations.
pub const default_dpi = f32(72.0)

// The font index reserved for built-in sprites (cursors, underlines, etc).
pub const sprite_index = u32(0)

// ============================================================
// Metrics
// ============================================================

// Metrics holds font measurement data for the grid.
pub struct Metrics {
pub mut:
	cell_width             u32
	cell_height            u32
	cell_baseline          u32
	// Position of the underline from the top of the cell.
	underline_position     u32
	// Thickness of the underline in pixels.
	underline_thickness    u32
	// Position of the strikethrough from the top of the cell.
	strikethrough_position u32
	// Thickness of the strikethrough in pixels.
	strikethrough_thickness u32
	// Position of the overline from the top of the cell.
	overline_position      u32
	// Thickness of the overline in pixels.
	overline_thickness     u32
	// Thickness for box-drawing characters.
	box_thickness          u32
	// Height of the cursor in pixels.
	cursor_height          u32
	// Icon height for multi-cell glyphs (f64 for precision).
	icon_height            f64
	// Icon height for single-cell glyphs.
	icon_height_single     f64
	// Width of the primary face (may differ from cell_width).
	face_width             f64
	// Height of the primary face.
	face_height            f64
	// Vertical offset of the face within the cell.
	face_y                 f64
}

// calc computes grid Metrics from face-level FaceMetrics.
// XTODO: implement full metrics calculation with proper rounding,
// underline/strikethrough position calculation, icon height, etc.
pub fn Metrics.calc(fm FaceMetrics) Metrics {
	line_height := fm.ascent - fm.descent + fm.line_gap
	cell_height := u32(math.round(line_height))
	cell_width := u32(math.round(fm.cell_width))
	// Cell baseline is the distance from the bottom of the cell
	// to the baseline, i.e., ceil(-descent).
	cell_baseline := u32(math.ceil(-fm.descent))

	// Underline: positioned at cell_height (bottom of cell).
	// XTODO: proper underline position from face metrics.
	ul_thickness := u32(math.max(1.0, math.round(fm.underline_thickness or { 1.0 })))
	ul_position := cell_height

	// Strikethrough: roughly at the center of the ascent.
	st_thickness := u32(math.max(1.0, math.round(fm.strikethrough_thickness or { f64(ul_thickness) })))
	st_position := u32(math.round(fm.ascent * 0.6))

	// Overline: at top of cell.
	ol_thickness := ul_thickness

	// Box drawing thickness.
	box_thickness := ul_thickness

	// Cap and ex heights for icon height calculation.
	cap_h := fm.cap_height_val()
	// Icon height = (2 * cap_height + face_height) / 3
	icon_h := (2.0 * cap_h + line_height) / 3.0

	return Metrics{
		cell_width: cell_width
		cell_height: cell_height
		cell_baseline: cell_baseline
		underline_position: ul_position
		underline_thickness: ul_thickness
		strikethrough_position: st_position
		strikethrough_thickness: st_thickness
		overline_position: 0
		overline_thickness: ol_thickness
		box_thickness: box_thickness
		cursor_height: cell_height
		icon_height: line_height
		icon_height_single: icon_h
		face_width: fm.cell_width
		face_height: line_height
		face_y: fm.descent + f64(cell_baseline)
	}
}

// apply applies metric modifiers to adjust the computed metrics.
pub fn (mut m Metrics) apply(modifiers MetricsModifierSet) {
	// XTODO: implement metric modifier application
	// (cell padding, custom underline position, etc.)
	_ = modifiers
}

// ============================================================
// DesiredSize
// ============================================================

// DesiredSize represents the desired font size with DPI info.
pub struct DesiredSize {
pub mut:
	points f32
	xdpi   u32
	ydpi   u32
}

// pixels returns the pixel size derived from points and DPI.
pub fn (d DesiredSize) pixels() f64 {
	dpi := if d.ydpi > 0 { f64(d.ydpi) } else { f64(default_dpi) }
	return f64(d.points) * dpi / f64(default_dpi)
}

// ============================================================
// SharedGridSet
// ============================================================

// SharedGridSet manages shared font grids across surfaces.
pub struct SharedGridSet {}

pub fn (s SharedGridSet) ref(config &DerivedConfig, size DesiredSize) !(GridKey, &SharedGrid) {
	return GridKey{}, &SharedGrid{
		metrics: Metrics{
			cell_width: 10
			cell_height: 20
			cell_baseline: 16
		}
	}
}

pub fn (s SharedGridSet) deref(key GridKey) {
	// stub: decrements reference count
	_ = key
}

pub struct GridKey {}

// ============================================================
// SharedGrid
// ============================================================

// SharedGrid is a font grid shared across surfaces. It contains
// the font atlas textures and metrics, protected by a lock.
pub struct SharedGrid {
pub mut:
	// The font metrics for this grid.
	metrics Metrics
	// The grayscale atlas for text glyphs.
	atlas_grayscale Atlas
	// The color atlas for emoji and color glyphs.
	atlas_color Atlas
}

// Render a glyph from the grid. Returns the rendered glyph info.
pub fn (mut g SharedGrid) render_glyph(font_idx u32, glyph_index u32, opts RenderOptions) !RenderResult {
	return RenderResult{
		glyph: GlyphInfo{}
		presentation: .text
	}
}

// Render a codepoint from the grid. Returns the rendered glyph info, or none.
pub fn (mut g SharedGrid) render_codepoint(cp u32, style FontStyle, presentation Presentation, opts RenderOptions) ?RenderResult {
	return RenderResult{
		glyph: GlyphInfo{}
		presentation: .text
	}
}

// ============================================================
// Atlas
// ============================================================

// Atlas holds a texture atlas for font glyphs.
pub struct Atlas {
pub mut:
	// Modification counter, incremented on each atlas update.
	modified u64
	// The size of the atlas texture (width and height are equal).
	size u32
	// The raw pixel data.
	data []u8
}

// ============================================================
// Glyph / Render types
// ============================================================

// GlyphInfo holds information about a rendered glyph in the atlas.
pub struct GlyphInfo {
pub mut:
	atlas_x  u32
	atlas_y  u32
	width    u32
	height   u32
	offset_x i32
	offset_y i32
}

// RenderResult holds the result of rendering a glyph.
pub struct RenderResult {
pub:
	glyph        GlyphInfo
	presentation Presentation
}

// RenderOptions for glyph rendering.
pub struct RenderOptions {
pub:
	cell_width       u32 = 1
	grid_metrics     Metrics
	thicken          bool
	thicken_strength u8
	constraint       Constraint
	constraint_width u32
}

// Constraint controls how a glyph is constrained to fit its cell.
// Specifies scaling/positioning attributes for glyphs.
pub struct Constraint {
pub:
	// Sizing rule.
	size ConstraintSize = .none_
	// Vertical alignment rule.
	align_vertical ConstraintAlign = .none_
	// Horizontal alignment rule.
	align_horizontal ConstraintAlign = .none_
	// Top padding when resizing.
	pad_top f64
	// Left padding when resizing.
	pad_left f64
	// Right padding when resizing.
	pad_right f64
	// Bottom padding when resizing.
	pad_bottom f64
	// Size and bearings of the glyph relative
	// to the bounding box of its scale group.
	relative_width f64 = 1.0
	relative_height f64 = 1.0
	relative_x f64
	relative_y f64
	// Maximum aspect ratio (width/height) to allow when stretching.
	// 0 means no limit.
	max_xy_ratio f64
	// Maximum number of cells horizontally to use.
	max_constraint_width u8 = 2
	// What to use as the height metric when constraining the glyph
	// and the constraint width is 1.
	height ConstraintHeight = .cell
}

// Don't constrain the glyph in any way.
pub const constraint_none = Constraint{}

// Returns true if the constraint does anything. If it doesn't,
// because it neither sizes nor positions the glyph, then this
// returns false.
pub fn (c Constraint) does_anything() bool {
	return c.size != .none_ || c.align_horizontal != .none_ || c.align_vertical != .none_
}

// ConstraintSize specifies how a glyph should be sized.
pub enum ConstraintSize {
	// Don't change the size of this glyph.
	none_
	// Scale the glyph down if needed to fit within the bounds,
	// preserving aspect ratio.
	fit
	// Scale the glyph up or down to exactly match the bounds,
	// preserving aspect ratio.
	cover
	// Scale the glyph down if needed to fit within the bounds,
	// preserving aspect ratio. If the glyph doesn't cover a
	// single cell, scale up. If the glyph exceeds a single
	// cell but is within the bounds, do nothing.
	// (Nerd Font specific rule.)
	fit_cover1
	// Stretch the glyph to exactly fit the bounds in both
	// directions, disregarding aspect ratio.
	stretch
}

// ConstraintAlign specifies how a glyph should be aligned.
pub enum ConstraintAlign {
	// Don't move the glyph on this axis.
	none_
	// Move the glyph so that its leading (bottom/left)
	// edge aligns with the leading edge of the axis.
	start
	// Move the glyph so that its trailing (top/right)
	// edge aligns with the trailing edge of the axis.
	end_
	// Move the glyph so that it is centered on this axis.
	center
	// Move the glyph so that it is centered on this axis,
	// but always with respect to the first cell even for
	// multi-cell constraints. (Nerd Font specific rule.)
	center1
}

// ConstraintHeight specifies what height metric to use.
pub enum ConstraintHeight {
	// Use the full line height of the primary face for
	// constraining this glyph.
	cell
	// Use the icon height from the grid metrics for
	// constraining this glyph. Unlike cell, the value of
	// this height depends on both the constraint width and the
	// adjust-icon-height config option.
	icon
}

// Backward compatibility aliases.
pub type GlyphConstraint = Constraint
pub type GlyphConstraintSize = ConstraintSize
pub const none_constraint = constraint_none

// Presentation for a glyph (text or emoji).
pub enum Presentation {
	text
	emoji
}

// FontStyle for codepoint rendering.
pub enum FontStyle {
	regular
	bold
	italic
	bold_italic
}

// ============================================================
// Sprite
// ============================================================

// Sprite enumerates built-in sprite glyphs used for cursors,
// underlines, and other decorations.
pub enum Sprite {
	underline
	underline_double
	underline_dotted
	underline_dashed
	underline_curly
	overline
	strikethrough
	cursor_rect
	cursor_hollow_rect
	cursor_bar
	cursor_underline
}

// ============================================================
// Shaper
// ============================================================

// Shaper performs text shaping (converting codepoints to positioned glyphs).
pub struct Shaper {
mut:
	features []string
}

pub fn Shaper.init(opts ShaperOptions) !Shaper {
	return Shaper{
		features: opts.features.clone()
	}
}

pub fn (mut s Shaper) deinit() {
	s.features = []
}

// Signal that we're done processing the current frame.
// For some shapers (e.g. CoreText), this triggers off-thread cleanup.
pub fn (mut s Shaper) end_frame() {
	// stub
}

// Shape a text run into positioned glyphs.
pub fn (mut s Shaper) shape(run TextRun) ![]ShapeCell {
	return []ShapeCell{}
}

// Create a run iterator for the given options.
pub fn (mut s Shaper) run_iterator(opts RunOptions) RunIterator {
	return RunIterator.new(unsafe { &s })
}

pub struct ShaperOptions {
pub:
	features []string
}

// ============================================================
// ShaperCache
// ============================================================

// ShaperCache caches shaped text runs to avoid re-shaping.
pub struct ShaperCache {
mut:
	entries map[u64][]ShapeCell
}

pub fn ShaperCache.init() ShaperCache {
	return ShaperCache{}
}

pub fn (mut c ShaperCache) deinit() {
	c.entries = map[u64][]ShapeCell{}
}

// Get cached shaping results for a run.
pub fn (c &ShaperCache) get(run TextRun) ?[]ShapeCell {
	return none
}

// Store shaping results for a run in the cache.
pub fn (mut c ShaperCache) put(run TextRun, cells []ShapeCell) ! {
	// stub: cache the result
}

// Return the number of cached entries.
pub fn (c &ShaperCache) count() int {
	return c.entries.len
}

// ============================================================
// Shape types (text runs and cells)
// ============================================================

// TextRun represents a run of text to be shaped.
pub struct TextRun {
pub:
	// A unique hash for this run. This can be used to cache the shaping
	// results. The hash is position-independent within the row by using
	// relative cluster positions.
	hash       u64
	font_index u32
	offset     u32
	cells      u32
}

// ShapeCell represents a positioned glyph from shaping.
pub struct ShapeCell {
pub:
	x           u32
	glyph_index u32
	x_offset    i32
	y_offset    i32
}

// RunOptions configures the run iterator.
pub struct RunOptions {
pub:
	grid      &SharedGrid = unsafe { nil }
	cells     []u8 // placeholder for multi-array slice
	selection ?[2]u16
	cursor_x  ?u16
}

// RunIterator iterates over text runs for shaping.
pub struct RunIterator {
pub mut:
	shaper_ptr voidptr = unsafe { nil }
	done       bool
}

// Create a new RunIterator with an opaque pointer to the shaper.
pub fn RunIterator.new(shaper_ptr voidptr) RunIterator {
	return RunIterator{
		shaper_ptr: shaper_ptr
	}
}

// Get the next text run, or none if done.
pub fn (mut it RunIterator) next() ?TextRun {
	if it.done {
		return none
	}
	it.done = true
	return none
}

// ============================================================
// Backward compat aliases
// ============================================================

pub type Grid = SharedGrid

pub struct CellSize {
pub:
	width  u32
	height u32
}

pub struct DerivedConfig {}

pub fn DerivedConfig.init(config voidptr) !DerivedConfig {
	return DerivedConfig{}
}
