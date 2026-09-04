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

	// Whether the containing application is focused. App-level key events are
	// limited to global bindings while this is false.
	focused bool = true

	// Conditional configuration state used to suppress redundant system-theme
	// reloads.
	config_conditional_state configpkg.ConditionalState
}

pub fn CoreApp.create() !&CoreApp {
	return &CoreApp{}
}

pub fn (mut c CoreApp) destroy() {
	// The embedded runtime owns and destroys surfaces individually. The core app
	// only retains non-owning pointers to them.
	c.surfaces.clear()
}

pub fn (mut c CoreApp) tick(app &App) ! {
	// Embedded runtime actions are delivered synchronously through perform_action.
	// There is no platform event queue to drain here; the host calls this entrypoint
	// after its wakeup callback so queued surface work can be added without changing
	// the ABI.
	_ = app
}

pub fn (mut c CoreApp) focus_event(focused bool) {
	// Prevent redundant focus events.
	if c.focused == focused {
		return
	}
	c.focused = focused
}

pub fn (mut c CoreApp) key_event(app &App, event voidptr) bool {
	if isnil(event) {
		return false
	}
	input_event := unsafe { *&input.KeyEvent(event) }
	if input_event.action == .release {
		return false
	}

	entry := app.config.keybind.set.get_event(input_event) or { return false }
	actions, flags := core_app_binding_leaf(entry) or { return false }
	if actions.len == 0 {
		return false
	}

	// When the application isn't focused, only global bindings are eligible.
	if !c.focused && !flags.global {
		return false
	}

	mut runtime_app := unsafe { &App(app) }
	if flags.global {
		for action in actions {
			c.perform_all_action(mut runtime_app, action) or {}
		}
		return true
	}

	// Surface-scoped bindings are handled by Surface.key_event. An app key event
	// is consumed only when every action in a chain is app-scoped.
	for action in actions {
		if action.scope() != .app {
			return false
		}
	}
	for action in actions {
		c.perform_app_action(mut runtime_app, action) or {}
	}
	return true
}

pub fn (c CoreApp) key_event_is_binding(app &App, event voidptr) bool {
	if isnil(event) {
		return false
	}
	input_event := unsafe { *&input.KeyEvent(event) }
	if input_event.action == .release {
		return false
	}
	entry := app.config.keybind.set.get_event(input_event) or { return false }
	return core_app_binding_leaf(entry) != none
}

pub fn (mut c CoreApp) add_surface(surface voidptr) ! {
	c.surfaces << surface
}

pub fn (mut c CoreApp) delete_surface(surface voidptr) {
	c.surfaces = c.surfaces.filter(it != surface)
}

pub fn (c CoreApp) needs_confirm_quit() bool {
	for surface_ptr in c.surfaces {
		if isnil(surface_ptr) {
			continue
		}
		surface := unsafe { &Surface(surface_ptr) }
		if surface.core_surface.needs_confirm_quit() {
			return true
		}
	}
	return false
}

pub fn (mut c CoreApp) color_scheme_event(app &App, scheme ColorScheme) ! {
	new_theme := match scheme {
		.light { configpkg.Theme.light }
		.dark { configpkg.Theme.dark }
	}
	if c.config_conditional_state.theme == new_theme {
		return
	}
	c.config_conditional_state.theme = new_theme
	mut runtime_app := unsafe { &App(app) }
	runtime_app.perform_action(Target(AppTarget{}), .reload_config, ActionValue{}) or {}
}

pub fn (mut c CoreApp) update_config(app &App, config voidptr) ! {
	if isnil(config) {
		return error('configuration pointer is null')
	}
	cfg := unsafe { &configpkg.Config(config) }
	for surface_ptr in c.surfaces {
		if isnil(surface_ptr) {
			continue
		}
		mut surface := unsafe { &Surface(surface_ptr) }
		surface.core_surface.update_config(cfg)!
	}
	mut runtime_app := unsafe { &App(app) }
	runtime_app.perform_action(Target(AppTarget{}), .config_change, ActionValue{
		config_change_: ConfigChange{
			config: cfg
		}
	}) or {}
}

// core_app_binding_leaf resolves a top-level app binding. App-level key
// sequences are intentionally unsupported, matching Ghostty's CoreApp lookup.
fn core_app_binding_leaf(entry &input.SetEntry) ?([]input.Action, input.Flags) {
	return match entry.value.typ {
		.leader { none }
		.leaf {
			([entry.value.leaf_action]), entry.value.leaf_flags
		}
		.leaf_chained {
			(entry.value.chain_actions.clone()), entry.value.chain_flags
		}
	}
}

// perform_app_action translates the app-scoped input action into the embedded
// runtime action boundary. This is the same switch as CoreApp.performAction.
fn (mut c CoreApp) perform_app_action(mut app App, action input.Action) ! {
	target := Target(AppTarget{})
	match action.tag {
		.ignore, .unbind {}
		.quit { app.perform_action(target, .quit, ActionValue{})! }
		.new_window { app.perform_action(target, .new_window, ActionValue{})! }
		.open_config { app.perform_action(target, .open_config, ActionValue{})! }
		.reload_config { app.perform_action(target, .reload_config, ActionValue{})! }
		.close_all_windows { app.perform_action(target, .close_all_windows, ActionValue{})! }
		.toggle_quick_terminal {
			app.perform_action(target, .toggle_quick_terminal, ActionValue{})!
		}
		.toggle_visibility { app.perform_action(target, .toggle_visibility, ActionValue{})! }
		.check_for_updates { app.perform_action(target, .check_for_updates, ActionValue{})! }
		.show_gtk_inspector { app.perform_action(target, .show_gtk_inspector, ActionValue{})! }
		.undo { app.perform_action(target, .undo, ActionValue{})! }
		.redo { app.perform_action(target, .redo, ActionValue{})! }
		else {}
	}
}

// perform_all_action applies app-scoped actions once and surface-scoped
// actions to every live surface, matching CoreApp.performAllAction.
fn (mut c CoreApp) perform_all_action(mut app App, action input.Action) ! {
	if action.scope() == .app {
		c.perform_app_action(mut app, action)!
		return
	}
	for surface_ptr in c.surfaces {
		if isnil(surface_ptr) {
			continue
		}
		mut surface := unsafe { &Surface(surface_ptr) }
		surface.core_surface.perform_binding_action(action) or {}
	}
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
	if isnil(config) {
		return error('configuration pointer is null')
	}
	cfg := unsafe { &configpkg.Config(config) }
	s.config.macos_option_as_alt = cfg.macos_option_as_alt
	s.config.selection_word_chars = cfg.selection_word_chars.codepoints.map(rune(it).str()).join('')
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
