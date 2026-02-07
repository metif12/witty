module terminal

// ScreenSet supplementary functions.
// Translated from Ghostty's terminal/ScreenSet.zig.
//
// A ScreenSet holds multiple terminal screens. This is initially created
// to handle simple primary vs alternate screens, but could be extended
// in the future to handle N screens.
//
// One of the goals of this is to allow lazy initialization of screens
// as needed. The primary screen is always initialized, but the alternate
// screen may not be until first used.
//
// The core ScreenSet struct, ScreenKey enum, and primary methods
// (init, deinit, get, switch_to, remove) are defined in terminal.v.
// This file provides additional helper methods.

// ============================================================
// ScreenSet helper methods
// ============================================================

// Get the screen for the given key, initializing it if necessary.
// If the screen for the key is not yet initialized, it will be
// created with the given column and row counts.
//
// This is the V translation of ScreenSet.getInit from the Zig source.
// The primary screen is always initialized, so this is mainly useful
// for lazily initializing the alternate screen on first use.
pub fn (mut self ScreenSet) get_or_init(key ScreenKey, cols u32, rows u32, max_scrollback u32) !&Screen {
	// If already initialized, return it.
	if mut existing := self.get(key) {
		return existing
	}
	// Initialize the screen. Only the alternate screen can be
	// lazily initialized; the primary is always present.
	match key {
		.alternate {
			mut init_screen := Screen.init(cols, rows, max_scrollback)
			self.alternate_ptr = unsafe { &Screen(memdup(&init_screen, int(sizeof(Screen)))) }
			return self.alternate_ptr
		}
		.primary {
			// Primary is always initialized; this should not happen.
			return &self.primary
		}
	}
}

// Returns true if the given screen key is the currently active screen.
pub fn (self &ScreenSet) is_active(key ScreenKey) bool {
	return self.active_key == key
}

// Returns a reference to the inactive screen, if it is initialized.
// For example, if the primary screen is active, this returns the
// alternate screen (if initialized), and vice versa.
pub fn (mut self ScreenSet) get_inactive() ?&Screen {
	inactive_key := match self.active_key {
		.primary { ScreenKey.alternate }
		.alternate { ScreenKey.primary }
	}
	return self.get(inactive_key)
}
