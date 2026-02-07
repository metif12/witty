// Surface represents a single terminal "surface". A terminal surface is
// a minimal "widget" where the terminal is drawn and responds to events
// such as keyboard and mouse. Each surface also creates and owns its pty
// session.
//
// The word "surface" is used because it is left to the higher level
// application runtime to determine if the surface is a window, a tab,
// a split, a preview pane in a larger window, etc. This struct doesn't care:
// it just draws and responds to events. The events come from the application
// runtime so the runtime can determine when and how those are delivered
// (i.e. with focus, without focus, and so on).
module main

import gg
import math
import time
import os

import terminal as _

// Minimum window size in cells.
const min_window_width_cells = u32(10)
const min_window_height_cells = u32(4)

// The maximum number of key tables that can be active at any given time.
const max_active_key_tables = 8

// Default DPI for font scaling.
const default_dpi = f32(72.0)

// The effect of an input event.
pub enum InputEffect {
	// Input was not handled and should be forwarded to the OS.
	ignored
	// Input was handled and consumed.
	consumed
	// Input resulted in a close event; surface pointers are now invalid.
	closed
}

// The action to report for a mouse event.
enum MouseReportAction {
	press
	release
	motion
}

// The portion of the screen to write for write_screen_file.
enum WriteScreenLoc {
	screen
	history
	selection
}

enum KeySequenceQueued {
	flush
	drop
}

enum KeySequenceMemory {
	retain
	free
}

// ScrollAmount keeps track of the scroll delta, normalized so that
// negative is down/left and positive is up/right.
struct ScrollAmount {
	delta i64
}

fn (s ScrollAmount) direction() ScrollDirection {
	return if s.delta < 0 { ScrollDirection.down_left } else { ScrollDirection.up_right }
}

fn (s ScrollAmount) magnitude() u64 {
	return if s.delta < 0 { u64(-s.delta) } else { u64(s.delta) }
}

enum ScrollDirection {
	down_left
	up_right
}

// Coordinate represents x/y in the viewport.
pub struct Coordinate {
pub mut:
	x u32
	y u32
}

fn (a Coordinate) eql(b Coordinate) bool {
	return a.x == b.x && a.y == b.y
}

// ContentScale represents the DPI content scale factors.
pub struct ContentScale {
pub:
	x f32
	y f32
}

// CursorPos represents a cursor position in surface coordinates.
pub struct CursorPos {
pub:
	x f64
	y f64
}

// ScreenSize represents the pixel dimensions of the screen area.
pub struct ScreenSize {
pub mut:
	width  u32
	height u32
}

fn (a ScreenSize) equals(b ScreenSize) bool {
	return a.width == b.width && a.height == b.height
}

// CellSize represents the pixel dimensions of a single cell.
pub struct CellSize {
pub mut:
	width  u32
	height u32
}

// Padding represents the padding around the terminal grid.
pub struct Padding {
pub mut:
	top    u32
	bottom u32
	left   u32
	right  u32
}

// GridSize represents the terminal grid dimensions in cells.
pub struct GridSize {
pub:
	columns u32
	rows    u32
}

// Size holds all the sizing information for the surface.
pub struct Size {
pub mut:
	screen  ScreenSize
	cell    CellSize
	padding Padding
}

fn (s Size) grid() GridSize {
	usable_w := if s.screen.width > s.padding.left + s.padding.right {
		s.screen.width - s.padding.left - s.padding.right
	} else {
		u32(0)
	}
	usable_h := if s.screen.height > s.padding.top + s.padding.bottom {
		s.screen.height - s.padding.top - s.padding.bottom
	} else {
		u32(0)
	}
	cols := if s.cell.width > 0 { usable_w / s.cell.width } else { u32(0) }
	rows := if s.cell.height > 0 { usable_h / s.cell.height } else { u32(0) }
	return GridSize{
		columns: cols
		rows: rows
	}
}

fn (s Size) terminal_width() u32 {
	g := s.grid()
	return g.columns * s.cell.width
}

fn (mut s Size) balance_padding(explicit Padding) {
	g := s.grid()
	total_w := g.columns * s.cell.width
	total_h := g.rows * s.cell.height
	usable_w := if s.screen.width > explicit.left + explicit.right {
		s.screen.width - explicit.left - explicit.right
	} else {
		u32(0)
	}
	usable_h := if s.screen.height > explicit.top + explicit.bottom {
		s.screen.height - explicit.top - explicit.bottom
	} else {
		u32(0)
	}
	extra_w := if usable_w > total_w { usable_w - total_w } else { u32(0) }
	extra_h := if usable_h > total_h { usable_h - total_h } else { u32(0) }
	s.padding = Padding{
		top: explicit.top + extra_h / 2
		bottom: explicit.bottom + (extra_h - extra_h / 2)
		left: explicit.left + extra_w / 2
		right: explicit.right + (extra_w - extra_w / 2)
	}
}

// FontMetrics holds font measurement data.
pub struct FontMetrics {
pub mut:
	cell_width    u32
	cell_height   u32
	cell_baseline u32
}

// DesiredSize represents the desired font size with DPI info.
pub struct DesiredSize {
pub mut:
	points f32
	xdpi   u32
	ydpi   u32
}

// Mouse state for the surface.
pub struct Mouse {
pub mut:
	// Last tracked mouse button state by button.
	click_state [10]MouseButtonState

	// Last mods state when the last mouse button was pressed/released.
	mods gg.Modifier

	// Pin at which the left mouse click happened.
	left_click_pin ?Pin

	// Starting xpos/ypos of the left click.
	left_click_xpos f64
	left_click_ypos f64

	// Click count for double/triple clicks.
	left_click_count u8
	left_click_time  time.Time

	// Last x/y sent for mouse reports.
	event_point ?Coordinate

	// Pressure stage for the mouse.
	pressure_stage MousePressureStage = .none_

	// Pending scroll amounts for high-precision scrolls.
	pending_scroll_x f64
	pending_scroll_y f64

	// True if the mouse is hidden.
	hidden bool

	// True if the mouse position is currently over a link.
	over_link bool

	// Last x/y in the cursor position for links.
	link_point ?Coordinate
}

pub enum MouseButtonState {
	press
	release
}

pub enum MousePressureStage {
	none_
	light
	deep
}

// Keyboard state for the surface.
pub struct Keyboard {
pub mut:
	// Currently active key sequence set.
	sequence_set ?&BindingSet

	// Queued keys when in the middle of a sequenced binding.
	sequence_queued []WriteReq

	// Stack of active key tables.
	table_stack []KeyTableEntry

	// Last handled binding trigger hash.
	last_trigger ?u64
}

struct KeyTableEntry {
	set  &BindingSet = unsafe { nil }
	once bool
}

// ---- Placeholder dependency types (stub implementations) ----
// These provide the interface surface.v needs. Full implementations
// would live in separate modules (terminal/, renderer/, termio/, etc.).

pub struct App {
pub mut:
	font_grid_set          FontGridSet
	config_conditional_state ConditionalState
	first                  bool = true
	last_notification_time   ?time.Time
	last_notification_digest u64
}

pub struct FontGridSet {}

fn (f FontGridSet) ref(config &DerivedFontConfig, size DesiredSize) !(FontGridKey, &FontGrid) {
	return FontGridKey{}, &FontGrid{
		metrics: FontMetrics{
			cell_width: if size.xdpi > 0 { u32(size.points) } else { u32(10) }
			cell_height: if size.ydpi > 0 { u32(size.points * 2) } else { u32(20) }
			cell_baseline: if size.ydpi > 0 { u32(size.points * 1.6) } else { u32(16) }
		}
	}
}

fn (f FontGridSet) deref(key FontGridKey) {
}

pub struct FontGridKey {}

pub struct FontGrid {
pub:
	metrics FontMetrics
}

fn (g FontGrid) cell_size() CellSize {
	return CellSize{
		width: g.metrics.cell_width
		height: g.metrics.cell_height
	}
}

pub struct RuntimeApp {}

fn (r RuntimeApp) perform_action(action AppAction) !bool {
	// Stub: in a real runtime, this dispatches to the windowing system.
	return false
}

pub struct AppAction {
pub:
	kind   AppActionKind
	target &Surface = unsafe { nil }
}

pub enum AppActionKind {
	set_title
	cell_size
	size_limit
	initial_size
	mouse_shape
	mouse_visibility
	mouse_over_link
	color_change
	renderer_health
	scrollbar
	present_terminal
	secure_input
	ring_bell
	progress_report
	command_finished
	desktop_notification
	reload_config
	config_change
	pwd
	open_url
	show_child_exited
	key_sequence
	key_table
	search_total
	search_selected
	close_surface
	close_window
	close_tab
}

pub struct RuntimeSurface {}

fn (r RuntimeSurface) close(confirm bool) {
}

fn (r RuntimeSurface) get_content_scale() !ContentScale {
	return ContentScale{ x: 1.0, y: 1.0 }
}

fn (r RuntimeSurface) get_size() !ScreenSize {
	return ScreenSize{ width: 800, height: 600 }
}

fn (r RuntimeSurface) get_cursor_pos() !CursorPos {
	return CursorPos{}
}

fn (r RuntimeSurface) get_title() ?string {
	return none
}

fn (r RuntimeSurface) set_clipboard(contents string, confirm bool) ! {
}

fn (r RuntimeSurface) supports_clipboard_selection() bool {
	return false
}

