module terminal

// Terminal represents the terminal emulator state.
pub struct Terminal {
pub mut:
	cols         u32
	rows         u32
	screens      Screens
	flags        TerminalFlags
	modes        Modes
	mouse_shape  MouseShape
	colors       Colors
	cursor_style CursorStyle
}

pub struct Screens {
pub mut:
	active     Screen
	active_key ScreenKey
}

pub enum ScreenKey {
	primary
	alternate
}

pub enum CursorStyle {
	block
	underline
	bar
}

// CellData represents a single cell in the terminal grid.
pub struct CellData {
pub mut:
	codepoint        u32
	style_id         u32
	is_protected     bool
	wide             CellWide
	semantic_content SemanticContent
	has_grapheme     bool
	graphemes        []u32
	content_tag      CellContentTag
	has_hyperlink    bool
}

pub enum CellContentTag {
	codepoint
	codepoint_grapheme
}

pub fn (c CellData) has_text() bool {
	return c.codepoint != 0
}

pub fn (c CellData) codepoint_val() u32 {
	return c.codepoint
}

// RowData represents a row of cells.
pub struct RowData {
pub mut:
	cells              []CellData
	dirty              bool
	wrap               bool
	wrap_continuation  bool
	styled             bool
	grapheme           bool
	hyperlink          bool
	semantic_prompt    SemanticPromptType
	kitty_virtual_placeholder bool
}

pub fn RowData.init(cols u32) RowData {
	return RowData{
		cells: []CellData{len: int(cols)}
	}
}

pub enum SemanticPromptType {
	unknown
	prompt
	prompt_continuation
	input
	command
}

pub enum CellWide {
	narrow
	wide
	spacer_head
	spacer_tail
}

pub enum SemanticContent {
	output
	prompt
	input
}

// Pages represents the terminal page list (simplified PageList).
pub struct Pages {
pub mut:
	cols           u32
	rows           u32
	max_scrollback u32
	screen_rows    []RowData
	active_start   int
	viewport       ViewportState
}

pub enum ViewportState {
	active
	offset
}

pub fn Pages.init(cols u32, rows u32, max_scrollback u32) Pages {
	mut p := Pages{
		cols: cols
		rows: rows
		max_scrollback: max_scrollback
		viewport: .active
	}
	for _ in 0 .. rows {
		p.screen_rows << RowData.init(cols)
	}
	p.active_start = 0
	return p
}

pub fn (p Pages) total_rows() int {
	return p.screen_rows.len
}

pub fn (mut p Pages) deinit() {
	p.screen_rows.clear()
}

pub fn (p Pages) get_active_row(y u32) &RowData {
	idx := p.active_start + int(y)
	return &p.screen_rows[idx]
}

pub fn (mut p Pages) get_active_row_mut(y u32) &RowData {
	idx := p.active_start + int(y)
	return unsafe { &mut p.screen_rows[idx] }
}

pub fn (p Pages) is_dirty(pt PinOpts) bool {
	pin := p.pin(pt) or { return false }
	if int(pin.y) < p.screen_rows.len {
		return p.screen_rows[int(pin.y)].dirty
	}
	return false
}

pub fn (p Pages) pin(opts PinOpts) ?Pin {
	match opts.tag {
		.active {
			y := u32(p.active_start) + opts.y
			if y < u32(p.screen_rows.len) && opts.x < p.cols {
				return Pin{
					x: opts.x
					y: y
				}
			}
			return none
		}
		.screen {
			if opts.y < u32(p.screen_rows.len) && opts.x < p.cols {
				return Pin{
					x: opts.x
					y: opts.y
				}
			}
			return none
		}
		.viewport {
			y := opts.y // simplified: viewport = active
			if y < u32(p.screen_rows.len) && opts.x < p.cols {
				return Pin{
					x: opts.x
					y: y
				}
			}
			return none
		}
		.history {
			if opts.y < u32(p.active_start) {
				return Pin{
					x: opts.x
					y: opts.y
				}
			}
			return none
		}
	}
}

pub fn (p Pages) get_top_left(tag PointTag) Pin {
	match tag {
		.active {
			return Pin{ x: 0, y: u32(p.active_start) }
		}
		.screen {
			return Pin{ x: 0, y: 0 }
		}
		.viewport {
			return Pin{ x: 0, y: u32(p.active_start) }
		}
		.history {
			return Pin{ x: 0, y: 0 }
		}
	}
}

