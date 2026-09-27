module apprt

// structs.v - Shared types for the apprt module.
// Translated from ghostty/src/apprt/structs.zig

// ContentScale is the ratio between the current DPI and the platform's
// default DPI. This is used to determine how much certain rendered elements
// need to be scaled up or down.
pub struct ContentScale {
pub:
	x f32
	y f32
}

// SurfaceSize is the size of the surface in pixels.
pub struct SurfaceSize {
pub:
	width  u32
	height u32
}

// CursorPos is the position of the cursor in pixels.
pub struct CursorPos {
pub:
	x f32
	y f32
}

// IMEPos is the Input Method Editor position.
pub struct IMEPos {
pub:
	x      f64
	y      f64
	width  f64
	height f64
}

// ClipboardContent holds the MIME type and data for clipboard contents.
pub struct ClipboardContent {
pub:
	mime string
	data string
}

// ClipboardRequestType identifies the type of clipboard request.
pub enum ClipboardRequestType as u8 {
	paste
	osc_52_read
	osc_52_write
}

// A direct paste of clipboard contents. This arm carries no clipboard because
// the clipboard to read is supplied separately to clipboard_request.
pub struct ClipboardRequestPaste {}

// A request to read clipboard contents via OSC 52.
pub struct ClipboardRequestOsc52Read {
pub:
	clipboard Clipboard
}

// A request to write clipboard contents via OSC 52.
pub struct ClipboardRequestOsc52Write {
pub:
	clipboard Clipboard
}

// ClipboardRequest is a clipboard request. This is used to request clipboard
// contents and must be sent as a response to a ClipboardRequest event.
pub type ClipboardRequest = ClipboardRequestOsc52Read | ClipboardRequestOsc52Write | ClipboardRequestPaste

// tag returns the source union discriminator used by the embedded callbacks.
pub fn (request ClipboardRequest) tag() ClipboardRequestType {
	return match request {
		ClipboardRequestPaste { .paste }
		ClipboardRequestOsc52Read { .osc_52_read }
		ClipboardRequestOsc52Write { .osc_52_write }
	}
}

// ColorScheme represents the color scheme in use (light vs dark).
pub enum ColorScheme as u8 {
	light
	dark
}

// Selection holds selection information.
pub struct Selection {
pub:
	// Top-left point of the selection in the viewport in scaled
	// window pixels. (0,0) is the top-left of the window.
	tl_x_px f64
	tl_y_px f64
	// The offset of the selection start in cells from the top-left
	// of the viewport.
	//
	// This is a strange metric but its used by macOS.
	offset_start u32
	offset_len   u32
}
