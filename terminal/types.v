module terminal

// Fundamental types for the terminal module.
// These types are used by both Screen and Terminal.

// ============================================================
// Constants
// ============================================================

// The default style ID (no style applied).
pub const default_style_id = u32(0)

// ============================================================
// Cell types
// ============================================================

// CellWide describes the width behavior of a cell.
pub enum CellWide as u8 {
	narrow      = 0
	wide        = 1
	spacer_tail = 2
	spacer_head = 3
}

// ContentTag describes what kind of content a cell holds.
// The content tag dictates the active field in CellData and possibly
// some other behaviors.
pub enum ContentTag as u8 {
	// A single codepoint, could be zero to be empty cell.
	codepoint          = 0
	// A codepoint that is part of a multi-codepoint grapheme cluster.
	// The codepoint field is active, but also expect more
	// codepoints in the graphemes data.
	codepoint_grapheme = 1
	// The cell has no text but only a background color. This is an
	// optimization so that cells with only backgrounds don't take up
	// style map space and also don't require a style map lookup.
	bg_color_palette   = 2
	bg_color_rgb       = 3
}

// SemanticContent describes what the cell content semantically represents.
pub enum SemanticContent as u8 {
	output = 0
	input  = 1
	prompt = 2
}

// CellData is the data for a single cell in the terminal grid.
//
// The zero value of this struct must be a valid cell representing empty,
// since we zero initialize cells by default.
pub struct CellData {
pub mut:
	// The codepoint that this cell contains. If content_tag is codepoint,
	// then this is the only codepoint in the cell. If content_tag is
	// codepoint_grapheme, then this is the first codepoint in the cluster.
	codepoint u32
	// The content tag dictates what kind of content this cell holds.
	content_tag ContentTag = .codepoint
	// The style ID to use for this cell within the style map. Zero
	// is always the default style so no lookup is required.
	style_id u32
	// The wide property of this cell, for wide characters.
	wide CellWide = .narrow
	// Whether this was written with the protection flag set.
	is_protected bool
	// Whether this cell is a hyperlink.
	has_hyperlink bool
	// The semantic type of the content of this cell.
	semantic_content SemanticContent = .output
	// Additional codepoints for grapheme clusters. These are the
	// codepoints in addition to the first codepoint. The first
	// codepoint is NOT included since it is on the cell itself.
	graphemes []u32
	// For bg_color content variants.
	color_palette u8
	color_rgb_r   u8
	color_rgb_g   u8
	color_rgb_b   u8
}

// Helper to make a cell that just has a codepoint.
pub fn CellData.init(cp u32) CellData {
	return CellData{
		content_tag: .codepoint
		codepoint: cp
	}
}

// Returns true if this cell represents all zeroes.
pub fn (self &CellData) is_zero() bool {
	return self.codepoint == 0 && self.content_tag == .codepoint && self.style_id == 0
		&& self.wide == .narrow && !self.is_protected
		&& !self.has_hyperlink && self.semantic_content == .output
		&& self.graphemes.len == 0
}

// Returns true if the cell has displayable text.
//
// Cases this returns false:
//   - Cell text is blank
//   - Cell is styled but only with a background color and no text
pub fn (self &CellData) has_text() bool {
	return match self.content_tag {
		.codepoint, .codepoint_grapheme { self.codepoint != 0 }
		.bg_color_palette, .bg_color_rgb { false }
	}
}

// Returns the codepoint for this cell, or 0 for bg-only cells.
pub fn (self &CellData) codepoint() u32 {
	return match self.content_tag {
		.codepoint, .codepoint_grapheme { self.codepoint }
		.bg_color_palette, .bg_color_rgb { 0 }
	}
}

// Returns true if this cell has multi-codepoint grapheme data.
pub fn (self &CellData) has_grapheme() bool {
	return self.content_tag == .codepoint_grapheme
}

// The width in grid cells that this cell takes up.
pub fn (self &CellData) grid_width() int {
	return match self.wide {
		.narrow, .spacer_head, .spacer_tail { 1 }
		.wide { 2 }
	}
}

