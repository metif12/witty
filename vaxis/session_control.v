module vaxis

import encoding.base64

// These return the bytes written to the pinned Vaxis IoWriter.
pub fn (vx &Vaxis) notify(title ?string, body string) string {
	_ = vx
	if value := title {
		return '\x1b]777;notify;${value};${body}\x1b\\'
	}
	return '\x1b]9;${body}\x1b\\'
}

pub fn (vx &Vaxis) set_title(title string) string {
	_ = vx
	return '\x1b]2;${title}\x1b\\'
}

pub fn (vx &Vaxis) copy_to_system_clipboard(text string) string {
	_ = vx
	return '\x1b]52;c;${base64.encode_str(text)}\x1b\\'
}

pub fn (vx &Vaxis) request_system_clipboard() !string {
	if !vx.opts.system_clipboard {
		return error('NoClipboardAllocator')
	}
	return '\x1b]52;c;?\x1b\\'
}

pub fn (mut vx Vaxis) set_terminal_foreground_color(rgb [3]u8) string {
	vx.state.changed_default_fg = true
	return terminal_color_sequence(10, rgb)
}

pub fn (mut vx Vaxis) set_terminal_background_color(rgb [3]u8) string {
	vx.state.changed_default_bg = true
	return terminal_color_sequence(11, rgb)
}

pub fn (mut vx Vaxis) set_terminal_cursor_color(rgb [3]u8) string {
	vx.state.changed_cursor_color = true
	return terminal_color_sequence(12, rgb)
}

fn terminal_color_sequence(number int, rgb [3]u8) string {
	return '\x1b]${number};rgb:${rgb[0]:02x}${rgb[0]:02x}/${rgb[1]:02x}${rgb[1]:02x}/${rgb[2]:02x}${rgb[2]:02x}\x1b\\'
}

pub fn (vx &Vaxis) query_color(kind ColorReportKind) string {
	_ = vx
	return match kind {
		ColorReportFg { '\x1b]10;?\x1b\\' }
		ColorReportBg { '\x1b]11;?\x1b\\' }
		ColorReportCursor { '\x1b]12;?\x1b\\' }
		ColorReportIndex { '\x1b]4;${kind.index};?\x1b\\' }
	}
}

pub fn (mut vx Vaxis) subscribe_to_color_scheme_updates() string {
	vx.state.color_scheme_updates = true
	return '\x1b[?996n\x1b[?2031h'
}

pub fn (vx &Vaxis) device_status_report() string {
	_ = vx
	return '\x1b[5n'
}
