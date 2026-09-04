module apprt

// surface.v - Surface message types.
// Translated from ghostty/src/apprt/surface.zig

import terminal
import renderer
import configpkg
import osc

// WriteReq represents a write request. Magic number comes from the max size
// we want this union to be.
pub struct WriteReq {
pub:
	data []u8
}

// SurfaceMessage represents the message types that can be sent to a single surface.
pub struct SurfaceMessage {
pub mut:
	kind SurfaceMessageKind

	// For set_title: null-terminated title buffer
	// TODO: we should change this to a "WriteReq" style structure in
	// the termio message so that we can more efficiently send strings
	// of any length
	title_buf [256]u8

	// For report_title
	report_style ReportTitleStyle

	// For set_mouse_shape
	mouse_shape terminal.MouseShape

	// For clipboard_read
	clipboard_type Clipboard

	// For clipboard_write
	clipboard_write_type Clipboard
	clipboard_write_req  WriteReq

	// For change_config: pointer to the new configuration. The pointer is
	// not valid after receiving this message so any config must be used
	// and derived immediately.
	config &configpkg.Config = unsafe { nil }

	// For child_exited
	child_exited ChildExited

	// For desktop_notification
	// Desktop notification title.
	notification_title [63]u8
	// Desktop notification body.
	notification_body [255]u8

	// For renderer_health
	renderer_health renderer.Health

	// For password_input: notifies the surface that password input has
	// started within the terminal. This should always be followed by a
	// false value unless the surface exits.
	password_input bool

	// For color_change: a terminal color was changed using OSC sequences.
	color_change osc.ColoredTarget

	// For selection_scroll_tick: notifies the surface that a tick of the
	// timer that is timing out selection scrolling has occurred.
	selection_scroll_tick bool

	// For pwd_change: the terminal has reported a change in the working directory.
	pwd_change WriteReq

	// For progress_report: report the progress of an action using a GUI element.
	progress_report osc.ProgressReport

	// For stop_command: the optional exit code of the command.
	stop_command_exit_code ?u8

	// For scrollbar: the scrollbar state changed.
	scrollbar terminal.Scrollbar

	// For search_total: search progress update.
	search_total ?usize

	// For search_selected: selected search index change.
	search_selected ?usize
}

// SurfaceMessageKind identifies the type of surface message.
pub enum SurfaceMessageKind {
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
pub enum ReportTitleStyle {
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

pub type SurfaceMailboxPushFn = fn (app voidptr, surface voidptr, msg SurfaceMessage) int

// push sends a message to the surface.
// Surface message sending is implemented on the app thread, so the
// message must be rewrapped with the surface pointer and sent to the
// app thread.
pub fn (m SurfaceMailbox) push(msg SurfaceMessage) int {
	if m.push_fn == unsafe { nil } {
		return 0
	}
	return m.push_fn(m.app, m.surface, msg)
}

// NewSurfaceContext describes where a new surface should be created
// (for determining inheritance behavior).
pub enum NewSurfaceContext {
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