// Returns true if the cell has a non-default style.
pub fn (self &CellData) has_styling() bool {
	return self.style_id != default_style_id
}

// Returns true if the cell has no text or styling.
pub fn (self &CellData) is_empty() bool {
	return match self.content_tag {
		// Textual cells are empty if they have no text and are narrow.
		// The "narrow" requirement is because wide spacers are meaningful.
		.codepoint, .codepoint_grapheme {
			!self.has_text() && self.wide == .narrow
		}
		.bg_color_palette, .bg_color_rgb {
			false
		}
	}
}

// Returns true if the set of cells has text in any cell.
pub fn has_text_any(cells []CellData) bool {
	for cell in cells {
		if cell.has_text() {
			return true
		}
	}
	return false
}

// ============================================================
// Row types
// ============================================================

// SemanticPromptType tracks what kind of semantic prompt a row has.
pub enum SemanticPromptType as u8 {
	unknown             = 0
	prompt              = 1
	prompt_continuation = 2
}

// RowData is the data for a single row in the terminal grid.
pub struct RowData {
pub mut:
	cells []CellData
	// The row's cell block within its page. Ghostty's Row holds an offset to
	// its cells in page memory, so moving a row within the page moves its
	// cells and their grapheme and hyperlink entries with it. V keeps each
	// row's cells in their own array; this is the equivalent handle, and the
	// page keys its managed-memory maps by it rather than by row index.
	cells_offset u32
	// True if this row is soft-wrapped. The first cell of the next
	// row is a continuation of this row.
	wrap bool
	// True if the previous row to this one is soft-wrapped and
	// this row is a continuation of that row.
	wrap_continuation bool
	// True if any of the cells in this row have multi-codepoint
	// grapheme clusters. If this is true, some fast paths are not
	// possible because erasing for example may need to clear existing
	// grapheme data.
	grapheme bool
	// True if any of the cells in this row have a ref-counted style.
	// This can have false positives but never a false negative.
	styled bool
	// True if any of the cells in this row are part of a hyperlink.
	// Similar to styled: can have false positives but never false negatives.
	hyperlink bool
	// The semantic prompt state for this row.
	semantic_prompt SemanticPromptType = .unknown
	// True if this row contains a virtual placeholder for the Kitty
	// graphics protocol. (U+10EEEE)
	kitty_virtual_placeholder bool
	// True if this row is dirty and requires a redraw.
	dirty bool
}

// Initialize a new row with the given number of columns.
pub fn RowData.init(cols u32) RowData {
	return RowData{
		cells: []CellData{len: int(cols)}
	}
}

// Returns true if this row has any managed memory outside of the
// row structure (graphemes, styles, hyperlinks).
pub fn (self &RowData) managed_memory() bool {
	// Ordered on purpose for likelihood.
	return self.styled || self.hyperlink || self.grapheme
}

// ============================================================
// Style types
// ============================================================

// UnderlineStyle for cell underline decoration.
pub enum UnderlineStyle as u8 {
	none   = 0
	single = 1
	double = 2
	curly  = 3
	dotted = 4
	dashed = 5
}

// StyleFlags contains boolean style attributes.
pub struct StyleFlags {
mut:
	value u16
}

pub fn StyleFlags.init(bold bool, italic bool, faint bool, blink bool, inverse bool, invisible bool, strikethrough bool, overline bool, underline UnderlineStyle) StyleFlags {
	return StyleFlags{
		value: u16(bold) | (u16(italic) << 1) | (u16(faint) << 2) | (u16(blink) << 3) | (u16(inverse) << 4) | (u16(invisible) << 5) | (u16(strikethrough) << 6) | (u16(overline) << 7) | (u16(underline) << 8)
	}
}

pub fn (flags StyleFlags) bold() bool {
	return flags.value & 0x0001 != 0
}

pub fn (flags StyleFlags) italic() bool {
	return flags.value & 0x0002 != 0
}

pub fn (flags StyleFlags) faint() bool {
	return flags.value & 0x0004 != 0
}

pub fn (flags StyleFlags) blink() bool {
	return flags.value & 0x0008 != 0
}

