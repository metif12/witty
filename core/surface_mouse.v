module core

import input
import terminal

// SurfaceMouse is the key-driven mouse cursor state used by Surface.key_callback.
// It is the canonical-type translation of Ghostty's surface_mouse.SurfaceMouse.
struct SurfaceMouse {
	physical_key input.Key
	mouse_event  terminal.MouseEvents
	mouse_shape  terminal.MouseShape
	mods         input.Mods
	over_link    bool
	hidden       bool
}

fn (self SurfaceMouse) key_to_mouse_shape() ?terminal.MouseShape {
	if !self.physical_key.ctrl_or_super() && !self.physical_key.left_or_right_shift()
		&& !self.physical_key.left_or_right_alt() {
		return none
	}

	if self.over_link || self.hidden {
		return none
	}

	if self.mouse_event != .none {
		if self.mods.shift && rectangle_select_mods(self.mods) {
			return .crosshair
		}
		if self.mods.shift {
			return .text
		}
		return .default_
	}

	if rectangle_select_mods(self.mods) {
		return .crosshair
	}
	return .text
}
