module apprt

// RuntimeApp represents the application runtime.
pub struct RuntimeApp {}

pub fn (r RuntimeApp) perform_action(target ActionTarget, action ActionKind, data ActionData) !bool {
	// stub: performs an apprt action, returns true if handled
	_ = target
	_ = action
	_ = data
	return false
}

// RuntimeSurface represents a single surface in the runtime.
pub struct RuntimeSurface {}

pub fn (r RuntimeSurface) close(confirm bool) {
	// stub: close surface
	_ = confirm
}

pub fn (r RuntimeSurface) get_content_scale() !ContentScale {
	return ContentScale{ x: 1.0, y: 1.0 }
}

pub fn (r RuntimeSurface) get_size() !SurfaceSize {
	return SurfaceSize{ width: 800, height: 600 }
}

pub fn (r RuntimeSurface) get_cursor_pos() !CursorPos {
	return CursorPos{ x: 0.0, y: 0.0 }
}

pub fn (r RuntimeSurface) get_title() ?string {
	return none
}

pub fn (r RuntimeSurface) set_clipboard(loc Clipboard, contents []ClipboardContent, confirm bool) ! {
	// stub: sets clipboard content
	_ = loc
	_ = contents
	_ = confirm
}

pub fn (r RuntimeSurface) supports_clipboard(loc Clipboard) bool {
	return loc == .standard
}

pub fn (r RuntimeSurface) clipboard_request(loc Clipboard, req ClipboardRequest) ! {
	// stub: requests clipboard read
	_ = loc
	_ = req
}

pub fn (r RuntimeSurface) default_termio_env() !map[string]string {
	return map[string]string{}
}

pub struct ContentScale {
pub:
	x f32
	y f32
}

pub struct SurfaceSize {
pub:
	width  u32
	height u32
}

pub struct CursorPos {
pub:
	x f64
	y f64
}

pub struct IMEPos {
pub:
	x      f64
	y      f64
	width  f64
	height f64
}

pub enum Clipboard {
	standard
	selection
	primary
}

pub struct ClipboardContent {
pub:
	mime string
	data string
}

pub struct ClipboardRequest {
pub:
	kind ClipboardRequestKind
}

pub enum ClipboardRequestKind {
	osc_52_read
	paste
	render
}

pub enum ActionKind {
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
}

pub struct ActionTarget {
pub:
	surface voidptr
}

pub struct ActionData {
pub:
	title       string
	width       u32
	height      u32
	min_width   u32
	min_height  u32
	max_width   u32
	max_height  u32
	url         string
	exit_code   u32
	soft        bool
	config      voidptr
	focused     bool
	total       ?u32
	selected    ?u32
}

// SurfaceMessage represents a message sent to a specific surface.
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

pub struct ChildExitedInfo {
pub:
	runtime_ms u32
	exit_code  u32
}

// ColorScheme represents the system color scheme preference.
pub enum ColorScheme {
	light
	dark
}

// NewSurfaceContext describes where a new surface should be created.
pub enum NewSurfaceContext {
	window
	tab
	split
}

// SplitDirection values for new_split.
pub enum SplitDirection {
	right
	down
	left
	up
	auto_
}

// GotoSplit values for goto_split focus direction.
pub enum GotoSplit {
	previous
	next
	up
	left
	down
	right
}

// ResizeSplitDirection values for resize_split.
pub enum ResizeSplitDirection {
	up
	down
	left
	right
}

// ResizeSplit holds direction and amount for split resize.
pub struct ResizeSplit {
pub:
	direction ResizeSplitDirection
	amount    u16
}

// Target represents the target of an apprt action, either the app
// or a specific surface.
pub type Target = AppTarget | SurfaceTarget

pub struct AppTarget {}

pub struct SurfaceTarget {
pub:
	surface voidptr
}

// CoreApp represents the core application logic.
// This is a stub; the full implementation lives in the main module.
pub struct CoreApp {
pub mut:
	// Surfaces tracked by the app.
	surfaces []voidptr
}

pub fn CoreApp.create() !&CoreApp {
	return &CoreApp{}
}

pub fn (mut c CoreApp) destroy() {
	// stub: release resources
}

pub fn (mut c CoreApp) tick(app &App) ! {
	// stub: process one tick of the event loop
	_ = app
}

pub fn (c CoreApp) focus_event(focused bool) {
	// stub: handle app focus change
	_ = focused
}

pub fn (c CoreApp) key_event(app &App, event voidptr) bool {
	// stub: process a key event at the app level
	_ = app
	_ = event
	return false
}

pub fn (c CoreApp) key_event_is_binding(app &App, event voidptr) bool {
	// stub: check if key event triggers a binding
	_ = app
	_ = event
	return false
}

pub fn (mut c CoreApp) add_surface(surface voidptr) ! {
	c.surfaces << surface
}

pub fn (mut c CoreApp) delete_surface(surface voidptr) {
	c.surfaces = c.surfaces.filter(it != surface)
}

pub fn (c CoreApp) needs_confirm_quit() bool {
	return false
}

pub fn (mut c CoreApp) color_scheme_event(app &App, scheme ColorScheme) ! {
	// stub: propagate color scheme to all surfaces
	_ = app
	_ = scheme
}

pub fn (mut c CoreApp) update_config(app &App, config voidptr) ! {
	// stub: update config and propagate
	_ = app
	_ = config
}

