module internal_os

import os

// DesktopEnvironment is the set of desktop environments Ghostty distinguishes.
pub enum DesktopEnvironment {
	gnome
	macos
	other
	windows
}

// desktop_environment detects the current desktop environment. On Linux and
// FreeBSD, only GNOME has behavior distinct from the generic fallback.
pub fn desktop_environment() DesktopEnvironment {
	$if macos {
		return .macos
	} $else $if windows {
		return .windows
	} $else $if linux || freebsd {
		if session := getenv('XDG_SESSION_DESKTOP') {
			if session.to_lower() in ['gnome', 'gnome-xorg'] {
				return .gnome
			}
		}
		if current := getenv('XDG_CURRENT_DESKTOP') {
			first := current.all_before(':')
			if first.to_lower() == 'gnome' {
				return .gnome
			}
		}
		return .other
	} $else {
		return .other
	}
}

// get_kernel_info returns Linux's kernel release, trimmed of surrounding
// ASCII whitespace. Other platforms and read failures return none.
pub fn get_kernel_info() ?string {
	$if linux {
		contents := os.read_file('/proc/sys/kernel/osrelease') or { return none }
		// Match Ghostty's bounded read; a kernel release should be tiny.
		if contents.len > 128 {
			return none
		}
		return contents.trim_space()
	} $else {
		return none
	}
}
