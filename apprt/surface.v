module apprt

// surface.v - Surface message types.
// Translated from ghostty/src/apprt/surface.zig

import terminal
import renderer
import configpkg
import datastruct
import osc

// WriteReq represents a write request. Magic number comes from the max size
// we want this union to be.
pub struct WriteReq {
mut:
	payload datastruct.MessageData[u8]
}

pub fn WriteReq.init(data []u8) WriteReq {
	return WriteReq{
		payload: datastruct.MessageData.init[u8](255, data)
	}
}

pub fn WriteReq.stable(data []u8) WriteReq {
	return WriteReq{
		payload: datastruct.MessageData.from_stable[u8](data)
	}
}

pub fn (self &WriteReq) slice() []u8 {
	return self.payload.slice()
}

pub fn (mut self WriteReq) deinit() {
	self.payload.deinit()
}

// Set the title of the surface.
// TODO: we should change this to a "WriteReq" style structure in
// the termio message so that we can more efficiently send strings
// of any length
pub struct SurfaceMessageSetTitle {
pub mut:
	title [256]u8
}

// Report the window title back to the terminal
pub struct SurfaceMessageReportTitle {
pub:
	style ReportTitleStyle
}

// Set the mouse shape.
pub struct SurfaceMessageSetMouseShape {
pub:
	shape terminal.MouseShape
}

// Read the clipboard and write to the pty.
pub struct SurfaceMessageClipboardRead {
pub:
	clipboard Clipboard
}

// Write the clipboard contents.
pub struct SurfaceMessageClipboardWrite {
pub:
	clipboard_type Clipboard
	req            WriteReq
}

// Change the configuration to the given configuration. The pointer is
// not valid after receiving this message so any config must be used
// and derived immediately.
pub struct SurfaceMessageChangeConfig {
pub:
	config &configpkg.Config = unsafe { nil }
}

// Close the surface. This will only close the current surface that
// receives this, not the full application.
pub struct SurfaceMessageClose {}

// Show a desktop notification.
pub struct SurfaceMessageDesktopNotification {
pub mut:
	// Desktop notification title.
	title [64]u8
	// Desktop notification body.
	body [256]u8
}

// Health status change for the renderer.
pub struct SurfaceMessageRendererHealth {
pub:
	health renderer.Health
}

// Tell the surface to present itself to the user. This may require raising
// a window and switching tabs.
pub struct SurfaceMessagePresentSurface {}

// Notifies the surface that password input has started within
// the terminal. This should always be followed by a false value
// unless the surface exits.
pub struct SurfaceMessagePasswordInput {
pub:
	value bool
}

// Notifies the surface that a tick of the timer that is timing
// out selection scrolling has occurred. "selection scrolling"
// is when the user has clicked and dragged the mouse outside
// the viewport of the terminal and the terminal is scrolling
// the viewport to follow the mouse cursor.
pub struct SurfaceMessageSelectionScrollTick {
pub:
	value bool
}

// The terminal has reported a change in the working directory.
pub struct SurfaceMessagePwdChange {
pub:
	req WriteReq
}

// The terminal encountered a bell character.
pub struct SurfaceMessageRingBell {}

// A command has started in the shell, start a timer.
pub struct SurfaceMessageStartCommand {}

// A command has finished in the shell, stop the timer and send out
// notifications as appropriate. The optional u8 is the exit code
// of the command.
pub struct SurfaceMessageStopCommand {
pub:
	exit_code ?u8
}

// Search progress update
pub struct SurfaceMessageSearchTotal {
pub:
	total ?usize
}

// Selected search index change
pub struct SurfaceMessageSearchSelected {
pub:
	selected ?usize
}

// The message types that can be sent to a single surface: the source's
// tagged `Message` union. `child_exited`, `color_change`, `progress_report`
// and `scrollbar` carry their payload types directly.
pub type SurfaceMessage = ChildExited
	| SurfaceMessageChangeConfig
	| SurfaceMessageClipboardRead
	| SurfaceMessageClipboardWrite
	| SurfaceMessageClose
	| SurfaceMessageDesktopNotification
	| SurfaceMessagePasswordInput
	| SurfaceMessagePresentSurface
	| SurfaceMessagePwdChange
	| SurfaceMessageRendererHealth
	| SurfaceMessageReportTitle
	| SurfaceMessageRingBell
	| SurfaceMessageSearchSelected
	| SurfaceMessageSearchTotal
	| SurfaceMessageSelectionScrollTick
	| SurfaceMessageSetMouseShape
	| SurfaceMessageSetTitle
	| SurfaceMessageStartCommand
	| SurfaceMessageStopCommand
	| osc.ColoredTarget
	| osc.ProgressReport
	| terminal.Scrollbar