fn (r RuntimeSurface) clipboard_request(kind ClipboardRequestKind) ! {
}

pub enum ClipboardRequestKind {
	osc_52_read
	paste
}

pub struct Renderer {
pub mut:
	initialized bool
}

fn (mut r Renderer) draw_frame(force bool) ! {
	// Stub: in gg-based rendering, this calls gg_ctx.begin()/end()
}

fn (mut r Renderer) deinit() {
	r.initialized = false
}

fn (r Renderer) thread_enter() ! {
}

pub struct RendererState {
pub mut:
	terminal  &Terminal = unsafe { nil }
	preedit   ?Preedit
	mouse     RendererMouseState
	inspector ?&Inspector
}

pub struct RendererMouseState {
pub mut:
	point ?Coordinate
	mods  gg.Modifier
}

pub struct Preedit {
pub:
	codepoints []PreeditCodepoint
}

pub struct PreeditCodepoint {
pub:
	codepoint u32
	wide      bool
}

pub fn (p Preedit) width() int {
	mut w := 0
	for cp in p.codepoints {
		w += if cp.wide { 2 } else { 1 }
	}
	return w
}

pub struct RendererThread {
pub mut:
	wakeup RendererWakeup
}

fn (mut t RendererThread) deinit() {
}

pub struct RendererWakeup {}

fn (w RendererWakeup) notify() ! {
}

// Terminal state.
pub struct Terminal {
pub mut:
	cols         u32
	rows         u32
	flags        TermFlags
	modes        TermModes
	mouse_shape  TermMouseShape
	cursor       TermCursor
	selection    ?TermSelection
	pwd          ?string
	kitty_keyboard KittyKeyboard
}

pub struct TermCursor {
pub mut:
	x u32
	y u32
}

pub struct TermFlags {
pub mut:
	mouse_event         TermMouseEvent = .none_
	mouse_format        TermMouseFormat = .x10
	mouse_shift_capture bool
	focused             bool
	password_input      bool
	dirty               TermDirty
}

pub struct TermDirty {
pub mut:
	clear   bool
	preedit bool
}

pub enum TermMouseEvent {
	none_
	x10
	normal
	button
	any
}

pub enum TermMouseFormat {
	x10
	utf8
	sgr
	urxvt
	sgr_pixels
}

pub enum TermMouseShape {
	default_
	text
	pointer
}

pub struct TermModes {
pub mut:
	cursor_visible   bool = true
	disable_keyboard bool
	bracketed_paste  bool
	alternate_screen bool
	alternate_scroll bool
}

pub struct KittyKeyboard {
pub mut:
	enabled bool
}

pub struct TermSelection {
pub mut:
	start_pin Pin
	end_pin   Pin
	rectangle bool
}

fn (a TermSelection) eql(b TermSelection) bool {
	return a.start_pin.eql(b.start_pin) && a.end_pin.eql(b.end_pin) && a.rectangle == b.rectangle
}

fn (s TermSelection) start() Pin {
	if s.start_pin.before(s.end_pin) {
		return s.start_pin
	}
	return s.end_pin
}

fn (s TermSelection) top_left() Pin {
	return s.start()
}

fn (s TermSelection) bottom_right() Pin {
	if s.start_pin.before(s.end_pin) {
		return s.end_pin
	}
	return s.start_pin
}

fn (mut t Terminal) scroll_viewport_delta(delta i32) ! {
	// Stub: adjusts viewport scroll position by delta lines.
}

fn (mut t Terminal) scroll_viewport_bottom() ! {
	// Stub: scrolls viewport to the bottom.
}

fn (t Terminal) cursor_is_at_prompt() bool {
	// Stub: checks shell-integration prompt markers.
	return true
}

fn (t Terminal) get_pwd() ?string {
	return t.pwd
}

fn (mut t Terminal) carriage_return() {
	t.cursor.x = 0
}

fn (mut t Terminal) linefeed() ! {
	t.cursor.y += 1
}

fn (mut t Terminal) print_string(s string) ! {
	// Stub: writes string at cursor position.
	t.cursor.x += u32(s.len)
}

fn (mut t Terminal) select_at(sel ?TermSelection) ! {
	t.selection = sel
}

fn (t Terminal) selection_string() string {
	// Stub: returns text covered by current selection.
	return ''
}

fn (t Terminal) select_word(pin Pin) ?TermSelection {
	return TermSelection{
		start_pin: pin
		end_pin: pin
	}
}

fn (t Terminal) select_word_between(a Pin, b Pin) ?TermSelection {
	return TermSelection{ start_pin: a, end_pin: b }
}

fn (t Terminal) select_line(pin Pin) ?TermSelection {
	return TermSelection{
		start_pin: Pin{ x: 0, y: pin.y }
		end_pin: Pin{ x: t.cols, y: pin.y }
	}
}

fn (t Terminal) viewport_pin(x u32, y u32) ?Pin {
	if x >= t.cols || y >= t.rows {
		return none
	}
	return Pin{ x: x, y: y }
}

pub struct Pin {
pub mut:
	x u32
	y u32
}

fn (a Pin) eql(b Pin) bool {
	return a.x == b.x && a.y == b.y
}

fn (a Pin) before(b Pin) bool {
	if a.y < b.y {
		return true
	}
	return a.y == b.y && a.x < b.x
}

pub struct TermIO {
pub mut:
	terminal Terminal
}

fn (t TermIO) queue_message(msg IOMessage) {
	// Stub: queues a message for the IO thread.
}

fn (mut t TermIO) deinit() {
}

pub struct IOThread {
pub mut:
	running bool
}

fn (mut t IOThread) deinit() {
	t.running = false
}

pub struct Inspector {}

fn (mut i Inspector) deinit() {
}

fn (i Inspector) record_key_event(ev KeyEvent) bool {
	return false
}

pub struct BindingSet {}

fn (s BindingSet) get_event(event KeyEvent) ?BindingEntry {
	return none
}

pub struct BindingEntry {
pub:
	kind BindingEntryKind
}

pub enum BindingEntryKind {
	leader
	leaf
	leaf_chained
}

pub struct WriteReq {
pub:
	data []u8
}

fn (w WriteReq) deinit() {
}

pub struct Config {}

pub struct ConditionalState {
pub mut:
	theme Theme
}

pub enum Theme {
	light
	dark
}

pub enum ColorScheme {
	light
	dark
}

// IMEPos represents the position and size for the Input Method Editor.
pub struct IMEPos {
pub:
	x      f64
	y      f64
	width  f64
	height f64
}

// Text represents text read from the terminal with viewport metadata.
pub struct Text {
pub mut:
	text     string
	viewport ?TextViewport
}

pub struct TextViewport {
pub:
	tl_px_x      f64
	tl_px_y      f64
	offset_start u32
	offset_len   u32
}

// Link represents a detected link at a position in the terminal.
struct Link {
	action    LinkAction
	selection TermSelection
}

pub enum LinkAction {
	open
	open_osc8
}

pub enum LinkHighlight {
	always
	hover
	always_mods
	hover_mods
}

// DerivedConfig holds the configuration derived from the main config.
pub struct DerivedConfig {
pub mut:
	original_font_size             f32
	abnormal_command_exit_runtime_ms u32
	clipboard_read                 ClipboardAccess
	clipboard_write                ClipboardAccess
	clipboard_trim_trailing_spaces bool
	clipboard_paste_protection     bool
	clipboard_paste_bracketed_safe bool
	copy_on_select                 CopyOnSelect
	confirm_close_surface          ConfirmCloseSurface
	cursor_click_to_move           bool
	desktop_notifications          bool
	mouse_interval                 u64
	mouse_hide_while_typing        bool
	mouse_reporting                bool
	mouse_shift_capture            MouseShiftCapture
	selection_clear_on_copy        bool
	selection_clear_on_typing      bool
	selection_word_chars           []u32
	vt_kam_allowed                 bool
	wait_after_command             bool
	window_padding_top             u32
	window_padding_bottom          u32
	window_padding_left            u32
	window_padding_right           u32
	window_padding_balance         bool
	window_height                  u32
	window_width                   u32
	title                          ?string
	title_report                   bool
	links                          []DerivedConfigLink
	link_previews                  LinkPreviews
	scroll_to_bottom_keystroke     bool
	font                           DerivedFontConfig
}

pub enum LinkPreviews {
	true_
	false_
}

pub struct DerivedFontConfig {}

pub struct DerivedConfigLink {
pub:
	action    LinkAction
	highlight LinkHighlight
}

pub enum ClipboardAccess {
	allow
	ask
	deny
}

pub enum CopyOnSelect {
	false_
	true_
	clipboard
}

pub enum ConfirmCloseSurface {
	always
	false_
	true_
}

pub enum MouseShiftCapture {
	never
	always
	false_
	true_
}

pub fn DerivedConfig.from_config(config &Config) !DerivedConfig {
	// Derives surface config from the main Config. In a full implementation
	// this copies fields, compiles link regexes, clones keybinds, etc.
	return DerivedConfig{
		clipboard_read: .allow
		clipboard_write: .allow
		clipboard_paste_protection: true
		clipboard_paste_bracketed_safe: true
		copy_on_select: .false_
		confirm_close_surface: .true_
		desktop_notifications: true
		mouse_hide_while_typing: true
		mouse_reporting: true
		mouse_shift_capture: .false_
		selection_clear_on_copy: true
		selection_clear_on_typing: true
		title_report: true
		scroll_to_bottom_keystroke: true
	}
}