pub fn (p Pages) get_bottom_right(tag PointTag) ?Pin {
	match tag {
		.active {
			end := u32(p.active_start) + p.rows - 1
			return Pin{ x: p.cols - 1, y: end }
		}
		.screen {
			if p.screen_rows.len == 0 {
				return none
			}
			return Pin{ x: p.cols - 1, y: u32(p.screen_rows.len - 1) }
		}
		.viewport {
			end := u32(p.active_start) + p.rows - 1
			return Pin{ x: p.cols - 1, y: end }
		}
		.history {
			if p.active_start == 0 {
				return none
			}
			return Pin{ x: p.cols - 1, y: u32(p.active_start - 1) }
		}
	}
}

pub fn (p Pages) point_from_pin(tag PointTag, pn Pin) ?Point {
	match tag {
		.active {
			if pn.y < u32(p.active_start) {
				return none
			}
			rel_y := pn.y - u32(p.active_start)
			if rel_y >= p.rows {
				return none
			}
			return Point{
				viewport: ViewportPoint{
					x: pn.x
					y: rel_y
				}
			}
		}
		.screen {
			return Point{
				viewport: ViewportPoint{
					x: pn.x
					y: pn.y
				}
			}
		}
		else {
			return Point{
				viewport: ViewportPoint{
					x: pn.x
					y: pn.y
				}
			}
		}
	}
}

pub fn (mut p Pages) grow() ?bool {
	p.screen_rows << RowData.init(p.cols)
	return true
}

pub fn (mut p Pages) erase_row(pt PinOpts) ! {
	pin := p.pin(pt) or { return }
	idx := int(pin.y)
	if idx < p.screen_rows.len {
		// Shift rows up: remove the row and add a blank at the end of active area
		p.screen_rows.delete(idx)
		end := p.active_start + int(p.rows) - 1
		p.screen_rows.insert(end, RowData.init(p.cols))
		// Mark all rows dirty
		for mut row in p.screen_rows {
			row.dirty = true
		}
	}
}

pub fn (mut p Pages) erase_rows(tl_tag PointTag, bl_tag ?PointTag) {
	tl := p.get_top_left(tl_tag)
	bl := if bt := bl_tag {
		p.get_top_left(bt)
	} else {
		p.get_bottom_right(tl_tag) or { return }
	}
	start := int(tl.y)
	end := int(bl.y) + 1
	if start >= end || start >= p.screen_rows.len {
		return
	}
	count := end - start
	for _ in 0 .. count {
		if start < p.screen_rows.len {
			p.screen_rows.delete(start)
		}
	}
	// Adjust active_start if needed
	if start < p.active_start {
		deleted_before := if end <= p.active_start {
			count
		} else {
			p.active_start - start
		}
		p.active_start -= deleted_before
		if p.active_start < 0 {
			p.active_start = 0
		}
	}
}

pub fn (mut p Pages) scroll(behavior ScrollBehavior) {
	match behavior {
		.active {
			p.viewport = .active
		}
		.top {
			p.viewport = .offset
		}
		else {
			p.viewport = .active
		}
	}
}

pub fn (mut p Pages) scroll_clear() ! {
	// Move all active content to scrollback and clear
	for y in 0 .. int(p.rows) {
		idx := p.active_start + y
		if idx < p.screen_rows.len {
			p.screen_rows[idx] = RowData.init(p.cols)
		}
	}
}

pub fn (mut p Pages) reset() {
	p.screen_rows.clear()
	for _ in 0 .. p.rows {
		p.screen_rows << RowData.init(p.cols)
	}
	p.active_start = 0
	p.viewport = .active
}

pub fn (mut p Pages) resize(opts ResizeOpts) ! {
	// XTODO: Full reflow-aware resize is not implemented.
	// This is a simplified version that adjusts dimensions.
	old_cols := p.cols
	old_rows := p.rows
	p.cols = opts.cols
	p.rows = opts.rows

	// Resize columns in existing rows
	if opts.cols != old_cols {
		for mut row in p.screen_rows {
			if opts.cols > old_cols {
				// Extend cells
				for _ in old_cols .. opts.cols {
					row.cells << CellData{}
				}
			} else {
				// Truncate cells
				row.cells = row.cells[..int(opts.cols)].clone()
			}
		}
	}

	// Adjust row count
	if opts.rows > old_rows {
		// Add rows
		needed := int(opts.rows) - int(old_rows)
		for _ in 0 .. needed {
			p.screen_rows << RowData.init(p.cols)
		}
	} else if opts.rows < old_rows {
		// Remove rows from the bottom of active area if possible
		excess := int(old_rows) - int(opts.rows)
		active_end := p.active_start + int(old_rows)
		for i := 0; i < excess && active_end - 1 - i >= p.active_start; i++ {
			idx := active_end - 1 - i
			if idx < p.screen_rows.len {
				p.screen_rows.delete(idx)
			}
		}
	}
}

