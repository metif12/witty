module apprt

import configpkg
import input

// "apprt" is the "application runtime" package. This abstracts the
// application runtime and lifecycle management such as creating windows,
// getting user input (mouse/keyboard), etc.
//
// This enables compile-time interfaces to be built to swap out the underlying
// application runtime. For example: pure macOS Cocoa, GTK+, browser, etc.
//
// The goal is to have different implementations share as much of the core
// logic as possible, and to only reach out to platform-specific implementation
// code when absolutely necessary.
//
// Types are organized across multiple files in this module:
//   action.v   - Action types, enums, and associated value structs
//   structs.v  - Basic structs: ContentScale, SurfaceSize, Clipboard, etc.
//   surface.v  - Surface message types
//   ipc.v      - Inter-process communication types
//   runtime.v  - Runtime enum
//   none.v     - "none" runtime stubs
//   browser.v  - Browser (WASM) runtime stubs
//   embedded.v - Embedded runtime (macOS / libghostty)

// RuntimeApp is the headless implementation of the application runtime used
// by the translated core package and tests. Platform runtimes implement the
// same action boundary; this implementation retains actions for its consumer.
pub struct RuntimeApp {
pub mut:
	config             configpkg.Config
	actions            []RuntimeAction
	handled            map[ActionKey]bool
	quit_timer_running bool
}

pub struct RuntimeAction {
pub:
	target Target
	action ActionKey
	data   ActionValue
}

pub fn (mut r RuntimeApp) perform_action(target Target, action ActionKey, data ActionValue) !bool {
	r.actions << RuntimeAction{
		target: target
		action: action
		data: data
	}
	if action == .quit_timer {
		r.quit_timer_running = data.quit_timer_ == .start
	}
	return r.handled[action]
}

// RuntimeSurface represents a single surface in the runtime.
pub struct RuntimeSurface {
pub mut:
	content_scale       ContentScale = ContentScale{ x: 1, y: 1 }
	size                SurfaceSize = SurfaceSize{ width: 800, height: 600 }
	cursor_pos          CursorPos
	title               ?string
	clipboards          map[Clipboard][]ClipboardContent
	requests            []ClipboardRequest
	closed              bool
	close_confirm       bool
	selection_clipboard bool
	default_env         map[string]string
}

pub fn (mut r RuntimeSurface) close(confirm bool) {
	r.closed = true
	r.close_confirm = confirm
}

pub fn (r RuntimeSurface) get_content_scale() !ContentScale {
	return r.content_scale
}

pub fn (r RuntimeSurface) get_size() !SurfaceSize {
	return r.size
}

pub fn (r RuntimeSurface) get_cursor_pos() !CursorPos {
	return r.cursor_pos
}

pub fn (r RuntimeSurface) get_title() ?string {
	return r.title
}

pub fn (mut r RuntimeSurface) set_clipboard(loc Clipboard, contents []ClipboardContent, confirm bool) ! {
	if confirm {
		return error('clipboard confirmation required')
	}
	r.clipboards[loc] = contents.clone()
}

pub fn (r RuntimeSurface) supports_clipboard(loc Clipboard) bool {
	return loc == .standard || r.selection_clipboard
}

pub fn (mut r RuntimeSurface) clipboard_request(loc Clipboard, req ClipboardRequest) ! {
	r.requests << ClipboardRequest{
		...req
		clipboard: loc
	}
}

pub fn (r RuntimeSurface) default_termio_env() !map[string]string {
	return r.default_env.clone()
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
	// Retain the surface-specific configuration used by the embedded ABI.
	if !isnil(config) {
		cfg := unsafe { &configpkg.Config(config) }
		s.config.macos_option_as_alt = cfg.macos_option_as_alt
		s.config.selection_word_chars = cfg.selection_word_chars.codepoints.map(rune(it).str()).join('')
	}
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

pub fn (mut s CoreSurface) mouse_button_callback(action_ voidptr, button voidptr, mods voidptr) !bool {
	_ = action_
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

// dump_text_locked reads the text covered by `sel` from the active screen.
// The renderer state mutex is assumed to be held by the caller. The returned
// DumpedText carries the text bytes along with viewport metadata (if any).
//
// This is currently a stub; the full implementation lives in the core
// terminal package (terminal.Screen.selectionString + page pin math).
pub fn (s CoreSurface) dump_text_locked(sel voidptr) !DumpedText {
	_ = sel
	return DumpedText{}
}

// DumpedText is the result of dump_text/dump_text_locked.
pub struct DumpedText {
pub mut:
	text     string
	viewport ?DumpedTextViewport
}

// DumpedTextViewport is the viewport-relative pixel/offset info for a
// dumped text region. Mirrors Ghostty's `Surface.Text.Viewport`.
pub struct DumpedTextViewport {
pub mut:
	tl_px_x      f64
	tl_px_y      f64
	offset_start u32
	offset_len   u32
}

// active_selection returns the active selection on the surface, if any.
// Currently a stub that always returns none.
pub fn (s CoreSurface) active_selection() ?voidptr {
	return none
}

// resolve_selection converts a CAPI-style selection into a core selection
// pointer that can be passed back to `dump_text_locked`. Returns none if
// the coordinates do not refer to a valid screen region.
pub fn (s CoreSurface) resolve_selection(tl_tag int, tl_coord_tag int, tl_x u32, tl_y u32, br_tag int, br_coord_tag int, br_x u32, br_y u32, rectangle bool) ?voidptr {
	_ = tl_tag
	_ = tl_coord_tag
	_ = tl_x
	_ = tl_y
	_ = br_tag
	_ = br_coord_tag
	_ = br_x
	_ = br_y
	_ = rectangle
	return none
}

// renderer_state_lock acquires the renderer-state mutex protecting the
// terminal/screen access. The current stub is a no-op; real locking is
// added when the renderer thread is wired in.
pub fn (mut s CoreSurface) renderer_state_lock() {
	// stub
}

// renderer_state_unlock releases the renderer-state mutex.
pub fn (mut s CoreSurface) renderer_state_unlock() {
	// stub
}

pub fn (s CoreSurface) mouse_captured() bool {
	return false
}

pub fn (mut s CoreSurface) perform_binding_action(action input.Action) !bool {
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
	macos_option_as_alt ?input.OptionAsAlt
	// Selection word boundary characters.
	selection_word_chars string
}

// SurfaceSizeInfo holds the surface's screen and cell size info.
pub struct SurfaceSizeInfo {
pub mut:
	screen ScreenSizeInfo
	cell   CellSizeInfo
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