// The tag of the active message variant.
pub fn (self SurfaceMessage) kind() SurfaceMessageKind {
	return match self {
		SurfaceMessageSetTitle { .set_title }
		SurfaceMessageReportTitle { .report_title }
		SurfaceMessageSetMouseShape { .set_mouse_shape }
		SurfaceMessageClipboardRead { .clipboard_read }
		SurfaceMessageClipboardWrite { .clipboard_write }
		SurfaceMessageChangeConfig { .change_config }
		SurfaceMessageClose { .close }
		ChildExited { .child_exited }
		SurfaceMessageDesktopNotification { .desktop_notification }
		SurfaceMessageRendererHealth { .renderer_health }
		SurfaceMessagePresentSurface { .present_surface }
		SurfaceMessagePasswordInput { .password_input }
		osc.ColoredTarget { .color_change }
		SurfaceMessageSelectionScrollTick { .selection_scroll_tick }
		SurfaceMessagePwdChange { .pwd_change }
		SurfaceMessageRingBell { .ring_bell }
		osc.ProgressReport { .progress_report }
		SurfaceMessageStartCommand { .start_command }
		SurfaceMessageStopCommand { .stop_command }
		terminal.Scrollbar { .scrollbar }
		SurfaceMessageSearchTotal { .search_total }
		SurfaceMessageSearchSelected { .search_selected }
	}
}

// SurfaceMessageKind identifies the type of surface message.
pub enum SurfaceMessageKind as u8 {
	// Set the title of the surface.
	set_title
	// Report the window title back to the terminal.
	report_title
	// Set the mouse shape.
	set_mouse_shape
	// Read the clipboard and write to the pty.
	clipboard_read
	// Write the clipboard contents.
	clipboard_write
	// Change the configuration to the given configuration.
	change_config
	// Close the surface.
	close
	// The child process running in the surface has exited.
	child_exited
	// Show a desktop notification.
	desktop_notification
	// Health status change for the renderer.
	renderer_health
	// Tell the surface to present itself to the user.
	present_surface
	// Notifies the surface that password input has started.
	password_input
	// A terminal color was changed using OSC sequences.
	color_change
	// Selection scrolling tick.
	selection_scroll_tick
	// The terminal has reported a change in the working directory.
	pwd_change
	// The terminal encountered a bell character.
	ring_bell
	// Report the progress of an action using a GUI element.
	progress_report
	// A command has started in the shell, start a timer.
	start_command
	// A command has finished in the shell, stop the timer and send out
	// notifications as appropriate.
	stop_command
	// The scrollbar state changed for the surface.
	scrollbar
	// Search progress update.
	search_total
	// Selected search index change.
	search_selected
}

// ReportTitleStyle identifies the style of title report.
pub enum ReportTitleStyle as u8 {
	csi_21_t
	// This enum is a placeholder for future title styles.
}

// ChildExited holds information about a child process that has exited.
pub struct ChildExited {
pub:
	exit_code  u32
	runtime_ms u64
}

// SurfaceMailbox handles pushing surface messages.
pub struct SurfaceMailbox {
pub:
	surface voidptr
	app     voidptr
	push_fn SurfaceMailboxPushFn = unsafe { nil }
}

pub type SurfaceMailboxPushFn = fn (app voidptr, surface voidptr, msg SurfaceMessage, timeout datastruct.BlockingQueueTimeout) u32

// push sends a message to the surface.
// Surface message sending is implemented on the app thread, so the
// message must be rewrapped with the surface pointer and sent to the
// app thread.
pub fn (m SurfaceMailbox) push(msg SurfaceMessage, timeout datastruct.BlockingQueueTimeout) u32 {
	if m.push_fn == unsafe { nil } {
		return 0
	}
	return m.push_fn(m.app, m.surface, msg, timeout)
}

// NewSurfaceContext describes where a new surface should be created
// (for determining inheritance behavior).
pub enum NewSurfaceContext as i32 {
	window
	tab
	split
}

// should_inherit_working_directory returns true if the given context should
// inherit the working directory from the focused surface.
pub fn should_inherit_working_directory(context NewSurfaceContext, config &configpkg.Config) bool {
	return match context {
		.window { config.window_inherit_working_directory }
		.tab { config.tab_inherit_working_directory }
		.split { config.split_inherit_working_directory }
	}
}

// new_config returns the independent configuration used to initialize a new
// surface. The last focused surface supplies its working directory when the
// selected creation context enables inheritance.
pub fn new_config(app &CoreApp, config &configpkg.Config, context NewSurfaceContext) configpkg.Config {
	mut copy := config.clone()
	if should_inherit_working_directory(context, config) {
		if pwd := app.focused_surface_pwd() {
			copy.working_directory = pwd
		}
	}
	return copy
}
