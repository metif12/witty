// SurfaceMouse represents mouse helper functionality for the core surface.
//
// It's currently small in scope; its purpose is to isolate mouse logic that
// has gotten a bit complex (e.g. pointer shape handling for key events), but
// the intention is to grow it later so that we can better test said logic).
module main

// MouseShape cursor types
pub enum MouseShape {
	default_
	text
	pointer
	crosshair
	progress
}

// MouseEvents tracking mode
pub enum MouseEvents {
	none_
	x10
	normal
	button
	any
}

// Key represents a physical key on the keyboard.
pub enum Key {
	unidentified
	shift_left
	shift_right
	control_left
	control_right
	alt_left
	alt_right
	super_left
	super_right
}

// true if this key is one of the left or right versions of super (macOS)
// or ctrl.
pub fn (k Key) ctrl_or_super() bool {
	$if macos {
		return k == .super_left || k == .super_right
	} $else {
		return k == .control_left || k == .control_right
	}
}

// true if this key is either left or right shift.
pub fn (k Key) left_or_right_shift() bool {
	return k == .shift_left || k == .shift_right
}

// true if this key is either left or right alt.
pub fn (k Key) left_or_right_alt() bool {
	return k == .alt_left || k == .alt_right
}

// Mods represents the modifier key state.
pub struct Mods {
pub:
	shift  bool
	ctrl   bool
	alt    bool
	super_ bool
}

// Checks to see if super is on (macOS) or ctrl.
pub fn (m Mods) ctrl_or_super() bool {
	$if macos {
		return m.super_
	} $else {
		return m.ctrl
	}
}

pub struct SurfaceMouse {
pub:
	// For processing key events; the key that was physically pressed on the
	// keyboard.
	physical_key Key
	// The mouse event tracking mode, if any.
	mouse_event MouseEvents
	// The current terminal's mouse shape.
	mouse_shape MouseShape
	// The last mods state when the last mouse button (whatever it was) was
	// pressed or release.
	mods Mods
	// True if the mouse position is currently over a link.
	over_link bool
	// True if the mouse pointer is currently hidden.
	hidden bool
}

// Translates key state to mouse shape (cursor) state, based on a state
// machine.
//
// There are 4 current states:
//
// * text: starting state, displays a text bar.
// * default: default state when in a mouse tracking mode. (e.g. vim, etc).
//   Displays an arrow pointer.
// * pointer: default state when over a link. Displays a pointing finger.
// * crosshair: any above state can transition to this when the rectangle
//   select keys are pressed (ctrl/super+alt).
//
// Additionally, default can transition back to text if one of the shift keys
// are pressed during mouse tracking mode.
//
// Any secondary state transitions back to its default state when the
// appropriate keys are released.
//
// none is returned when the mouse shape does not need changing.
pub fn (self SurfaceMouse) key_to_mouse_shape() ?MouseShape {
	// Filter for appropriate key events
	if !eligible_mouse_shape_key_event(self.physical_key) {
		return none
	}

	// Exceptions: link hover or hidden state overrides any other shape
	// processing and does not change state.
	//
	// TODO: As we unravel mouse state, we can fix this to be more explicit.
	if self.over_link || self.hidden {
		return none
	}

	// Set our current default state
	mut current_shape_state := MouseShape.text
	if self.mouse_event != .none_ {
		// In mouse tracking mode, should be default (arrow pointer)
		current_shape_state = .default_
	} else {
		// Default terminal mode, should be text (text bar)
		current_shape_state = .text
	}

	// Transition table.
	//
	// TODO: This could be updated eventually to be a true transition table if
	// we move to a full stateful mouse surface, e.g. very specific inputs
	// transitioning state based on previous state, versus flags like "is the
	// mouse over a link", etc.
	match current_shape_state {
		.default_ {
			if is_mouse_mode_override_state(self.mods) && is_rectangle_select_state(self.mods) {
				// Crosshair (rectangle select), only set if we are also
				// overriding (e.g. shift+ctrl+alt)
				return .crosshair
			} else if is_mouse_mode_override_state(self.mods) {
				// Normal override state
				return .text
			} else {
				return .default_
			}
		}
		.text {
			if is_rectangle_select_state(self.mods) {
				// Crosshair (rectangle select)
				return .crosshair
			} else {
				return .text
			}
		}
		else {
			// Fall back on default state - should be unreachable
			return none
		}
	}
}

fn eligible_mouse_shape_key_event(physical_key Key) bool {
	return physical_key.ctrl_or_super() || physical_key.left_or_right_shift()
		|| physical_key.left_or_right_alt()
}

fn is_mouse_mode_override_state(mods Mods) bool {
	return mods.shift
}

// Returns true if our modifiers put us in a state where dragging
// should cause a rectangle select.
pub fn is_rectangle_select_state(mods Mods) bool {
	$if macos {
		return mods.alt
	} $else {
		return mods.ctrl_or_super() && mods.alt
	}
}