pub fn (mut self DerivedConfig) deinit() {
	// Cleanup compiled regexes and cloned keybinds.
	self.links = []
	self.selection_word_chars = []
}

fn (self &DerivedConfig) scaled_padding(x_dpi f32, y_dpi f32) Padding {
	top := u32(math.floor(f32(self.window_padding_top) * y_dpi / 72.0))
	bottom := u32(math.floor(f32(self.window_padding_bottom) * y_dpi / 72.0))
	left := u32(math.floor(f32(self.window_padding_left) * x_dpi / 72.0))
	right := u32(math.floor(f32(self.window_padding_right) * x_dpi / 72.0))
	return Padding{
		top: top
		bottom: bottom
		left: left
		right: right
	}
}

pub struct IOMessage {
pub:
	kind IOMessageKind
}

pub enum IOMessageKind {
	write_small
	write_stable
	write_alloc
	resize
	inspector_
	change_config
	focused
	color_scheme_report
	selection_scroll
	visible
}

pub struct SurfaceMessage {
pub:
	kind SurfaceMessageKind
}

pub enum SurfaceMessageKind {
	change_config
	set_title
	report_title
	color_change
	set_mouse_shape
	clipboard_read
	clipboard_write
	pwd_change
	close
	child_exited
	desktop_notification
	renderer_health
	scrollbar
	present_surface
	password_input
	ring_bell
	progress_report
	selection_scroll_tick
	start_command
	stop_command
	search_total
	search_selected
}

pub struct BindingAction {
pub:
	kind BindingActionKind
}

pub enum BindingActionKind {
	none_
	ignore
	csi
	esc
	text
	copy_to_clipboard
	paste_from_clipboard
	increase_font_size
	decrease_font_size
	reset_font_size
	scroll_page_up
	scroll_page_down
	scroll_to_top
	scroll_to_bottom
	close_surface
	close_window
	close_tab
	new_window
	new_tab
	toggle_fullscreen
	inspector_toggle
	deactivate_key_table
	open_url
	write_screen_file
}

pub struct BindingFlags {
pub:
	consumed    bool
	global      bool
	all         bool
	performable bool
}

pub struct KeyEvent {
pub mut:
	key    gg.KeyCode
	action KeyAction
	mods   gg.Modifier
	utf8   string
}

pub fn (e KeyEvent) binding_hash() u64 {
	mut h := u64(17)
	h = h * 31 + u64(e.key)
	h = h * 31 + u64(e.mods)
	return h
}

pub enum KeyAction {
	press
	repeat
	release
}

fn key_is_modifier(k gg.KeyCode) bool {
	return k in [
		.left_shift, .right_shift,
		.left_control, .right_control,
		.left_alt, .right_alt,
		.left_super, .right_super,
	]
}

fn closing_action(action BindingAction) bool {
	return action.kind in [.close_surface, .close_window, .close_tab]
}

// ---- Surface struct ----

pub struct Surface {
pub mut:
	// The gg rendering context for drawing.
	gg_ctx &gg.Context = unsafe { nil }

	app        &App            = unsafe { nil }
	rt_app     &RuntimeApp     = unsafe { nil }
	rt_surface &RuntimeSurface = unsafe { nil }

	font_grid_key      FontGridKey
	font_size          DesiredSize
	font_size_adjusted bool
	font_metrics       FontMetrics

	renderer        Renderer
	renderer_state  RendererState
	renderer_thread RendererThread

	mouse    Mouse
	keyboard Keyboard

	io        TermIO
	io_thread IOThread

	inspector ?&Inspector

	size   Size
	config DerivedConfig

	config_conditional_state ConditionalState

	child_exited bool
	focused      bool = true

	selection_scroll_active bool
	readonly               bool

	command_timer  ?time.Time
	last_bell_time ?time.Time

	pressed_key          ?KeyEvent
	last_binding_trigger u64
}

// has_terminal returns true if the terminal pointer is initialized.
fn (self &Surface) has_terminal() bool {
	return unsafe { self.renderer_state.terminal != nil }
}

// ---- Surface methods ----

// init creates a new surface. This must be called from the main thread.
pub fn (mut self Surface) init(config &Config, app &App, rt_app &RuntimeApp, rt_surface &RuntimeSurface) ! {
	unsafe {
		self.app = app
		self.rt_app = rt_app
		self.rt_surface = rt_surface
	}

	// Derive our config
	mut derived_config := DerivedConfig.from_config(config)!

	// Get content scale for DPI
	content_scale := rt_surface.get_content_scale()!
	x_dpi := content_scale.x * default_dpi
	y_dpi := content_scale.y * default_dpi

	// Determine font size with DPI
	self.font_size = DesiredSize{
		points: derived_config.original_font_size
		xdpi: u32(x_dpi)
		ydpi: u32(y_dpi)
	}

	// Get font grid (shared across surfaces with same config)
	font_grid_key, font_grid := app.font_grid_set.ref(&derived_config.font, self.font_size)!
	self.font_grid_key = font_grid_key
	self.font_metrics = font_grid.metrics

	// Build our size struct with screen size, cell size, and padding
	surface_size := rt_surface.get_size()!
	self.size = Size{
		screen: ScreenSize{
			width: surface_size.width
			height: surface_size.height
		}
		cell: font_grid.cell_size()
	}

	// Apply padding
	explicit := derived_config.scaled_padding(x_dpi, y_dpi)
	if derived_config.window_padding_balance {
		self.size.balance_padding(explicit)
	} else {
		self.size.padding = explicit
	}

	// Store derived config
	self.config = derived_config
	self.config_conditional_state = app.config_conditional_state

	// Initialize renderer state with terminal reference
	self.renderer_state = RendererState{
		terminal: &self.io.terminal
	}

	// Initialize renderer
	self.renderer = Renderer{ initialized: true }

	// Report initial cell size
	self.rt_app.perform_action(AppAction{
		kind: .cell_size
		target: &self
	})!

	// Report size limits
	self.rt_app.perform_action(AppAction{
		kind: .size_limit
		target: &self
	})!

	// Call resize to finalize setup
	self.resize(self.size.screen)!

	// Compute initial window size if configured
	self.recompute_initial_size() or {}

	// Set title if configured
	if _ := self.config.title {
		self.rt_app.perform_action(AppAction{
			kind: .set_title
			target: &self
		})!
	}
}

// deinit cleans up the surface and all its resources.
pub fn (mut self Surface) deinit() {
	// Stop renderer thread
	self.renderer_thread.deinit()
	self.renderer.deinit()

	// Stop IO thread
	self.io_thread.deinit()
	self.io.deinit()

	// Clean up inspector
	if mut insp := self.inspector {
		insp.deinit()
		self.inspector = none
	}

	// Clean up keyboard state
	for req in self.keyboard.sequence_queued {
		req.deinit()
	}
	self.keyboard.sequence_queued.clear()
	self.keyboard.table_stack.clear()

	// Release font grid
	self.app.font_grid_set.deref(self.font_grid_key)

	// Clean up config
	self.config.deinit()
}

// close triggers the runtime to start the close process.
pub fn (mut self Surface) close() {
	self.rt_surface.close(self.needs_confirm_quit())
}

// needs_confirm_quit returns true if the surface requires confirmation to quit.
pub fn (self &Surface) needs_confirm_quit() bool {
	if self.readonly {
		return true
	}
	if self.child_exited {
		return false
	}
	return match self.config.confirm_close_surface {
		.always { true }
		.false_ { false }
		.true_ {
			// Check if cursor is at a shell prompt (process likely idle).
			if !self.has_terminal() {
				true
			} else {
				!self.renderer_state.terminal.cursor_is_at_prompt()
			}
		}
	}
}

// handle_message handles mailbox messages to this specific surface.
pub fn (mut self Surface) handle_message(msg SurfaceMessage) ! {
	match msg.kind {
		.change_config {
			self.update_config(&Config{})!
		}
		.set_title {
			if self.config.title != none {
				return
			}
			self.rt_app.perform_action(AppAction{
				kind: .set_title
				target: &self
			})!
		}
		.report_title {
			if !self.config.title_report {
				return
			}
			title := self.rt_surface.get_title() or { '' }
			data := '\x1b]l${title}\x1b\\'
			self.queue_io(IOMessage{ kind: .write_alloc })
			_ = data
		}
		.color_change {
			self.rt_app.perform_action(AppAction{
				kind: .color_change
				target: &self
			})!
		}
		.set_mouse_shape {
			self.rt_app.perform_action(AppAction{
				kind: .mouse_shape
				target: &self
			})!
		}
		.clipboard_read {
			if self.config.clipboard_read == .deny {
				return
			}
			self.start_clipboard_request(.osc_52_read)!
		}
		.clipboard_write {
			self.clipboard_write('', .paste)!
		}
		.pwd_change {
			self.rt_app.perform_action(AppAction{
				kind: .pwd
				target: &self
			})!
		}
		.close {
			self.close()
		}
		.child_exited {
			self.child_exited_handler(0, 0)
		}
		.desktop_notification {
			if !self.config.desktop_notifications {
				return
			}
			self.show_desktop_notification('', '')!
		}
		.renderer_health {
			self.update_renderer_health(0)
		}
		.scrollbar {
			self.update_scrollbar(0)
		}
		.present_surface {
			self.present_surface()!
		}
		.password_input {
			self.password_input(false)!
		}
		.ring_bell {
			now := time.now()
			if last := self.last_bell_time {
				// Rate-limit bell to at most once per 100ms
				if now - last < time.Duration(100 * time.millisecond) {
					return
				}
			}
			self.last_bell_time = now
			self.rt_app.perform_action(AppAction{
				kind: .ring_bell
				target: &self
			})!
		}
		.progress_report {
			self.rt_app.perform_action(AppAction{
				kind: .progress_report
				target: &self
			})!
		}
		.selection_scroll_tick {
			self.selection_scroll_tick()!
		}
		.start_command {
			self.command_timer = time.now()
		}
		.stop_command {
			if _ := self.command_timer {
				self.command_timer = none
				self.rt_app.perform_action(AppAction{
					kind: .command_finished
					target: &self
				})!
			}
		}
		.search_total {
			self.rt_app.perform_action(AppAction{
				kind: .search_total
				target: &self
			})!
		}
		.search_selected {
			self.rt_app.perform_action(AppAction{
				kind: .search_selected
				target: &self
			})!
		}
	}
}