pub struct ResizeOpts {
pub:
	cols   u32
	rows   u32
	reflow bool
	cursor struct {
	pub:
		x u32
		y u32
	}
}

pub enum ScrollBehavior {
	active
	top
	pin_scroll
	row
	delta_row
	delta_prompt
}

pub struct PinOpts {
pub:
	tag PointTag = .active
	x   u32
	y   u32
}

pub struct ViewportPoint {
pub:
	x u32
	y u32
}

pub enum PointTag {
	active
	screen
	viewport
	history
}

pub struct Point {
pub:
	viewport ViewportPoint
}

pub fn (p Point) coord() ViewportPoint {
	return p.viewport
}

pub struct Pin {
pub mut:
	x u32
	y u32
}

pub fn (a Pin) eql(b Pin) bool {
	return a.x == b.x && a.y == b.y
}

pub fn (a Pin) before(b Pin) bool {
	if a.y < b.y {
		return true
	}
	if a.y == b.y {
		return a.x < b.x
	}
	return false
}

pub fn (p Pin) up(n u32) ?Pin {
	if p.y >= n {
		return Pin{ x: p.x, y: p.y - n }
	}
	return none
}

pub fn (p Pin) down(n u32) ?Pin {
	return Pin{ x: p.x, y: p.y + n }
}

pub fn (p Pin) left_wrap(n u32) Pin {
	mut x := p.x
	mut y := p.y
	if x >= n {
		x -= n
	} else {
		if y > 0 {
			y -= 1
		}
		x = 0
	}
	return Pin{ x: x, y: y }
}

pub fn (p Pin) right_wrap(n u32, cols u32) Pin {
	mut x := p.x + n
	mut y := p.y
	if x >= cols {
		x = 0
		y += 1
	}
	return Pin{ x: x, y: y }
}

pub fn (p Pin) mark_dirty(pages &Pages) {
	if int(p.y) < pages.screen_rows.len {
		unsafe {
			mut row := &pages.screen_rows[int(p.y)]
			row.dirty = true
		}
	}
}

pub struct Selection {
pub mut:
	start_pin Pin
	end_pin   Pin
	rectangle bool
}

pub fn Selection.init(start_p Pin, end_p Pin, rect bool) Selection {
	return Selection{
		start_pin: start_p
		end_pin: end_p
		rectangle: rect
	}
}

pub fn (s Selection) start() Pin {
	if s.start_pin.before(s.end_pin) {
		return s.start_pin
	}
	return s.end_pin
}

pub fn (s Selection) end() Pin {
	if s.start_pin.before(s.end_pin) {
		return s.end_pin
	}
	return s.start_pin
}

pub fn (s Selection) top_left() Pin {
	return s.start()
}

pub fn (s Selection) bottom_right() Pin {
	return s.end()
}

pub fn (a Selection) eql(b Selection) bool {
	return a.start_pin.eql(b.start_pin) && a.end_pin.eql(b.end_pin) && a.rectangle == b.rectangle
}

pub fn (s Selection) tracked() bool {
	return true // simplified: all selections are "tracked" in V
}

pub struct TerminalFlags {
pub mut:
	mouse_event         MouseEvent
	mouse_format        MouseFormat
	mouse_shift_capture bool
	focused             bool
	password_input      bool
}

pub enum MouseEvent {
	none
	x10
	normal
	button
	any
}

pub enum MouseFormat {
	x10
	utf8
	sgr
	urxvt
	sgr_pixels
}

pub struct Modes {
pub mut:
	values map[string]bool
}

pub fn (m Modes) get(mode ModeTag) bool {
	return m.values[mode.str()] or { false }
}

pub fn (mut m Modes) set(mode ModeTag, val bool) {
	m.values[mode.str()] = val
}

pub enum ModeTag {
	cursor_visible
	disable_keyboard
	bracketed_paste
	alternate_screen
	alternate_scroll
}

pub fn (m ModeTag) str() string {
	return match m {
		.cursor_visible { 'cursor_visible' }
		.disable_keyboard { 'disable_keyboard' }
		.bracketed_paste { 'bracketed_paste' }
		.alternate_screen { 'alternate_screen' }
		.alternate_scroll { 'alternate_scroll' }
	}
}

pub enum MouseShape {
	default
	text
	pointer
	crosshair
	move_
	not_allowed
}

pub struct Colors {
pub mut:
	background ColorEntry
	foreground ColorEntry
	palette    Palette
}

pub struct ColorEntry {
pub:
	r u8
	g u8
	b u8
}

