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