// draw forces the surface to render a frame using gg.
pub fn (mut self Surface) draw() ! {
	self.renderer.draw_frame(true)!
}

// activate_inspector begins collecting inspection data.
pub fn (mut self Surface) activate_inspector() ! {
	if self.inspector != none {
		return
	}
	mut insp := &Inspector{}
	self.inspector = insp

	// Put the inspector onto the render state
	self.renderer_state.inspector = self.inspector

	// Notify components that inspector is active
	self.renderer_thread.wakeup.notify()!
	self.queue_io(IOMessage{ kind: .inspector_ })
}

// deactivate_inspector stops collecting inspection data.
pub fn (mut self Surface) deactivate_inspector() {
	mut insp := self.inspector or { return }

	// Remove from render state
	self.renderer_state.inspector = none

	// Notify components
	self.renderer_thread.wakeup.notify() or {}
	self.queue_io(IOMessage{ kind: .inspector_ })

	// Cleanup
	insp.deinit()
	self.inspector = none
}

// update_config updates the surface configuration at runtime.
pub fn (mut self Surface) update_config(config &Config) ! {
	derived := DerivedConfig.from_config(config)!
	self.config.deinit()
	self.config = derived

	// If mouse hiding was disabled but mouse is hidden, show it
	if !self.config.mouse_hide_while_typing && self.mouse.hidden {
		self.show_mouse()
	}

	// Clear any active key sequence
	self.end_key_sequence(.drop, .free)

	// Deactivate all key tables (pointers may be stale after config change)
	self.deactivate_all_key_tables() or {}

	// Update font size (preserving manual adjustments)
	font_size := if self.font_size_adjusted {
		self.font_size
	} else {
		mut s := self.font_size
		s.points = self.config.original_font_size
		s
	}
	self.set_font_size(font_size)!

	// Notify renderer and IO of config change
	self.renderer_thread.wakeup.notify()!
	self.queue_io(IOMessage{ kind: .change_config })

	// Notify runtime of config change
	if _ := self.config.title {
		self.rt_app.perform_action(AppAction{
			kind: .set_title
			target: &self
		})!
	}
	self.rt_app.perform_action(AppAction{
		kind: .config_change
		target: &self
	})!
}

// has_selection returns true if the terminal has a selection.
pub fn (self &Surface) has_selection() bool {
	return self.renderer_state.terminal.selection != none
}

// selection_string returns the selected text.
pub fn (self &Surface) selection_string() ?string {
	_ := self.renderer_state.terminal.selection or { return none }
	text := self.renderer_state.terminal.selection_string()
	if text.len == 0 {
		return none
	}
	return text
}

// pwd returns the current working directory of the terminal.
pub fn (self &Surface) pwd() ?string {
	return self.renderer_state.terminal.get_pwd()
}

// ime_point returns the x/y coordinate of where the IME keyboard should be rendered.
pub fn (self &Surface) ime_point() IMEPos {
	cursor := self.renderer_state.terminal.cursor
	preedit_width := if p := self.renderer_state.preedit {
		u32(p.width())
	} else {
		u32(0)
	}

	content_scale := self.rt_surface.get_content_scale() or {
		ContentScale{ x: 1.0, y: 1.0 }
	}

	// X: cursor column * cell width + padding, centered in cell, scaled
	mut x := f64(cursor.x * self.size.cell.width + self.size.padding.left)
	x += f64(self.size.cell.width) / 2.0
	x /= content_scale.x

	// Y: cursor row * cell height + padding + full cell height - baseline, scaled
	mut y := f64(cursor.y * self.size.cell.height + self.size.padding.top)
	y += f64(self.size.cell.height)
	y /= content_scale.y

	// Height is one cell
	height := f64(self.size.cell.height) / content_scale.y

	// Width is preedit width clamped to remaining screen space
	mut w := f64(preedit_width * self.size.cell.width)
	term_w := f64(self.size.terminal_width())
	x_offset := f64((cursor.x + 1) * self.size.cell.width)
	max_w := term_w - x_offset
	if w > max_w {
		w = max_w
	}

	return IMEPos{
		x: x
		y: y
		width: w
		height: height
	}
}

// set_font_size changes the font size. Must be called from the main thread.
pub fn (mut self Surface) set_font_size(size DesiredSize) ! {
	self.font_size = size

	// Get a new font grid for this size
	font_grid_key, font_grid := self.app.font_grid_set.ref(&self.config.font, self.font_size)!

	// Update cell size
	self.set_cell_size(font_grid.cell_size())!

	// Notify renderer of new font grid
	self.renderer_thread.wakeup.notify()!

	// Swap our font grid key
	old_key := self.font_grid_key
	self.font_grid_key = font_grid_key
	self.font_metrics = font_grid.metrics

	// Release old grid
	self.app.font_grid_set.deref(old_key)

	// Schedule render
	self.queue_render()!
}

// queue_render queues a render operation with the renderer thread.
fn (mut self Surface) queue_render() ! {
	self.renderer_thread.wakeup.notify()!
}

// size_callback is called when the surface size changes.
pub fn (mut self Surface) size_callback(width u32, height u32) ! {
	new_screen := ScreenSize{
		width: width
		height: height
	}
	if self.size.screen.equals(new_screen) {
		return
	}
	self.resize(new_screen)!
}

fn (mut self Surface) resize(size ScreenSize) ! {
	self.size.screen = size
	self.balance_padding_if_needed()

	grid_size := self.size.grid()
	if grid_size.columns < 5
		&& (self.size.padding.left > 0 || self.size.padding.right > 0) {
		// WARNING: very small terminal grid detected with padding set.
	}
	if grid_size.rows < 2
		&& (self.size.padding.top > 0 || self.size.padding.bottom > 0) {
		// WARNING: very small terminal grid detected with padding set.
	}

	// Notify IO thread of resize
	self.queue_io(IOMessage{ kind: .resize })
}

fn (mut self Surface) balance_padding_if_needed() {
	if !self.config.window_padding_balance {
		return
	}
	content_scale := self.rt_surface.get_content_scale() or {
		return
	}
	x_dpi := content_scale.x * default_dpi
	y_dpi := content_scale.y * default_dpi
	self.size.balance_padding(self.config.scaled_padding(x_dpi, y_dpi))
}

// preedit_callback sets the preedit state for character input (dead keys, IME).
pub fn (mut self Surface) preedit_callback(preedit ?string) ! {
	// Clear selection when preedit changes (if configured)
	if self.renderer_state.preedit != none || preedit != none {
		if self.config.selection_clear_on_typing {
			self.set_selection(none)!
		}
	}

	// Always clear prior preedit
	self.renderer_state.preedit = none

	// Mark preedit dirty
	self.renderer_state.terminal.flags.dirty.preedit = true

	// If no text, just queue render to clear previous preedit display
	text := preedit or {
		self.queue_render()!
		return
	}

	// Convert UTF-8 text to codepoints
	mut codepoints := []PreeditCodepoint{}
	for ch in text.runes() {
		cp := u32(ch)
		// Simple width detection: CJK ranges are wide
		wide := (cp >= 0x1100 && cp <= 0x115f) || (cp >= 0x2e80 && cp <= 0x9fff)
			|| (cp >= 0xac00 && cp <= 0xd7a3) || (cp >= 0xf900 && cp <= 0xfaff)
			|| (cp >= 0xfe10 && cp <= 0xfe6f) || (cp >= 0xff01 && cp <= 0xff60)
			|| (cp >= 0x20000 && cp <= 0x2fffd) || (cp >= 0x30000 && cp <= 0x3fffd)
		codepoints << PreeditCodepoint{ codepoint: cp, wide: wide }
	}

	if codepoints.len == 0 {
		self.queue_render()!
		return
	}

	self.renderer_state.preedit = Preedit{ codepoints: codepoints }
	self.queue_render()!
}

// key_event_is_binding returns binding flags if the key event would trigger a keybinding.
pub fn (mut self Surface) key_event_is_binding(event KeyEvent) ?BindingFlags {
	if event.action == .release {
		return none
	}

	// Check active key sequence set
	if seq_set := self.keyboard.sequence_set {
		_ := seq_set.get_event(event) or { return none }
		return BindingFlags{}
	}

	// Check active key tables (inner to outer)
	for i := self.keyboard.table_stack.len - 1; i >= 0; i-- {
		if _ := self.keyboard.table_stack[i].set.get_event(event) {
			return BindingFlags{}
		}
	}

	return none
}

