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
	if !eligible_mouse_shape_key_event(self.physical_key) {
		return none
	}

	if self.over_link || self.hidden {
		return none
	}

	if self.mouse_event != .none {
		if is_mouse_mode_override_state(self.mods) && is_rectangle_select_state(self.mods) {
			return .crosshair
		}
		if is_mouse_mode_override_state(self.mods) {
			return .text
		}
		return .default_
	}

	if is_rectangle_select_state(self.mods) {
		return .crosshair
	}
	return .text
}

fn eligible_mouse_shape_key_event(physical_key input.Key) bool {
	return physical_key.ctrl_or_super() || physical_key.left_or_right_shift()
		|| physical_key.left_or_right_alt()
}

fn is_mouse_mode_override_state(mods input.Mods) bool {
	return mods.shift()
}

// Returns true if our modifiers put us in a state where dragging should
// cause a rectangle selection.
pub fn is_rectangle_select_state(mods input.Mods) bool {
	$if macos {
		return mods.alt()
	} $else {
		return mods.ctrl_or_super() && mods.alt()
	}
}