pub fn (flags StyleFlags) inverse() bool {
	return flags.value & 0x0010 != 0
}

pub fn (flags StyleFlags) invisible() bool {
	return flags.value & 0x0020 != 0
}

pub fn (flags StyleFlags) strikethrough() bool {
	return flags.value & 0x0040 != 0
}

pub fn (flags StyleFlags) overline() bool {
	return flags.value & 0x0080 != 0
}

pub fn (flags StyleFlags) underline() UnderlineStyle {
	return unsafe { UnderlineStyle((flags.value >> 8) & 0x0007) }
}

pub fn (flags StyleFlags) int() u16 {
	return flags.value
}

fn (mut flags StyleFlags) set_bool(mask u16, enabled bool) {
	flags.value = if enabled { flags.value | mask } else { flags.value & ~mask }
}

pub fn (mut flags StyleFlags) set_bold(enabled bool) {
	flags.set_bool(0x0001, enabled)
}

pub fn (mut flags StyleFlags) set_italic(enabled bool) {
	flags.set_bool(0x0002, enabled)
}

pub fn (mut flags StyleFlags) set_faint(enabled bool) {
	flags.set_bool(0x0004, enabled)
}

pub fn (mut flags StyleFlags) set_blink(enabled bool) {
	flags.set_bool(0x0008, enabled)
}

pub fn (mut flags StyleFlags) set_inverse(enabled bool) {
	flags.set_bool(0x0010, enabled)
}

pub fn (mut flags StyleFlags) set_invisible(enabled bool) {
	flags.set_bool(0x0020, enabled)
}

pub fn (mut flags StyleFlags) set_strikethrough(enabled bool) {
	flags.set_bool(0x0040, enabled)
}

pub fn (mut flags StyleFlags) set_overline(enabled bool) {
	flags.set_bool(0x0080, enabled)
}

pub fn (mut flags StyleFlags) set_underline(underline UnderlineStyle) {
	flags.value = (flags.value & ~u16(0x0700)) | (u16(underline) << 8)
}

// ColorType describes what type of color is set.
pub enum ColorType as u8 {
	none
	palette
	rgb
}

// CellStyle holds the complete style for a cell.
pub struct CellStyle {
pub mut:
	flags           StyleFlags
	fg_color        ColorType = .none
	bg_color        ColorType = .none
	underline_color_type ColorType = .none
	fg_r            u8
	fg_g            u8
	fg_b            u8
	bg_r            u8
	bg_g            u8
	bg_b            u8
	fg_palette      u8
	bg_palette      u8
	// Dedicated underline-color storage, independent of the fg color.
	// Ghostty stores this in a separate Style.underline_color Color union.
	underline_r       u8
	underline_g       u8
	underline_b       u8
	underline_palette u8
}

// Returns true if this is the default (empty) style.
pub fn (self &CellStyle) default() bool {
	return self.flags.int() == 0 && self.fg_color == .none && self.bg_color == .none
		&& self.underline_color_type == .none
}

// Returns a blank cell with the background color of this style.
//
// If no background color is set this returns none. Otherwise it returns a
// cell tagged as background-only content, so no style-map lookup is needed.
pub fn (self &CellStyle) bg_cell() ?CellData {
	return match self.bg_color {
		.none {
			none
		}
		.palette {
			CellData{
				content_tag: .bg_color_palette
				color_palette: self.bg_palette
			}
		}
		.rgb {
			CellData{
				content_tag: .bg_color_rgb
				color_rgb_r: self.bg_r
				color_rgb_g: self.bg_g
				color_rgb_b: self.bg_b
			}
		}
	}
}

// ============================================================
// SgrAttribute - SGR (Select Graphic Rendition) attribute
// ============================================================

pub enum SgrAttributeKind as i32 {
	unset
	unknown
	bold
	reset_bold
	italic
	reset_italic
	faint
	underline_set
	underline_color
	underline_color_256
	reset_underline_color
	overline
	reset_overline
	blink
	reset_blink
	inverse
	reset_inverse
	invisible
	reset_invisible
	strikethrough
	reset_strikethrough
	direct_color_fg
	direct_color_bg
	bg_8
	fg_8
	reset_fg
	reset_bg
	bright_bg_8
	bright_fg_8
	bg_256
	fg_256
}