// key_callback handles key events including keybindings, encoding, and sending to terminal.
pub fn (mut self Surface) key_callback(event KeyEvent) !InputEffect {
	// Handle keybindings first (press, repeat, release all checked)
	if v := self.maybe_handle_binding(event) {
		return v
	}

	// Check if KAM (keyboard action mode) is enabled
	if self.config.vt_kam_allowed && self.renderer_state.terminal.modes.disable_keyboard {
		return .consumed
	}

	// Hide mouse on typing if configured
	if self.config.mouse_hide_while_typing && event.action == .press
		&& !self.mouse.hidden && event.utf8.len > 0 {
		self.hide_mouse()
	}

	// Update modifiers if changed
	if self.mouse.mods != event.mods {
		self.mods_changed(event.mods)
	}

	// Track pressed key for release handling on focus loss
	if event.action == .release {
		if prev_ev := self.pressed_key {
			if prev_ev.key == event.key {
				self.pressed_key = none
			}
		}
	} else {
		mut copy := event
		copy.utf8 = ''
		self.pressed_key = copy
	}

	// Encode and send the key to the terminal
	if write_req := self.encode_key(event) {
		// If process exited and we got an encoded key, close surface
		if self.child_exited {
			self.close()
			return .closed
		}

		// Queue the encoded key for IO
		self.queue_io(IOMessage{ kind: .write_small })
		_ = write_req
	} else {
		return .ignored
	}

	// For non-modifier keys: clear selection and scroll to bottom
	if !key_is_modifier(event.key) {
		if self.config.selection_clear_on_typing || event.key == .escape {
			self.set_selection(none)!
		}
		if self.config.scroll_to_bottom_keystroke {
			self.scroll_to_bottom()!
		}
		self.queue_render()!
	}

	return .consumed
}

// text_callback sends text as-is to the terminal (like a paste).
pub fn (mut self Surface) text_callback(text string) ! {
	self.complete_clipboard_paste(text, true)!
}

// occlusion_callback is called when the surface visibility changes.
pub fn (mut self Surface) occlusion_callback(visible bool) ! {
	self.queue_io(IOMessage{ kind: .visible })
	_ = visible
	self.queue_render()!
}

// focus_callback is called when the surface gains or loses focus.
pub fn (mut self Surface) focus_callback(focused bool) ! {
	if self.focused == focused {
		return
	}
	self.focused = focused

	// Notify renderer of focus state
	self.renderer_thread.wakeup.notify()!

	if focused {
		// On focus gain, notify app
		self.rt_app.perform_action(AppAction{
			kind: .mouse_shape
			target: &self
		})!
	} else {
		// On focus loss, release any pressed keys
		if _ := self.pressed_key {
			self.pressed_key = none
		}
		// Show mouse cursor on focus loss
		self.show_mouse()
	}

	// Update terminal focus flag
	self.renderer_state.terminal.flags.focused = focused

	// Notify IO thread
	self.queue_io(IOMessage{ kind: .focused })

	self.queue_render()!
}

// refresh_callback schedules a render.
pub fn (mut self Surface) refresh_callback() ! {
	self.queue_render()!
}

// scroll_callback handles mouse scroll events.
pub fn (mut self Surface) scroll_callback(xoff f64, yoff f64, precision bool) ! {
	// Accumulate scroll deltas for high-precision (trackpad) scrolling
	if precision {
		self.mouse.pending_scroll_x += xoff
		self.mouse.pending_scroll_y += yoff
	} else {
		self.mouse.pending_scroll_x = xoff
		self.mouse.pending_scroll_y = yoff
	}

	// Convert pixel scroll to line scroll using cell height
	cell_h := if self.size.cell.height > 0 { f64(self.size.cell.height) } else { 1.0 }
	y_lines := i64(self.mouse.pending_scroll_y / cell_h)
	if y_lines == 0 && !precision {
		// For non-precision, always scroll at least one line
		if self.mouse.pending_scroll_y > 0 {
			self.mouse.pending_scroll_y = 0
			self.renderer_state.terminal.scroll_viewport_delta(-1)!
			self.queue_render()!
			return
		} else if self.mouse.pending_scroll_y < 0 {
			self.mouse.pending_scroll_y = 0
			self.renderer_state.terminal.scroll_viewport_delta(1)!
			self.queue_render()!
			return
		}
	}

	if y_lines != 0 {
		// Consume the scroll amount that produced these lines
		self.mouse.pending_scroll_y -= f64(y_lines) * cell_h

		// Check if terminal is in mouse reporting mode
		if self.renderer_state.terminal.flags.mouse_event != .none_ {
			// Report scroll as mouse button events to the terminal
			self.mouse_report(none, .press, self.mouse.mods, CursorPos{})!
		} else {
			// Scroll the viewport
			self.renderer_state.terminal.scroll_viewport_delta(i32(-y_lines))!
		}
		self.queue_render()!
	}
}

// content_scale_callback is called when the DPI content scale changes.
pub fn (mut self Surface) content_scale_callback(content_scale ContentScale) ! {
	x_dpi := content_scale.x * default_dpi
	y_dpi := content_scale.y * default_dpi

	// Update font size with new DPI
	mut new_size := self.font_size
	new_size.xdpi = u32(x_dpi)
	new_size.ydpi = u32(y_dpi)
	self.set_font_size(new_size)!

	// Recalculate padding with new DPI
	self.balance_padding_if_needed()

	// Trigger resize to recalculate everything
	self.resize(self.size.screen)!
}

// mouse_button_callback handles mouse button press/release events.
pub fn (mut self Surface) mouse_button_callback(action gg.MouseButton, button gg.MouseButton, mods gg.Modifier) !bool {
	// Update mods
	self.mouse.mods = mods

	// Show mouse on click
	if self.mouse.hidden {
		self.show_mouse()
	}

	btn_idx := int(button) % 10
	is_press := action == button // press when action matches button

	if is_press {
		self.mouse.click_state[btn_idx] = .press

		// Check for mouse reporting
		if self.is_mouse_reporting() && !self.mouse_shift_capture(true) {
			self.mouse_report(?gg.MouseButton(button), .press, mods, CursorPos{})!
			return true
		}

		// Handle left button
		if button == .left {
			self.mouse.left_click_count += 1

			// Double-click: select word
			if self.mouse.left_click_count == 2 {
				pos := self.rt_surface.get_cursor_pos()!
				vp := self.pos_to_viewport(pos.x, pos.y)
				if pin := self.renderer_state.terminal.viewport_pin(vp.x, vp.y) {
					if sel := self.renderer_state.terminal.select_word(pin) {
						self.renderer_state.terminal.select_at(sel)!
					}
				}
				self.queue_render()!
				return true
			}

			// Triple-click: select line
			if self.mouse.left_click_count >= 3 {
				pos := self.rt_surface.get_cursor_pos()!
				vp := self.pos_to_viewport(pos.x, pos.y)
				if pin := self.renderer_state.terminal.viewport_pin(vp.x, vp.y) {
					if sel := self.renderer_state.terminal.select_line(pin) {
						self.renderer_state.terminal.select_at(sel)!
					}
				}
				self.queue_render()!
				return true
			}
		}
	} else {
		self.mouse.click_state[btn_idx] = .release

		// Check for mouse reporting
		if self.is_mouse_reporting() && !self.mouse_shift_capture(true) {
			self.mouse_report(?gg.MouseButton(button), .release, mods, CursorPos{})!
			return true
		}

		// Stop selection scroll on release
		if button == .left && self.selection_scroll_active {
			self.selection_scroll_active = false
		}

		// Copy on select
		if button == .left && self.config.copy_on_select != .false_ {
			if _ := self.renderer_state.terminal.selection {
				sel := self.renderer_state.terminal.selection or { return false }
				self.copy_selection_to_clipboards(sel, 0)!
			}
		}
	}

	self.queue_render()!
	return false
}

// cursor_pos_callback handles cursor position / mouse move events.
pub fn (mut self Surface) cursor_pos_callback(pos CursorPos, mods ?gg.Modifier) ! {
	// Update mods if provided
	if m := mods {
		self.mouse.mods = m
	}

	// Convert to viewport coordinates
	pos_vp := self.pos_to_viewport(pos.x, pos.y)

	// Check for link hover
	if self.mouse.link_point == none || !(self.mouse.link_point or { Coordinate{} }).eql(pos_vp) {
		self.mouse_refresh_links(pos, pos_vp, self.mouse.over_link)!
	}

	// Handle mouse reporting for motion events
	if self.is_mouse_reporting() {
		report_motion := self.renderer_state.terminal.flags.mouse_event in [.button, .any]
		if report_motion {
			self.mouse_report(none, .motion, self.mouse.mods, pos)!
		}
	}

	// Handle selection drag (left click held)
	if self.mouse.click_state[0] == .press && self.mouse.left_click_count > 0 {
		if pin := self.renderer_state.terminal.viewport_pin(pos_vp.x, pos_vp.y) {
			match self.mouse.left_click_count {
				1 { self.drag_left_click_single(pin, pos.x)! }
				2 { self.drag_left_click_double(pin)! }
				else { self.drag_left_click_triple(pin)! }
			}
		}

		// Start selection scrolling if cursor is outside viewport
		if pos.y < 0 || pos.y > f64(self.size.screen.height) {
			self.selection_scroll_active = true
			self.queue_io(IOMessage{ kind: .selection_scroll })
		}

		self.queue_render()!
	}
}

