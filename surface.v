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

// Minimum window size in cells.
const min_window_width_cells = u32(10)
const min_window_height_cells = u32(4)

// The maximum number of key tables that can be active at any given time.
const max_active_key_tables = 8

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
	// XTODO
	// Depends on renderer padding balancing logic — centers the grid within
	// the screen by distributing leftover pixels as padding.
	_ = explicit
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
	click_state [10]gg.MouseButton

	// Last mods state when the last mouse button was pressed/released.
	mods gg.Modifier

	// Pin at which the left mouse click happened.
	left_click_pin ?&Pin

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
	set  &BindingSet
	once bool
}

// Placeholder types for external dependencies.
// These would be implemented in their respective modules.

pub struct App {
pub mut:
	last_notification_time   ?time.Time
	last_notification_digest u64
}

pub struct RuntimeApp {}

pub struct RuntimeSurface {}

pub struct Renderer {}

pub struct RendererState {
pub mut:
	terminal &Terminal = unsafe { nil }
	preedit  ?&Preedit
	mouse    RendererMouseState
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

pub struct RendererThread {}

pub struct Terminal {}

pub struct TermIO {}

pub struct IOThread {}

pub struct Inspector {}

pub struct Pin {}

pub struct Selection {}

pub struct BindingSet {}

pub struct WriteReq {}

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
	selection Selection
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
	scroll_to_bottom_keystroke     bool
	font                           DerivedFontConfig
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

pub fn DerivedConfig.init(config &Config) !DerivedConfig {
	// XTODO
	// Depends on configpkg.Config and all its fields from Ghostty config system.
	// Needs arena allocator, link regex compilation, keybind cloning, etc.
	_ = config
	return DerivedConfig{}
}

pub fn (mut self DerivedConfig) deinit() {
	// XTODO
	// Depends on arena allocator cleanup and regex deinit from Ghostty's DerivedConfig.
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

pub struct IOMessage {}

pub struct SurfaceMessage {}

pub struct BindingAction {}

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
	// XTODO
	// Depends on Ghostty's input.KeyEvent.bindingHash() hash computation.
	return 0
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

// Surface is the main terminal surface struct.
pub struct Surface {
pub mut:
	// The gg rendering context for drawing.
	gg_ctx &gg.Context = unsafe { nil }

	app        &App            = unsafe { nil }
	rt_app     &RuntimeApp     = unsafe { nil }
	rt_surface &RuntimeSurface = unsafe { nil }

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

// ---- Surface methods ----

// init creates a new surface. This must be called from the main thread.
pub fn (mut self Surface) init(config &Config, app &App, rt_app &RuntimeApp, rt_surface &RuntimeSurface) ! {
	// XTODO
	// Depends on configpkg.Config, apprt.runtime, font.SharedGridSet, rendererpkg,
	// termio.Termio, termio.Thread, and many other Ghostty subsystems for full
	// initialization. Sets up renderer, IO, font grid, terminal size, spawns
	// renderer and IO threads, and configures the initial window size.
	_ = config
	unsafe {
		self.app = app
		self.rt_app = rt_app
		self.rt_surface = rt_surface
	}
}

// deinit cleans up the surface and all its resources.
pub fn (mut self Surface) deinit() {
	// XTODO
	// Depends on search thread deinit, renderer thread stop/join, IO thread stop/join,
	// renderer/IO deinit, inspector cleanup, keyboard state cleanup (sequence_queued,
	// table_stack), font grid deref, preedit free, mutex destroy, config deinit.
	_ = self
}

// close triggers the runtime to start the close process.
pub fn (mut self Surface) close() {
	// XTODO
	// Depends on rt_surface.close(needs_confirm_quit()).
	_ = self
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
			// XTODO
			// Depends on renderer_state mutex lock and terminal.cursorIsAtPrompt().
			true
		}
	}
}

// handle_message handles mailbox messages to this specific surface.
pub fn (mut self Surface) handle_message(msg SurfaceMessage) ! {
	// XTODO
	// Depends on apprt.surface.Message variants and all handler methods:
	// change_config, set_title, report_title, color_change, set_mouse_shape,
	// clipboard_read/write, pwd_change, close, child_exited, desktop_notification,
	// renderer_health, scrollbar, present_surface, password_input, ring_bell,
	// progress_report, selection_scroll_tick, start/stop_command, search_total/selected.
	_ = msg
}

// draw forces the surface to render a frame using gg.
pub fn (mut self Surface) draw() ! {
	// XTODO
	// Depends on renderer.drawFrame(). In a gg-based implementation, this would
	// call self.gg_ctx.begin(), draw terminal cells, cursor, selections, etc.,
	// then call self.gg_ctx.end().
	_ = self
}

// activate_inspector begins collecting inspection data.
pub fn (mut self Surface) activate_inspector() ! {
	// XTODO
	// Depends on Inspector allocation and init, renderer_state mutex,
	// renderer_thread mailbox, and IO queue for inspector activation.
	_ = self
}

// deactivate_inspector stops collecting inspection data.
pub fn (mut self Surface) deactivate_inspector() {
	// XTODO
	// Depends on renderer_state mutex, renderer_thread mailbox,
	// IO queue, and Inspector deinit/destroy.
	_ = self
}

// update_config updates the surface configuration at runtime.
pub fn (mut self Surface) update_config(config &Config) ! {
	// XTODO
	// Depends on DerivedConfig.init, font size changes, renderer/termio config
	// message creation, renderer_thread mailbox push, IO queue, and apprt
	// performAction calls (set_title, config_change).
	_ = config
}

// has_selection returns true if the terminal has a selection.
pub fn (self &Surface) has_selection() bool {
	// XTODO
	// Depends on renderer_state mutex lock and terminal.screens.active.selection check.
	return false
}

// selection_string returns the selected text.
pub fn (self &Surface) selection_string() ?string {
	// XTODO
	// Depends on renderer_state mutex lock and terminal screen selectionString().
	return none
}

// pwd returns the current working directory of the terminal.
pub fn (self &Surface) pwd() ?string {
	// XTODO
	// Depends on renderer_state mutex lock and terminal.getPwd().
	return none
}

// ime_point returns the x/y coordinate of where the IME keyboard should be rendered.
pub fn (self &Surface) ime_point() IMEPos {
	// XTODO
	// Depends on renderer_state mutex, terminal cursor position, preedit width,
	// content scale, cell/padding sizes. Returns position/size for IME overlay.
	return IMEPos{}
}

// set_font_size changes the font size. Must be called from the main thread.
pub fn (mut self Surface) set_font_size(size DesiredSize) ! {
	// XTODO
	// Depends on app.font_grid_set.ref(), set_cell_size(), renderer_thread mailbox
	// for font_grid message, font grid key management, and queue_render.
	self.font_size = size
}

// queue_render queues a render operation with the renderer thread.
fn (mut self Surface) queue_render() ! {
	// XTODO
	// Depends on renderer_thread.wakeup.notify(). In a gg-based app, this could
	// set a needs_refresh flag on the gg context.
	_ = self
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

	// XTODO
	// Depends on queueIo(.resize) to notify the IO thread of the new pixel/grid sizes.
}

fn (mut self Surface) balance_padding_if_needed() {
	if !self.config.window_padding_balance {
		return
	}
	// XTODO
	// Depends on rt_surface.getContentScale() and font.face.default_dpi
	// to compute DPI-scaled padding and pass it to size.balance_padding().
}

// preedit_callback sets the preedit state for character input (dead keys, IME).
pub fn (mut self Surface) preedit_callback(preedit ?string) ! {
	// XTODO
	// Depends on renderer_state mutex, preedit codepoint conversion via UTF-8 decode,
	// selection clearing (selection_clear_on_typing), render queue.
	_ = preedit
}

// key_event_is_binding returns binding flags if the key event would trigger a keybinding.
pub fn (mut self Surface) key_event_is_binding(event KeyEvent) ?BindingFlags {
	// XTODO
	// Depends on config.key_remaps, keyboard.sequence_set, keyboard.table_stack,
	// and config.keybind.set lookup. Checks if a key event matches any configured
	// keybinding without actually performing it.
	_ = event
	return none
}

// key_callback handles key events including keybindings, encoding, and sending to terminal.
pub fn (mut self Surface) key_callback(event KeyEvent) !InputEffect {
	// XTODO
	// Depends on key remapping, crash metadata, inspector event recording,
	// maybe_handle_binding, KAM mode check, mouse hide, modifier change handling,
	// cursor shape updates, pressed key tracking, key encoding, child_exited close,
	// IO queue write, selection clearing, scroll_to_bottom, and render queue.
	_ = event
	return .ignored
}

// text_callback sends text as-is to the terminal (like a paste).
pub fn (mut self Surface) text_callback(text string) ! {
	// XTODO
	// Depends on complete_clipboard_paste which handles bracketed paste mode,
	// newline filtering, and IO queue writes.
	_ = text
}

// occlusion_callback is called when the surface visibility changes.
pub fn (mut self Surface) occlusion_callback(visible bool) ! {
	// XTODO
	// Depends on renderer_thread mailbox push (.visible) and queue_render.
	_ = visible
}

// focus_callback is called when the surface gains or loses focus.
pub fn (mut self Surface) focus_callback(focused bool) ! {
	if self.focused == focused {
		return
	}
	self.focused = focused

	// XTODO
	// Depends on renderer_thread mailbox (.focus), app.focusSurface on gain,
	// pressed key release logic on lose (sends release events for held keys and
	// modifier pairs), show_mouse, renderer_state mutex, terminal flags.focused,
	// IO focused message, and render queue.
}

// refresh_callback schedules a render.
pub fn (mut self Surface) refresh_callback() ! {
	self.queue_render()!
}

// scroll_callback handles mouse scroll events.
pub fn (mut self Surface) scroll_callback(xoff f64, yoff f64, precision bool) ! {
	// XTODO
	// Depends on mouse state, cell size, scroll multiplier config, terminal mode checks
	// (alternate screen, alternate scroll mode), mouse reporting, alternate scroll
	// cursor key conversion, viewport scrolling, and render queue.
	_ = xoff
	_ = yoff
	_ = precision
}

// content_scale_callback is called when the DPI content scale changes.
pub fn (mut self Surface) content_scale_callback(content_scale ContentScale) ! {
	// XTODO
	// Depends on font.face.default_dpi, set_font_size with new DPI,
	// DPI-dependent padding recalculation, and resize.
	_ = content_scale
}

// mouse_button_callback handles mouse button press/release events.
pub fn (mut self Surface) mouse_button_callback(action gg.MouseButton, button gg.MouseButton, mods gg.Modifier) !bool {
	// XTODO
	// Depends on click state tracking, mouse reporting, shift capture, selection
	// extension, selection scroll stop, copy-on-select, link clicking, prompt clicking,
	// context menu/right-click actions, double/triple click word/line selection,
	// middle-click paste, and render queue.
	_ = action
	_ = button
	_ = mods
	return false
}

// cursor_pos_callback handles cursor position / mouse move events.
pub fn (mut self Surface) cursor_pos_callback(pos CursorPos, mods ?gg.Modifier) ! {
	// XTODO
	// Depends on link hover detection, hyperlink state reset on negative pos,
	// mouse reporting (motion events), selection drag handling (single/double/triple
	// click drag), selection scroll start, inspector mouse tracking, and render queue.
	_ = pos
	_ = mods
}

// mouse_pressure_callback handles force touch events.
pub fn (mut self Surface) mouse_pressure_callback(stage MousePressureStage, pressure f64) ! {
	if self.mouse.pressure_stage == stage {
		return
	}
	self.mouse.pressure_stage = stage
	// XTODO
	// Depends on left mouse button check and word selection on deep press
	// using terminal screen selectWord().
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

	// XTODO
	// Depends on queueIo for color_scheme_report (mode 2031).
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
	// XTODO
	// Depends on the entire Ghostty binding action system: csi/esc sequence sending,
	// text input, cursor key mode, search start/end/navigate, copy/paste to clipboards,
	// font size inc/dec/reset/set, tab/split/window management, scrolling (top/bottom/
	// page/lines/fractional/prompt), screen file writing, selection adjustment, key table
	// activation/deactivation, inspector toggle, and crash actions.
	_ = action
	return true
}

// ---- Private helper methods ----

fn (mut self Surface) mods_changed(mods gg.Modifier) {
	// XTODO
	// Depends on mouse.mods comparison, renderer_state mutex, mouse mods with capture,
	// terminal dirty.clear flag, and render queue. Updates mouse modifier state
	// and refreshes link highlight if needed.
	_ = mods
}

fn (mut self Surface) mouse_refresh_links(pos CursorPos, pos_vp Coordinate, over_link bool) ! {
	// XTODO
	// Depends on link_at_pos, terminal selection string for URL display,
	// renderer_state mouse point, apprt mouse_shape/mouse_over_link actions,
	// link preview config, and render queue.
	_ = pos
	_ = pos_vp
	_ = over_link
}

fn (self &Surface) is_mouse_reporting() bool {
	// XTODO
	// Depends on config.mouse_reporting and terminal flags.mouse_event != .none.
	return false
}

fn (mut self Surface) mouse_report(button ?gg.MouseButton, action MouseReportAction, mods gg.Modifier, pos CursorPos) ! {
	// XTODO
	// Depends on terminal mouse event/format flags, viewport point conversion,
	// button code calculation with modifier bits, and IO queue writes for
	// x10/utf8/sgr/urxvt/sgr_pixels mouse report formats.
	_ = button
	_ = action
	_ = mods
	_ = pos
}

fn (self &Surface) mouse_shift_capture(do_lock bool) bool {
	// XTODO
	// Depends on config.mouse_shift_capture (never/always/false/true),
	// renderer_state mutex, and terminal flags.mouse_shift_capture.
	_ = do_lock
	return false
}

pub fn (mut self Surface) mouse_captured() bool {
	// XTODO
	// Depends on renderer_state mutex and terminal flags.mouse_event.
	return false
}

fn (self &Surface) mouse_mods_with_capture(mods gg.Modifier) gg.Modifier {
	// XTODO
	// Depends on terminal flags.mouse_event, mods.shift check, and
	// mouse_shift_capture to decide whether to strip shift from mods.
	return mods
}

fn (mut self Surface) set_selection(sel ?Selection) ! {
	// XTODO
	// Depends on terminal screen select(), copy_on_select config check,
	// and copy_selection_to_clipboards for selection/standard clipboard.
	_ = sel
}

fn (mut self Surface) set_cell_size(size CellSize) ! {
	self.size.cell = size
	self.balance_padding_if_needed()
	// XTODO
	// Depends on queueIo(.resize), recompute_initial_size(),
	// and apprt cell_size/size_limit actions.
}

fn (mut self Surface) queue_io(msg IOMessage) {
	// XTODO
	// Depends on readonly check (blocks write_small/write_stable/write_alloc in readonly)
	// and io.queueMessage from Ghostty's termio system.
	_ = msg
}

fn (mut self Surface) recompute_initial_size() ! {
	if self.config.window_height <= 0 || self.config.window_width <= 0 {
		return
	}
	// XTODO
	// Depends on rt_surface.getContentScale(), cell size * window_height/width,
	// content scale division, padding addition, and apprt initial_size action.
}

fn (mut self Surface) scroll_to_bottom() ! {
	// XTODO
	// Depends on terminal.scrollViewport(.bottom) and queue_render.
}

fn (mut self Surface) hide_mouse() {
	if self.mouse.hidden {
		return
	}
	self.mouse.hidden = true
	// XTODO
	// Depends on rt_app.performAction(.mouse_visibility, .hidden).
}

fn (mut self Surface) show_mouse() {
	if !self.mouse.hidden {
		return
	}
	self.mouse.hidden = false
	// XTODO
	// Depends on rt_app.performAction(.mouse_visibility, .visible).
}

fn (mut self Surface) child_exited_handler(runtime_ms u32, exit_code u32) {
	self.child_exited = true

	if runtime_ms <= self.config.abnormal_command_exit_runtime_ms {
		// XTODO
		// Depends on apprt show_child_exited action, terminal print methods
		// for error message display, and platform-specific exit code handling.
		return
	}

	// XTODO
	// Depends on apprt show_child_exited, terminal carriage_return/linefeed/printString,
	// cursor visibility mode, keyboard disable mode, and wait_after_command config.
	if !self.config.wait_after_command {
		self.close()
	}
}

fn (mut self Surface) password_input(v bool) ! {
	// XTODO
	// Depends on renderer_state mutex, terminal flags.password_input comparison
	// and update, apprt secure_input action, and queue_render.
	_ = v
}

fn (mut self Surface) update_renderer_health(health int) {
	// XTODO
	// Depends on apprt renderer_health action.
	_ = health
}

fn (mut self Surface) update_scrollbar(scrollbar int) {
	// XTODO
	// Depends on apprt scrollbar action.
	_ = scrollbar
}

fn (mut self Surface) notify_config_conditional_state() {
	// XTODO
	// Depends on rt_app.performAction(.reload_config, .{ .soft = true }).
}

fn (mut self Surface) present_surface() ! {
	// XTODO
	// Depends on rt_app.performAction(.present_terminal).
}

fn (mut self Surface) end_key_sequence(action KeySequenceQueued, mem KeySequenceMemory) {
	// XTODO (partial — structure is translated, IO queue calls are stubs)
	// Depends on rt_app.performAction(.key_sequence, .end) for apprt notification.
	self.keyboard.sequence_set = none

	if self.keyboard.sequence_queued.len == 0 {
		return
	}

	match action {
		.flush {
			for write_req in self.keyboard.sequence_queued {
				// XTODO: queue_io with write_req converted to write_small/stable/alloc
				_ = write_req
			}
		}
		.drop {
			for write_req in self.keyboard.sequence_queued {
				// XTODO: write_req.deinit()
				_ = write_req
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

	// XTODO
	// Depends on rt_app.performAction(.key_table, .deactivate_all).
	return true
}

fn (self &Surface) catch_all_is_ignore() bool {
	// XTODO
	// Depends on keyboard.table_stack and config.keybind.set catch_all trigger
	// lookup to check if the catch-all binding action is .ignore.
	return false
}

fn (mut self Surface) encode_key(event KeyEvent) ?WriteReq {
	// XTODO
	// Depends on encode_key_opts (terminal modes, macOS option-as-alt detection),
	// input.key_encode.encode (writes escape sequences to buffer), and
	// termio.Message.WriteReq construction (small fixed buffer or heap alloc).
	_ = event
	return none
}

fn (mut self Surface) selection_scroll_tick() ! {
	if !self.selection_scroll_active {
		return
	}
	if self.mouse.left_click_count == 0 {
		return
	}
	// XTODO
	// Depends on rt_surface.getCursorPos, pos_to_viewport, renderer_state mutex,
	// terminal screen active_key check, scrollViewport(.delta), drag_left_click_single,
	// and queue_render.
}

fn (mut self Surface) process_links(pos CursorPos) !bool {
	// XTODO
	// Depends on link_at_pos, terminal selection string for URL,
	// resolve_path_for_opening, open_url, and osc8 URI lookup.
	_ = pos
	return false
}

fn (mut self Surface) open_url(url string) ! {
	// XTODO
	// Depends on rt_app.performAction(.open_url) and fallback internal_os.open.
	_ = url
}

fn (self &Surface) osc8_uri(pin Pin) ?string {
	// XTODO
	// Depends on pin page data, cell hyperlink flag, page.lookupHyperlink,
	// hyperlink_set.get, and entry.uri.slice for URI extraction.
	_ = pin
	return none
}

fn (mut self Surface) write_screen_file(loc WriteScreenLoc, emit int) ! {
	// XTODO
	// Depends on internal_os.TempDir, file creation, terminal formatter
	// (plain/vt/html), renderer_state mutex, terminal selection/screen/history
	// dumping, and action dispatch (copy path / open file / paste path).
	_ = loc
	_ = emit
}

fn (mut self Surface) complete_clipboard_paste(data string, allow_unsafe bool) ! {
	if data.len == 0 {
		return
	}
	// XTODO
	// Depends on renderer_state mutex for encode options (bracketed paste mode),
	// paste safety detection (newlines, bracket injection), scroll_to_bottom,
	// input.paste.encode (may mutate data for newline conversion), and queue_io writes.
	_ = allow_unsafe
}

fn (mut self Surface) show_desktop_notification(title string, body string) ! {
	// XTODO
	// Depends on rate limiting via app.last_notification_time (1s global, 5s same content),
	// Wyhash for content dedup, and rt_app.performAction(.desktop_notification).
	_ = title
	_ = body
}

fn (mut self Surface) copy_selection_to_clipboards(sel Selection, format int) ! {
	// XTODO
	// Depends on terminal formatter (plain/vt/html/mixed modes), arena allocator,
	// clipboard content list building, and rt_surface.setClipboard.
	_ = sel
	_ = format
}

fn (mut self Surface) clipboard_write(data []u8, loc int) ! {
	// XTODO
	// Depends on config.clipboard_write deny check, base64 standard decoding,
	// sentinel allocation, and rt_surface.setClipboard with confirm flag.
	_ = data
	_ = loc
}

fn (mut self Surface) start_clipboard_request(loc int, req int) !bool {
	// XTODO
	// Depends on clipboard access config check (deny for osc_52_read)
	// and rt_surface.clipboardRequest.
	_ = loc
	_ = req
	return false
}

fn (self &Surface) link_at_pos(pos CursorPos) ?Link {
	// XTODO
	// Depends on terminal screen pin conversion from pos_to_viewport,
	// mouse_mods_with_capture, OSC8 hyperlink detection (cell.hyperlink flag),
	// and configured link regex matching via link_at_pin.
	_ = pos
	return none
}

fn (self &Surface) link_at_pin(pin Pin, mouse_mods ?gg.Modifier) ?Link {
	// XTODO
	// Depends on config.links iteration, terminal screen selectLine,
	// StringMap construction from selectionString, regex searchIterator,
	// match selection containment check, and mods/highlight filtering.
	_ = pin
	_ = mouse_mods
	return none
}

fn (mut self Surface) maybe_prompt_click() !bool {
	// XTODO
	// Depends on renderer_state mutex, terminal semantic_prompt.click mode,
	// cursor prompt detection (cursorIsAtPrompt), pin comparison, and
	// click_events (sends ESC[<0;x;yM) or cl mode (sends arrow key sequences).
	return false
}

fn (mut self Surface) drag_left_click_single(pin Pin, drag_x f64) ! {
	// XTODO
	// Depends on mouse_selection() calculation and terminal screen select().
	_ = pin
	_ = drag_x
}

fn (mut self Surface) drag_left_click_double(pin Pin) ! {
	// XTODO
	// Depends on terminal screen selectWordBetween for word-level drag selection.
	_ = pin
}

fn (mut self Surface) drag_left_click_triple(pin Pin) ! {
	// XTODO
	// Depends on terminal screen selectLine for line-level drag selection.
	_ = pin
}

fn (self &Surface) resolve_path_for_opening(path string) ?string {
	// XTODO
	// Depends on terminal getPwd, os.path.resolve, and file access check.
	_ = path
	return none
}

fn (mut self Surface) dump_text(sel Selection) !Text {
	// XTODO
	// Depends on renderer_state mutex and dump_text_locked.
	_ = sel
	return Text{}
}

fn (mut self Surface) dump_text_locked(sel Selection) !Text {
	// XTODO
	// Depends on terminal selectionString, viewport pin calculations (topLeft,
	// bottomRight, pointFromPin), content scale, cell/padding math for pixel
	// position and linear offset computation.
	_ = sel
	return Text{}
}

// mouse_selection calculates the selection given click/drag pins and pixel positions.
// Implements the core selection algorithm with 60% cell width threshold, normal vs
// rectangular modes, and LTR/RTL direction handling.
fn mouse_selection(click_pin Pin, drag_pin Pin, click_x u32, drag_x u32, mods gg.Modifier, size Size) ?Selection {
	// XTODO
	// Depends on terminal.Pin methods (eql, before, leftWrap, rightWrap, leftClamp,
	// rightClamp), terminal.Selection.init, and SurfaceMouse.isRectangleSelectState.
	// Algorithm:
	// 1. Compute 60% threshold_point from cell width
	// 2. Compute fractional positions within cells for click and drag
	// 3. Determine if end is before start (LTR vs RTL)
	// 4. Decide inclusion of click/drag cells based on threshold
	// 5. Compute start/end pins, handling wrapping and clamping
	// 6. Return null if the selection would be empty
	_ = click_pin
	_ = drag_pin
	_ = click_x
	_ = drag_x
	_ = mods
	_ = size
	return none
}

fn closing_action(action BindingAction) bool {
	// XTODO
	// Depends on BindingAction variants: close_surface, close_window, close_tab.
	_ = action
	return false
}

fn main() {
	// Entry point placeholder — the real application creates surfaces via the runtime.
}
