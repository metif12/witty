module apprt

// Test ContentScale struct creation.
fn test_content_scale() {
	cs := ContentScale{ x: 2.0, y: 2.0 }
	assert cs.x == f32(2.0)
	assert cs.y == f32(2.0)
}

// Test SurfaceSize struct creation.
fn test_surface_size() {
	ss := SurfaceSize{ width: 1920, height: 1080 }
	assert ss.width == 1920
	assert ss.height == 1080
}

// Test CursorPos struct creation.
fn test_cursor_pos() {
	cp := CursorPos{ x: 10.5, y: 20.3 }
	assert cp.x == f32(10.5)
	assert cp.y == f32(20.3)
}

// Test IMEPos struct creation.
fn test_ime_pos() {
	ip := IMEPos{ x: 100.0, y: 200.0, width: 50.0, height: 20.0 }
	assert ip.x == 100.0
	assert ip.width == 50.0
}

// Test Clipboard enum values.
fn test_clipboard() {
	assert Clipboard.standard == .standard
	assert Clipboard.selection == .selection
	assert Clipboard.primary == .primary
}

// Test ClipboardContent struct creation.
fn test_clipboard_content() {
	cc := ClipboardContent{ mime: 'text/plain', data: 'hello' }
	assert cc.mime == 'text/plain'
	assert cc.data == 'hello'
}

// Test ClipboardRequestType enum values.
fn test_clipboard_request_type() {
	assert ClipboardRequestType.paste == .paste
	assert ClipboardRequestType.osc_52_read == .osc_52_read
	assert ClipboardRequestType.osc_52_write == .osc_52_write
}

// Test ClipboardRequest struct creation.
fn test_clipboard_request() {
	cr := ClipboardRequest{ kind: .paste }
	assert cr.kind == .paste
}

// Test ColorScheme enum values.
fn test_color_scheme() {
	assert ColorScheme.light == .light
	assert ColorScheme.dark == .dark
}

// Test Selection struct creation.
fn test_selection() {
	sel := Selection{
		tl_x_px: 10.0
		tl_y_px: 20.0
		offset_start: 5
		offset_len: 10
	}
	assert sel.tl_x_px == 10.0
	assert sel.offset_start == 5
	assert sel.offset_len == 10
}