// mouse_pressure_callback handles force touch events.
pub fn (mut self Surface) mouse_pressure_callback(stage MousePressureStage, pressure f64) ! {
	if self.mouse.pressure_stage == stage {
		return
	}
	self.mouse.pressure_stage = stage

	// On deep press with left mouse button, select word under cursor
	if stage == .deep && self.mouse.click_state[0] == .press && self.has_terminal() {
		pos := self.rt_surface.get_cursor_pos()!
		vp := self.pos_to_viewport(pos.x, pos.y)
		if pin := self.renderer_state.terminal.viewport_pin(vp.x, vp.y) {
			if sel := self.renderer_state.terminal.select_word(pin) {
				self.renderer_state.terminal.select_at(sel)!
				self.queue_render()!
			}
		}
	}
	_ = pressure
}

// color_scheme_callback is called when the color scheme changes (light/dark).
pub fn (mut self Surface) color_scheme_callback(scheme ColorScheme) ! {
	new_scheme := match scheme {
		.light { Theme.light }
		.dark { Theme.dark }
	}
	if self.config_conditional_state.theme == new_scheme {
		return
	}
	self.config_conditional_state.theme = new_scheme
	self.notify_config_conditional_state()

	// Notify IO thread for mode 2031 DSR report
	self.queue_io(IOMessage{ kind: .color_scheme_report })
}

// pos_to_viewport converts surface pixel coordinates to viewport cell coordinates.
pub fn (self &Surface) pos_to_viewport(xpos f64, ypos f64) Coordinate {
	raw_x := xpos - f64(self.size.padding.left)
	raw_y := ypos - f64(self.size.padding.top)
	x := if raw_x < 0 {
		u32(0)
	} else if self.size.cell.width > 0 {
		u32(raw_x) / self.size.cell.width
	} else {
		u32(0)
	}
	y := if raw_y < 0 {
		u32(0)
	} else if self.size.cell.height > 0 {
		u32(raw_y) / self.size.cell.height
	} else {
		u32(0)
	}
	return Coordinate{ x: x, y: y }
}

// perform_binding_action performs a binding action from a keybinding.
pub fn (mut self Surface) perform_binding_action(action BindingAction) !bool {
	match action.kind {
		.none_ { return false }
		.ignore { return true }
		.csi {
			self.queue_io(IOMessage{ kind: .write_small })
			return true
		}
		.esc {
			self.queue_io(IOMessage{ kind: .write_small })
			return true
		}
		.text {
			self.queue_io(IOMessage{ kind: .write_small })
			return true
		}
		.copy_to_clipboard {
			if sel := self.renderer_state.terminal.selection {
				self.copy_selection_to_clipboards(sel, 0)!
				if self.config.selection_clear_on_copy {
					self.set_selection(none)!
				}
			}
			return true
		}
		.paste_from_clipboard {
			self.start_clipboard_request(.paste)!
			return true
		}
		.increase_font_size {
			mut size := self.font_size
			size.points += 1.0
			self.font_size_adjusted = true
			self.set_font_size(size)!
			return true
		}
		.decrease_font_size {
			mut size := self.font_size
			if size.points > 1.0 {
				size.points -= 1.0
			}
			self.font_size_adjusted = true
			self.set_font_size(size)!
			return true
		}
		.reset_font_size {
			mut size := self.font_size
			size.points = self.config.original_font_size
			self.font_size_adjusted = false
			self.set_font_size(size)!
			return true
		}
		.scroll_page_up {
			grid := self.size.grid()
			self.renderer_state.terminal.scroll_viewport_delta(-i32(grid.rows))!
			self.queue_render()!
			return true
		}
		.scroll_page_down {
			grid := self.size.grid()
			self.renderer_state.terminal.scroll_viewport_delta(i32(grid.rows))!
			self.queue_render()!
			return true
		}
		.scroll_to_top {
			self.renderer_state.terminal.scroll_viewport_delta(-999999)!
			self.queue_render()!
			return true
		}
		.scroll_to_bottom {
			self.scroll_to_bottom()!
			self.queue_render()!
			return true
		}
		.close_surface {
			self.close()
			return true
		}
		.close_window {
			self.rt_app.perform_action(AppAction{
				kind: .close_window
				target: &self
			})!
			return true
		}
		.close_tab {
			self.rt_app.perform_action(AppAction{
				kind: .close_tab
				target: &self
			})!
			return true
		}
		.new_window {
			self.rt_app.perform_action(AppAction{
				kind: .set_title
				target: &self
			})!
			return true
		}
		.new_tab {
			self.rt_app.perform_action(AppAction{
				kind: .set_title
				target: &self
			})!
			return true
		}
		.toggle_fullscreen {
			self.rt_app.perform_action(AppAction{
				kind: .set_title
				target: &self
			})!
			return true
		}
		.inspector_toggle {
			if self.inspector != none {
				self.deactivate_inspector()
			} else {
				self.activate_inspector()!
			}
			return true
		}
		.deactivate_key_table {
			return self.deactivate_all_key_tables()!
		}
		.open_url {
			self.open_url('')!
			return true
		}
		.write_screen_file {
			self.write_screen_file(.screen, 0)!
			return true
		}
	}
}

// ---- Private helper methods ----

fn (mut self Surface) mods_changed(mods gg.Modifier) {
	if self.mouse.mods == mods {
		return
	}
	self.mouse.mods = mods

	// Update renderer mouse mods for link highlighting
	self.renderer_state.mouse.mods = self.mouse_mods_with_capture(self.mouse.mods)

	// Force screen rebuild to update link highlight state
	self.renderer_state.terminal.flags.dirty.clear = true

	self.queue_render() or {}
}

fn (mut self Surface) mouse_refresh_links(pos CursorPos, pos_vp Coordinate, over_link bool) ! {
	if pos.x < 0 || pos.y < 0 {
		return
	}

	// Update last checked link point
	self.mouse.link_point = pos_vp

	// Check for link at current position
	link := self.link_at_pos(pos) or {
		// No link found. If we were previously over a link, reset state
		if over_link {
			self.mouse.over_link = false
			self.renderer_state.mouse.point = none
			self.rt_app.perform_action(AppAction{
				kind: .mouse_shape
				target: &self
			})!
			self.rt_app.perform_action(AppAction{
				kind: .mouse_over_link
				target: &self
			})!
			self.queue_render()!
		}
		return
	}

	// Found a link — update state and notify runtime
	self.renderer_state.mouse.point = pos_vp
	self.mouse.over_link = true
	_ = link

	self.rt_app.perform_action(AppAction{
		kind: .mouse_shape
		target: &self
	})!

	if self.config.link_previews == .true_ {
		self.rt_app.perform_action(AppAction{
			kind: .mouse_over_link
			target: &self
		})!
	}

	self.queue_render()!
}

fn (self &Surface) is_mouse_reporting() bool {
	return self.config.mouse_reporting
		&& self.renderer_state.terminal.flags.mouse_event != .none_
}

fn (mut self Surface) mouse_report(button ?gg.MouseButton, action MouseReportAction, mods gg.Modifier, pos CursorPos) ! {
	// Convert cursor position to viewport coordinates
	vp := self.pos_to_viewport(pos.x, pos.y)

	// Update event point for tracking
	self.mouse.event_point = vp

	// Build and send the mouse report based on terminal's mouse format
	match self.renderer_state.terminal.flags.mouse_format {
		.x10 {
			// X10 format: ESC[M Cb Cx Cy (all +32)
			self.queue_io(IOMessage{ kind: .write_small })
		}
		.utf8 {
			// UTF-8 extended format
			self.queue_io(IOMessage{ kind: .write_small })
		}
		.sgr {
			// SGR format: ESC[<Cb;Cx;Cy M/m
			self.queue_io(IOMessage{ kind: .write_small })
		}
		.urxvt {
			// URXVT format
			self.queue_io(IOMessage{ kind: .write_small })
		}
		.sgr_pixels {
			// SGR-Pixels format
			self.queue_io(IOMessage{ kind: .write_small })
		}
	}
	_ = button
	_ = action
	_ = mods
}

fn (self &Surface) mouse_shift_capture(do_lock bool) bool {
	return match self.config.mouse_shift_capture {
		.never { false }
		.always { true }
		.false_ { false }
		.true_ {
			// Check terminal's mouse_shift_capture flag
			self.renderer_state.terminal.flags.mouse_shift_capture
		}
	}
}

pub fn (mut self Surface) mouse_captured() bool {
	return self.renderer_state.terminal.flags.mouse_event != .none_
}

fn (self &Surface) mouse_mods_with_capture(mods gg.Modifier) gg.Modifier {
	// If the terminal is reporting mouse events and shift is pressed,
	// strip shift from mods if we're not capturing shift
	if self.renderer_state.terminal.flags.mouse_event != .none_ {
		if (int(mods) & int(gg.Modifier.shift)) != 0 && !self.mouse_shift_capture(false) {
			return unsafe { gg.Modifier(int(mods) & ~int(gg.Modifier.shift)) }
		}
	}
	return mods
}