pub struct SgrAttribute {
pub:
	kind      SgrAttributeKind
	underline UnderlineStyle = .none
	r         u8
	g         u8
	b         u8
	index     u8
	// Populated for unknown attributes. full is the complete SGR parameter
	// list and partial begins at the parameter that could not be parsed.
	unknown_full    []u16
	unknown_partial []u16
}

// Hyperlink is defined in hyperlink.v.

// ============================================================
// KeyFlagStack (Kitty keyboard protocol)
// ============================================================

// KeyFlags is the packed five-bit value used by the Kitty keyboard protocol.
// V's narrowest integer backing is one byte.
pub struct KeyFlags {
mut:
	value u8
}

pub const key_flags_disabled = KeyFlags{}
pub const key_flags_all = KeyFlags{ value: 0b1_1111 }

pub fn KeyFlags.init(disambiguate bool, report_events bool, report_alternates bool, report_all bool, report_associated bool) KeyFlags {
	return KeyFlags{
		value: u8(disambiguate) | (u8(report_events) << 1) | (u8(report_alternates) << 2) | (u8(report_all) << 3) | (u8(report_associated) << 4)
	}
}

pub fn KeyFlags.from_int(value u8) KeyFlags {
	return KeyFlags{
		value: value & 0b1_1111
	}
}

pub fn (self KeyFlags) disambiguate() bool {
	return self.value & 0b0_0001 != 0
}

pub fn (self KeyFlags) report_events() bool {
	return self.value & 0b0_0010 != 0
}

pub fn (self KeyFlags) report_alternates() bool {
	return self.value & 0b0_0100 != 0
}

pub fn (self KeyFlags) report_all() bool {
	return self.value & 0b0_1000 != 0
}

pub fn (self KeyFlags) report_associated() bool {
	return self.value & 0b1_0000 != 0
}

pub fn (self KeyFlags) int() u8 {
	return self.value
}

pub struct KeyFlagStack {
pub mut:
	flags [8]KeyFlags = [8]KeyFlags{init: key_flags_disabled}
	idx   u8
}

// Push a new set of flags onto the stack.
pub fn (mut self KeyFlagStack) push(new_flags KeyFlags) {
	// Overflow and wrap around if we're full, which evicts
	// the oldest entry.
	self.idx = (self.idx + 1) % 8
	self.flags[self.idx] = new_flags
}

// Pop `n` entries from the stack. This will just wrap around
// if `n` is greater than the amount in the stack.
pub fn (mut self KeyFlagStack) pop(n usize) {
	// If n is more than our length then we just reset the stack.
	// This also avoids a DoS vector where a malicious client
	// could send a huge number of pop commands to waste cpu.
	if n >= 8 {
		self.idx = 0
		self.flags = [8]KeyFlags{init: key_flags_disabled}
		return
	}

	for _ in 0 .. n {
		self.flags[self.idx] = key_flags_disabled
		self.idx = if self.idx == 0 { u8(7) } else { self.idx - 1 }
	}
}

// Get the current (top) flags value.
pub fn (self KeyFlagStack) current() KeyFlags {
	return self.flags[self.idx]
}

// Set flags using a merge operation.
pub enum KeyFlagSetOp as u8 {
	set_
	or_
	not_
}

pub fn (mut self KeyFlagStack) set(op KeyFlagSetOp, new_flags KeyFlags) {
	match op {
		.set_ {
			self.flags[self.idx] = new_flags
		}
		.or_ {
			self.flags[self.idx] = KeyFlags.from_int(self.flags[self.idx].int() | new_flags.int())
		}
		.not_ {
			self.flags[self.idx] = KeyFlags.from_int(self.flags[self.idx].int() & ~new_flags.int())
		}
	}
}

// ============================================================
// PromptKind - for semantic prompt operations
// ============================================================

pub enum PromptKind as u8 {
	initial
	right
	continuation
	secondary
}
