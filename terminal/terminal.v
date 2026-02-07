module terminal

// Terminal represents the terminal emulator state.
pub struct Terminal {
pub mut:
	cols             u32
	rows             u32
	screens          Screens
	flags            TerminalFlags
	modes            Modes
	mouse_shape      MouseShape
	colors           Colors
	cursor_style     CursorStyle
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

pub struct Screen {
pub mut:
	cursor    Cursor
	selection ?Selection
	pages     Pages
	dirty     ScreenDirty
}

pub struct ScreenDirty {
pub mut:
	hyperlink_hover bool
	clear           bool
	preedit         bool
}

pub struct Cursor {
pub mut:
	x u32
	y u32
}

pub enum CursorStyle {
	block
	underline
	bar
}

pub struct Pages {
pub mut:
	cols u32
	rows u32
}

pub fn (p Pages) pin(opts PinOpts) ?Pin {
	return Pin{
		x: opts.viewport.x
		y: opts.viewport.y
	}
}

pub fn (p Pages) get_top_left(tag PointTag) Pin {
	return Pin{}
}

pub fn (p Pages) get_bottom_right(tag PointTag) ?Pin {
	return Pin{}
}

pub fn (p Pages) point_from_pin(tag PointTag, pin Pin) ?Point {
	return Point{
		viewport: ViewportPoint{
			x: pin.x
			y: pin.y
		}
	}
}

pub struct PinOpts {
pub:
	viewport ViewportPoint
}

pub struct ViewportPoint {
pub:
	x u32
	y u32
}

pub enum PointTag {
	viewport
	screen
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

pub struct Selection {
pub mut:
	start_pin Pin
	end_pin   Pin
	rectangle bool
}

pub fn Selection.init(start Pin, end Pin, rect bool) Selection {
	return Selection{
		start_pin: start
		end_pin: end
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

pub fn (s Selection) top_left(screen Screen) Pin {
	return s.start()
}

pub fn (s Selection) bottom_right(screen Screen) Pin {
	return s.end()
}

pub fn (a Selection) eql(b Selection) bool {
	return a.start_pin.eql(b.start_pin) && a.end_pin.eql(b.end_pin) && a.rectangle == b.rectangle
}

pub fn (mut s Screen) select(sel ?Selection) ! {
	s.selection = sel
}

pub fn (s Screen) selection_string(opts SelectionStringOpts) !string {
	return ''
}

pub struct SelectionStringOpts {
pub:
	sel  Selection
	trim bool
}

pub fn (s Screen) select_word(pin Pin) ?Selection {
	return Selection{
		start_pin: pin
		end_pin: pin
	}
}

pub fn (s Screen) select_word_between(a Pin, b Pin) ?Selection {
	return Selection{
		start_pin: a
		end_pin: b
	}
}

pub fn (s Screen) select_line(pin Pin) ?Selection {
	return Selection{
		start_pin: Pin{ x: 0, y: pin.y }
		end_pin: Pin{ x: 0, y: pin.y }
	}
}

pub struct TerminalFlags {
pub mut:
	mouse_event         MouseEvent
	mouse_format        MouseFormat
	mouse_shift_capture bool
	focused             bool
	password_input      bool
	dirty               ScreenDirty
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

pub fn (mut t Terminal) scroll_viewport(scroll ScrollViewportOpts) ! {
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

pub fn (mut t Terminal) set_attribute(attr Attribute) ! {
	// stub: sets text attribute
}

pub fn (t Terminal) plain_string() !string {
	return ''
}

pub struct Attribute {
pub:
	unset    bool
	bold     bool
	fg_8     ?FgColor
}

pub enum FgColor {
	red
	bright_red
}

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