fn (mut self Surface) set_selection(sel ?TermSelection) ! {
	prev := self.renderer_state.terminal.selection
	self.renderer_state.terminal.select_at(sel)!

	// If copy_on_select is enabled and selection changed, copy to clipboard
	if self.config.copy_on_select == .false_ {
		return
	}
	new_sel := sel or { return }
	if prev_sel := prev {
		if new_sel.eql(prev_sel) {
			return
		}
	}
	self.copy_selection_to_clipboards(new_sel, 0)!
}

fn (mut self Surface) set_cell_size(size CellSize) ! {
	self.size.cell = size
	self.balance_padding_if_needed()

	// Notify IO thread of new size
	self.queue_io(IOMessage{ kind: .resize })

	// Recompute initial window size if configured
	self.recompute_initial_size() or {}

	// Notify runtime of cell size change
	self.rt_app.perform_action(AppAction{
		kind: .cell_size
		target: &self
	})!
}

fn (mut self Surface) queue_io(msg IOMessage) {
	// In readonly mode, block write operations
	if self.readonly {
		match msg.kind {
			.write_small, .write_stable, .write_alloc { return }
			else {}
		}
	}
	self.io.queue_message(msg)
}

fn (mut self Surface) recompute_initial_size() ! {
	if self.config.window_height <= 0 || self.config.window_width <= 0 {
		return
	}

	content_scale := self.rt_surface.get_content_scale()!

	height := math.max(self.config.window_height, min_window_height_cells) * self.size.cell.height
	width := math.max(self.config.window_width, min_window_width_cells) * self.size.cell.width

	// Scale and add padding
	final_width := u32(math.ceil(f64(width) / content_scale.x)) +
		self.size.padding.left + self.size.padding.right
	final_height := u32(math.ceil(f64(height) / content_scale.y)) +
		self.size.padding.top + self.size.padding.bottom

	_ = final_width
	_ = final_height
	self.rt_app.perform_action(AppAction{
		kind: .initial_size
		target: &self
	})!
}

fn (mut self Surface) scroll_to_bottom() ! {
	self.renderer_state.terminal.scroll_viewport_bottom()!
	self.queue_render()!
}

fn (mut self Surface) hide_mouse() {
	if self.mouse.hidden {
		return
	}
	self.mouse.hidden = true
	self.rt_app.perform_action(AppAction{
		kind: .mouse_visibility
		target: &self
	}) or {}
}

fn (mut self Surface) show_mouse() {
	if !self.mouse.hidden {
		return
	}
	self.mouse.hidden = false
	self.rt_app.perform_action(AppAction{
		kind: .mouse_visibility
		target: &self
	}) or {}
}

fn (mut self Surface) child_exited_handler(runtime_ms u32, exit_code u32) {
	self.child_exited = true

	// Abnormal exit detection
	if runtime_ms <= self.config.abnormal_command_exit_runtime_ms {
		// Show native GUI error if available
		self.rt_app.perform_action(AppAction{
			kind: .show_child_exited
			target: &self
		}) or {}

		// Print error to terminal
		self.renderer_state.terminal.carriage_return()
		self.renderer_state.terminal.linefeed() or { return }
		self.renderer_state.terminal.print_string('Process exited abnormally. Press any key to close.') or {
			return
		}
		self.renderer_state.terminal.modes.cursor_visible = false
		return
	}

	// Normal exit: show message in terminal
	self.rt_app.perform_action(AppAction{
		kind: .show_child_exited
		target: &self
	}) or {}

	self.renderer_state.terminal.carriage_return()
	self.renderer_state.terminal.linefeed() or { return }
	self.renderer_state.terminal.print_string('Process exited. Press any key to close the terminal.') or {
		return
	}
	self.renderer_state.terminal.modes.cursor_visible = false
	self.renderer_state.terminal.modes.disable_keyboard = false

	if !self.config.wait_after_command {
		self.close()
	}
}

fn (mut self Surface) password_input(v bool) ! {
	// Check if state actually changed
	if self.renderer_state.terminal.flags.password_input == v {
		return
	}
	self.renderer_state.terminal.flags.password_input = v

	// Notify runtime for secure input handling (e.g. macOS SecureInput)
	self.rt_app.perform_action(AppAction{
		kind: .secure_input
		target: &self
	}) or {}

	self.queue_render()!
}

fn (mut self Surface) update_renderer_health(health int) {
	self.rt_app.perform_action(AppAction{
		kind: .renderer_health
		target: &self
	}) or {}
	_ = health
}

fn (mut self Surface) update_scrollbar(scrollbar int) {
	self.rt_app.perform_action(AppAction{
		kind: .scrollbar
		target: &self
	}) or {}
	_ = scrollbar
}

fn (mut self Surface) notify_config_conditional_state() {
	self.rt_app.perform_action(AppAction{
		kind: .reload_config
		target: &self
	}) or {}
}

fn (mut self Surface) present_surface() ! {
	self.rt_app.perform_action(AppAction{
		kind: .present_terminal
		target: &self
	})!
}

fn (mut self Surface) end_key_sequence(action KeySequenceQueued, mem KeySequenceMemory) {
	self.keyboard.sequence_set = none

	// Notify runtime that key sequence ended
	self.rt_app.perform_action(AppAction{
		kind: .key_sequence
		target: &self
	}) or {}

	if self.keyboard.sequence_queued.len == 0 {
		return
	}

	match action {
		.flush {
			// Send all queued keys to the IO thread
			for write_req in self.keyboard.sequence_queued {
				self.queue_io(IOMessage{ kind: .write_small })
				_ = write_req
			}
		}
		.drop {
			// Discard all queued keys
			for write_req in self.keyboard.sequence_queued {
				write_req.deinit()
			}
		}
	}

	match mem {
		.free { self.keyboard.sequence_queued = [] }
		.retain { self.keyboard.sequence_queued.clear() }
	}
}

fn (mut self Surface) deactivate_all_key_tables() !bool {
	if self.keyboard.table_stack.len == 0 {
		return false
	}
	self.keyboard.table_stack.clear()

	// Notify runtime
	self.rt_app.perform_action(AppAction{
		kind: .key_table
		target: &self
	})!
	return true
}

fn (self &Surface) catch_all_is_ignore() bool {
	// Check if the innermost key table has a catch-all that maps to ignore.
	// This is used during key sequence handling.
	if self.keyboard.table_stack.len > 0 {
		// Would check table_stack.last().set.catch_all == .ignore
		return false
	}
	return false
}

fn (mut self Surface) maybe_handle_binding(event KeyEvent) ?InputEffect {
	// Release events: check if we consumed the corresponding press
	if event.action == .release {
		if last := self.keyboard.last_trigger {
			if last == event.binding_hash() {
				return .consumed
			}
		}
		return none
	}

	// Check for key sequence
	if seq_set := self.keyboard.sequence_set {
		entry := seq_set.get_event(event) or {
			// Not in sequence; for modifiers, allow passthrough
			if key_is_modifier(event.key) {
				return none
			}

			// Check if catch-all says ignore
			if self.catch_all_is_ignore() {
				self.end_key_sequence(.drop, .retain)
				return .ignored
			}

			// Flush queued keys and continue normal processing
			self.end_key_sequence(.flush, .retain)
			return none
		}
		_ = entry
		// Entry found in sequence — this is a leaf/leader, handle it
		return .consumed
	}

	// Check key tables (inner to outer)
	for i := self.keyboard.table_stack.len - 1; i >= 0; i-- {
		table := self.keyboard.table_stack[i]
		if _ := table.set.get_event(event) {
			// Found in table; if one-shot and topmost, deactivate
			if table.once && i == self.keyboard.table_stack.len - 1 {
				self.perform_binding_action(BindingAction{ kind: .deactivate_key_table }) or {}
			}
			return .consumed
		}
	}

	return none
}

fn (mut self Surface) encode_key(event KeyEvent) ?WriteReq {
	// If the key produces UTF-8 text, send it as a write request
	if event.utf8.len > 0 && event.action != .release {
		return WriteReq{
			data: event.utf8.bytes()
		}
	}

	// Map special keys to escape sequences
	esc := match event.key {
		.escape { '\x1b' }
		.enter { '\r' }
		.backspace { '\x7f' }
		.tab { '\t' }
		.up { '\x1b[A' }
		.down { '\x1b[B' }
		.right { '\x1b[C' }
		.left { '\x1b[D' }
		.home { '\x1b[H' }
		.end { '\x1b[F' }
		.page_up { '\x1b[5~' }
		.page_down { '\x1b[6~' }
		.insert { '\x1b[2~' }
		.delete { '\x1b[3~' }
		else { '' }
	}

	if esc.len > 0 {
		return WriteReq{ data: esc.bytes() }
	}

	return none
}

fn (mut self Surface) selection_scroll_tick() ! {
	if !self.selection_scroll_active {
		return
	}
	if self.mouse.left_click_count == 0 {
		return
	}

	pos := self.rt_surface.get_cursor_pos()!
	pos_vp := self.pos_to_viewport(pos.x, pos.y)
	delta := if pos.y < 0 { i32(-1) } else { i32(1) }

	// Scroll the viewport
	self.renderer_state.terminal.scroll_viewport_delta(delta)!

	// Continue drag selection
	if pin := self.renderer_state.terminal.viewport_pin(pos_vp.x, pos_vp.y) {
		self.drag_left_click_single(pin, pos.x)!
	}

	self.queue_render()!
}

