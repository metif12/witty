module font

// Default DPI used as the base for scaling calculations.
pub const default_dpi = f32(72.0)

// The font index reserved for built-in sprites (cursors, underlines, etc).
pub const sprite_index = u32(0)

// ============================================================
// Metrics
// ============================================================

// Metrics holds font measurement data.
pub struct Metrics {
pub mut:
	cell_width    u32
	cell_height   u32
	cell_baseline u32
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
	constraint       GlyphConstraint = GlyphConstraint.none
	constraint_width u32
}

// GlyphConstraint controls how a glyph is constrained to fit its cell.
pub struct GlyphConstraint {
pub:
	size GlyphConstraintSize = .none
}

pub enum GlyphConstraintSize {
	none
	fit
	cell
}

pub const none_constraint = GlyphConstraint{}

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
	return RunIterator{
		shaper: unsafe { &s }
	}
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
mut:
	shaper &Shaper = unsafe { nil }
	done   bool
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
// CodepointResolver
// ============================================================

pub struct CodepointResolver {
pub:
	style_status StyleStatus
}

// StyleStatus tracks which font styles are enabled.
pub struct StyleStatus {
pub mut:
	bold        bool = true
	italic      bool = true
	bold_italic bool = true
}

pub fn StyleStatus.init_fill(val bool) StyleStatus {
	return StyleStatus{
		bold: val
		italic: val
		bold_italic: val
	}
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