// CoreSurface represents the core terminal surface logic.
// This is a stub; the full implementation lives in the main module.
pub struct CoreSurface {
pub mut:
	// Whether the child process has exited.
	child_exited bool
	// The current font size.
	font_size FontSize
	// The renderer state.
	renderer_state RendererState
	// Configuration.
	config SurfaceConfig
	// The surface size.
	size SurfaceSizeInfo
	// Inspector, if active.
	inspector ?&voidptr
}

pub fn (mut s CoreSurface) init(config voidptr, core_app &CoreApp, app &App, surface voidptr) ! {
	// stub: initialize core surface
	_ = config
	_ = core_app
	_ = app
	_ = surface
}

pub fn (mut s CoreSurface) deinit() {
	// stub: cleanup core surface
}

pub fn (mut s CoreSurface) key_callback(event voidptr) !InputEffect {
	// stub: handle key input
	_ = event
	return .ignored
}

pub fn (mut s CoreSurface) refresh_callback() ! {
	// stub: schedule a render
}

pub fn (mut s CoreSurface) draw() ! {
	// stub: draw the surface
}

pub fn (mut s CoreSurface) content_scale_callback(scale ContentScale) ! {
	_ = scale
}

pub fn (mut s CoreSurface) size_callback(size SurfaceSize) ! {
	_ = size
}

pub fn (mut s CoreSurface) color_scheme_callback(scheme ColorScheme) ! {
	_ = scheme
}

pub fn (mut s CoreSurface) mouse_button_callback(action voidptr, button voidptr, mods voidptr) !bool {
	_ = action
	_ = button
	_ = mods
	return false
}

pub fn (mut s CoreSurface) mouse_pressure_callback(stage voidptr, pressure f64) ! {
	_ = stage
	_ = pressure
}

pub fn (mut s CoreSurface) scroll_callback(xoff f64, yoff f64, mods voidptr) ! {
	_ = xoff
	_ = yoff
	_ = mods
}

pub fn (mut s CoreSurface) cursor_pos_callback(pos CursorPos, mods voidptr) ! {
	_ = pos
	_ = mods
}

pub fn (mut s CoreSurface) preedit_callback(preedit ?string) !bool {
	_ = preedit
	return false
}

pub fn (mut s CoreSurface) text_callback(text string) !bool {
	_ = text
	return false
}

pub fn (mut s CoreSurface) focus_callback(focused bool) ! {
	_ = focused
}

pub fn (mut s CoreSurface) occlusion_callback(visible bool) ! {
	_ = visible
}

pub fn (s CoreSurface) close() {
	// stub: request surface close
}

pub fn (s CoreSurface) has_selection() bool {
	return false
}

pub fn (s CoreSurface) mouse_captured() bool {
	return false
}

pub fn (mut s CoreSurface) perform_binding_action(action voidptr) !bool {
	_ = action
	return false
}

pub fn (mut s CoreSurface) update_config(config voidptr) ! {
	_ = config
}

pub fn (s CoreSurface) needs_confirm_quit() bool {
	return false
}

pub fn (s CoreSurface) ime_point() IMEPos {
	return IMEPos{}
}

pub fn (s CoreSurface) pwd() !string {
	return ''
}

pub fn (mut s CoreSurface) complete_clipboard_request(state ClipboardRequest, str string, confirmed bool) ! {
	_ = state
	_ = str
	_ = confirmed
}

pub fn (mut s CoreSurface) set_font_size(size FontSize) ! {
	_ = size
}

pub fn (mut s CoreSurface) activate_inspector() ! {
	// stub: activate the inspector
}

pub fn (mut s CoreSurface) deactivate_inspector() {
	// stub: deactivate the inspector
}

pub fn (s CoreSurface) key_event_is_binding(event voidptr) ?voidptr {
	_ = event
	return none
}

// InputEffect represents the effect of processing an input event.
pub enum InputEffect {
	// Input was not handled.
	ignored
	// Input was handled and consumed.
	consumed
	// Input resulted in a close event.
	closed
}

// FontSize holds the font size configuration.
pub struct FontSize {
pub mut:
	points f32
}

// RendererState holds the renderer's shared state.
pub struct RendererState {
pub mut:
	// Stub fields; the real implementation is in the renderer module.
	terminal voidptr
}

// SurfaceConfig holds surface-specific derived configuration.
pub struct SurfaceConfig {
pub mut:
	// macos-option-as-alt setting for this surface.
	macos_option_as_alt ?voidptr
	// Selection word boundary characters.
	selection_word_chars string
}

// SurfaceSizeInfo holds the surface's screen and cell size info.
pub struct SurfaceSizeInfo {
pub mut:
	screen  ScreenSizeInfo
	cell    CellSizeInfo
}

pub struct ScreenSizeInfo {
pub mut:
	width  u32
	height u32
}

pub struct CellSizeInfo {
pub mut:
	width  u32
	height u32
}

// GridSizeInfo holds the grid (columns/rows) dimensions.
pub struct GridSizeInfo {
pub:
	columns u16
	rows    u16
}

// grid returns the grid dimensions from the surface size.
pub fn (s SurfaceSizeInfo) grid() GridSizeInfo {
	if s.cell.width == 0 || s.cell.height == 0 {
		return GridSizeInfo{}
	}
	return GridSizeInfo{
		columns: u16(s.screen.width / s.cell.width)
		rows: u16(s.screen.height / s.cell.height)
	}
}