pub fn (c ColorEntry) get() ColorEntry {
	return c
}

pub struct Palette {
pub:
	current [256]ColorEntry
}

pub struct Scrollbar {
pub:
	visible bool
	top     f64
	bottom  f64
}

pub fn (mut t Terminal) scroll_viewport(scroll_opts ScrollViewportOpts) ! {
	// stub: would adjust viewport scroll position
}

pub struct ScrollViewportOpts {
pub:
	delta  i32
	bottom bool
}

pub fn ScrollViewportOpts.top() ScrollViewportOpts {
	return ScrollViewportOpts{ delta: -999999 }
}

pub fn ScrollViewportOpts.bottom_val() ScrollViewportOpts {
	return ScrollViewportOpts{ bottom: true }
}

pub fn (t Terminal) cursor_is_at_prompt() bool {
	return true
}

pub fn (t Terminal) get_pwd() ?string {
	return none
}

pub fn (mut t Terminal) carriage_return() {
	// stub: moves cursor to column 0
}

pub fn (mut t Terminal) linefeed() ! {
	// stub: moves cursor down one line
}

pub fn (mut t Terminal) print_string(s string) ! {
	// stub: prints string at cursor position
}

pub fn (mut t Terminal) print(cp u32) ! {
	// stub: prints codepoint at cursor
}

pub fn (mut t Terminal) set_attribute(attr SgrAttribute) ! {
	// stub: sets text attribute
}

pub fn (t Terminal) plain_string() !string {
	return ''
}

// SgrAttribute represents an SGR (Select Graphic Rendition) attribute.
pub struct SgrAttribute {
pub:
	kind      SgrAttributeKind
	color_r   u8
	color_g   u8
	color_b   u8
	color_idx u8
	underline UnderlineStyle
}

pub enum SgrAttributeKind {
	unset
	bold
	reset_bold
	italic
	reset_italic
	faint
	underline_set
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
	fg_8
	bg_8
	reset_fg
	reset_bg
	bright_fg_8
	bright_bg_8
	fg_256
	bg_256
	underline_color
	underline_color_256
	reset_underline_color
	unknown
}

pub enum UnderlineStyle {
	none
	single
	double_
	dotted
	dashed
	curly
}

pub enum FgColor {
	red
	bright_red
}

// CellStyle represents the style applied to a cell.
pub struct CellStyle {
pub mut:
	fg_color    StyleColor
	bg_color    StyleColor
	underline_color StyleColor
	flags       StyleFlags
}

pub fn (s CellStyle) default() bool {
	return s.fg_color == .none && s.bg_color == .none
		&& s.underline_color == .none && s.flags.is_default()
}

pub fn (s CellStyle) bg_cell() ?CellData {
	if s.bg_color == .none {
		return none
	}
	return CellData{}
}

pub enum StyleColor {
	none
	palette
	rgb
}

pub struct StyleFlags {
pub mut:
	bold          bool
	italic        bool
	faint         bool
	underline     UnderlineStyle
	overline      bool
	blink         bool
	inverse       bool
	invisible     bool
	strikethrough bool
}

pub fn (f StyleFlags) is_default() bool {
	return !f.bold && !f.italic && !f.faint && f.underline == .none
		&& !f.overline && !f.blink && !f.inverse && !f.invisible && !f.strikethrough
}

// ProtectedMode from ansi.zig
pub enum ProtectedMode {
	off
	dec
	iso
}

// CharsetSlot from charsets.zig
pub enum CharsetSlot {
	g0
	g1
	g2
	g3
}

// Charset from charsets.zig
pub enum Charset {
	utf8
	ascii
	dec_special
	british
}

// Direction for iterating
pub enum Direction {
	right_down
	left_up
}

// PromptKind from osc.zig
pub enum PromptKind {
	initial
	right
	continuation
	secondary
}

// PromptRedraw from osc.zig
pub enum PromptRedraw {
	false_
	true_
	last
}

// Hyperlink stub
pub struct Hyperlink {
pub mut:
	uri string
	id  HyperlinkIdValue
}

pub union HyperlinkIdValue {
	explicit string
	implicit u32
}

pub fn (mut h Hyperlink) deinit() {
}

// KeyFlagStack from kitty.zig
pub struct KeyFlagStack {
pub mut:
	flags []u32
}

// Default style ID
pub const default_style_id = u32(0)

pub struct KittyKeyboard {
pub mut:
	mode KittyMode
}

pub fn (mut k KittyKeyboard) set(action KittyAction, val KittyMode) {
	k.mode = val
}

pub enum KittyAction {
	set
}

pub enum KittyMode {
	disabled
	normal
}
