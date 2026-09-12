module build

import os

// Targets identifies the window-system backends compiled into GTK4.
pub struct Targets {
	value u8
}

pub fn Targets.init(x11 bool, wayland bool) Targets {
	mut value := u8(0)
	if x11 {
		value |= 0x01
	}
	if wayland {
		value |= 0x02
	}
	return Targets{
		value: value
	}
}

pub fn (targets Targets) x11() bool {
	return targets.value & 0x01 != 0
}

pub fn (targets Targets) wayland() bool {
	return targets.value & 0x02 != 0
}

pub fn (targets Targets) int_val() u8 {
	return targets.value
}

// targets returns the window-system backends GTK4 was compiled with. Failure
// is intentionally ignored so build help remains usable without GTK installed.
pub fn targets() Targets {
	result := os.execute('pkg-config --variable=targets gtk4')
	if result.exit_code != 0 {
		return Targets{}
	}
	return targets_from_output(result.output)
}

fn targets_from_output(output string) Targets {
	return Targets.init(output.contains('x11'), output.contains('wayland'))
}