fn (mut self Surface) process_links(pos CursorPos) !bool {
	link := self.link_at_pos(pos) or { return false }
	match link.action {
		.open {
			url := self.renderer_state.terminal.selection_string()
			if url.len > 0 {
				// Try resolving as local path first
				if resolved := self.resolve_path_for_opening(url) {
					self.open_url(resolved)!
				} else {
					self.open_url(url)!
				}
			}
			return true
		}
		.open_osc8 {
			if uri := self.osc8_uri(link.selection.start()) {
				self.open_url(uri)!
				return true
			}
		}
	}
	return false
}

fn (mut self Surface) open_url(url string) ! {
	// Try runtime action first, fall back to OS open
	self.rt_app.perform_action(AppAction{
		kind: .open_url
		target: &self
	}) or { return }
	if url.len > 0 {
		os.execute('open "${url}"')
	}
}

fn (self &Surface) osc8_uri(pin Pin) ?string {
	// Stub: looks up OSC 8 hyperlink URI at the given pin position.
	// Would check pin's page data for hyperlink flag and look up the URI.
	_ = pin
	return none
}

fn (mut self Surface) write_screen_file(loc WriteScreenLoc, emit int) ! {
	// Create temp file for screen content dump
	tmp_dir := os.temp_dir()
	tmp_path := os.join_path(tmp_dir, 'vterminal_dump.txt')

	content := self.renderer_state.terminal.selection_string()
	os.write_file(tmp_path, content)!
	_ = loc
	_ = emit
}

fn (mut self Surface) complete_clipboard_paste(data string, allow_unsafe bool) ! {
	if data.len == 0 {
		return
	}

	// Check for paste safety (newlines in non-bracketed mode)
	bracketed := self.renderer_state.terminal.modes.bracketed_paste
	if !allow_unsafe && data.contains('\n') && !bracketed {
		if self.config.clipboard_paste_protection {
			// Potentially unsafe paste detected — in a full implementation
			// this would prompt the user for confirmation
			return
		}
	}

	// Scroll to bottom before pasting
	self.scroll_to_bottom()!

	// Apply bracketed paste mode wrapping
	if bracketed {
		self.queue_io(IOMessage{ kind: .write_small }) // ESC[200~
		self.queue_io(IOMessage{ kind: .write_alloc }) // paste data
		self.queue_io(IOMessage{ kind: .write_small }) // ESC[201~
	} else {
		// Send data directly, converting newlines if needed
		self.queue_io(IOMessage{ kind: .write_alloc })
	}
}

fn (mut self Surface) show_desktop_notification(title string, body string) ! {
	// Rate limit: at most one notification per second
	now := time.now()
	if last := self.app.last_notification_time {
		if now - last < time.Duration(1 * time.second) {
			return
		}
	}

	// Dedup: don't repeat identical notifications within 5 seconds
	mut content_hash := u64(0)
	for b in title.bytes() {
		content_hash = content_hash * 31 + u64(b)
	}
	for b in body.bytes() {
		content_hash = content_hash * 31 + u64(b)
	}

	if content_hash == self.app.last_notification_digest {
		if last := self.app.last_notification_time {
			if now - last < time.Duration(5 * time.second) {
				return
			}
		}
	}

	self.app.last_notification_time = now
	self.app.last_notification_digest = content_hash

	self.rt_app.perform_action(AppAction{
		kind: .desktop_notification
		target: &self
	})!
}

fn (mut self Surface) copy_selection_to_clipboards(sel TermSelection, format int) ! {
	// Get selected text from terminal
	text := self.renderer_state.terminal.selection_string()
	if text.len == 0 {
		return
	}

	// Trim trailing spaces if configured
	final_text := if self.config.clipboard_trim_trailing_spaces {
		text.trim_right(' ')
	} else {
		text
	}

	// Set clipboard
	self.rt_surface.set_clipboard(final_text, false)!
	_ = sel
	_ = format
}

fn (mut self Surface) clipboard_write(data string, loc ClipboardRequestKind) ! {
	if self.config.clipboard_write == .deny {
		return
	}
	// Decode base64 data and set clipboard
	self.rt_surface.set_clipboard(data, self.config.clipboard_write == .ask)!
	_ = loc
}

fn (mut self Surface) start_clipboard_request(kind ClipboardRequestKind) !bool {
	if kind == .osc_52_read && self.config.clipboard_read == .deny {
		return false
	}
	self.rt_surface.clipboard_request(kind)!
	return true
}

fn (self &Surface) link_at_pos(pos CursorPos) ?Link {
	if pos.x < 0 || pos.y < 0 {
		return none
	}

	pos_vp := self.pos_to_viewport(pos.x, pos.y)
	mouse_mods := self.mouse_mods_with_capture(self.mouse.mods)

	// Check if left click is held and mouse moved (cancel link hover during drag)
	if self.mouse.click_state[0] == .press {
		if pin := self.mouse.left_click_pin {
			if !pin.eql(Pin{ x: pos_vp.x, y: pos_vp.y }) {
				return none
			}
		}
	}

	return self.link_at_pin(Pin{ x: pos_vp.x, y: pos_vp.y }, mouse_mods)
}

fn (self &Surface) link_at_pin(pin Pin, mouse_mods gg.Modifier) ?Link {
	// Check configured link patterns
	for link_cfg in self.config.links {
		// In a full implementation, this would:
		// 1. Get the line text at the pin
		// 2. Run the regex against it
		// 3. Check if the pin falls within a match
		// 4. Check highlight/mods requirements
		_ = link_cfg
	}
	_ = pin
	_ = mouse_mods
	return none
}

fn (mut self Surface) maybe_prompt_click() !bool {
	// Check if cursor-click-to-move is enabled and cursor is at a prompt
	if !self.config.cursor_click_to_move {
		return false
	}
	if !self.renderer_state.terminal.cursor_is_at_prompt() {
		return false
	}
	// Would send arrow key sequences to move cursor to click position
	return false
}

fn (mut self Surface) drag_left_click_single(pin Pin, drag_x f64) ! {
	click_pin := self.mouse.left_click_pin or { return }
	// Compute selection between click pin and drag pin
	if sel := mouse_selection(click_pin, pin,
		u32(self.mouse.left_click_xpos), u32(drag_x),
		self.mouse.mods, self.size)
	{
		self.renderer_state.terminal.select_at(sel)!
	}
}

fn (mut self Surface) drag_left_click_double(pin Pin) ! {
	// Word-level drag selection
	click_pin := self.mouse.left_click_pin or { return }
	if sel := self.renderer_state.terminal.select_word_between(click_pin, pin) {
		self.renderer_state.terminal.select_at(sel)!
	}
}

fn (mut self Surface) drag_left_click_triple(pin Pin) ! {
	// Line-level drag selection
	if sel := self.renderer_state.terminal.select_line(pin) {
		self.renderer_state.terminal.select_at(sel)!
	}
}

fn (self &Surface) resolve_path_for_opening(path string) ?string {
	if !os.is_abs_path(path) {
		terminal_pwd := self.renderer_state.terminal.get_pwd() or { return none }
		resolved := os.join_path(terminal_pwd, path)
		if os.exists(resolved) {
			return resolved
		}
		return none
	}
	return none
}

fn (mut self Surface) dump_text(sel TermSelection) !Text {
	return self.dump_text_locked(sel)
}

fn (mut self Surface) dump_text_locked(sel TermSelection) !Text {
	text := self.renderer_state.terminal.selection_string()

	// Calculate viewport info for the selection
	content_scale := self.rt_surface.get_content_scale() or {
		ContentScale{ x: 1.0, y: 1.0 }
	}

	tl := sel.top_left()
	mut x := f64(tl.x * self.size.cell.width + self.size.padding.left)
	x /= content_scale.x

	mut y := f64(tl.y * self.size.cell.height + self.size.padding.top)
	y += f64(self.size.cell.height)
	y -= f64(self.font_metrics.cell_baseline)
	y /= content_scale.y

	br := sel.bottom_right()
	start := tl.y * self.renderer_state.terminal.cols + tl.x
	end_val := br.y * self.renderer_state.terminal.cols + br.x

	return Text{
		text: text
		viewport: TextViewport{
			tl_px_x: x
			tl_px_y: y
			offset_start: start
			offset_len: end_val - start
		}
	}
}

// mouse_selection calculates the selection given click/drag pins and pixel positions.
fn mouse_selection(click_pin Pin, drag_pin Pin, click_x u32, drag_x u32, mods gg.Modifier, size Size) ?TermSelection {
	if click_pin.eql(drag_pin) && click_x == drag_x {
		return none
	}

	// Determine the 60% threshold for cell inclusion
	threshold := if size.cell.width > 0 { size.cell.width * 6 / 10 } else { u32(0) }

	// Determine start and end pins
	// If drag is before click, swap
	is_before := drag_pin.before(click_pin)

	start := if is_before { drag_pin } else { click_pin }
	end := if is_before { click_pin } else { drag_pin }

	// Adjust based on threshold and fractional position within cells
	_ = threshold
	_ = click_x
	_ = drag_x
	_ = mods

	return TermSelection{
		start_pin: start
		end_pin: end
		rectangle: (int(mods) & int(gg.Modifier.alt)) != 0
	}
}

fn main() {
	// Entry point placeholder — the real application creates surfaces via the runtime.
}
