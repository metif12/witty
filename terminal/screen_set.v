module terminal

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
pub struct ScreenSet {
pub mut:
	active_key ScreenKey = .primary
	active     &Screen = unsafe { nil }
mut:
	all map[ScreenKey]&Screen
}

pub enum ScreenKey as u8 {
	primary   = 0
	alternate = 1
}

pub fn ScreenSet.init(opts ScreenOptions) !ScreenSet {
	mut init_primary := Screen.init(opts.cols, opts.rows, opts.max_scrollback)
	mut primary := unsafe { &Screen(memdup(&init_primary, int(sizeof(Screen)))) }
	// This can't fail because the storage is always empty at this point
	// and the only fail-able case is that we have to evict images.
	primary.kitty_images.set_limit(mut primary, opts.kitty_image_storage_limit)
	return ScreenSet{
		active: primary
		all: {
			ScreenKey.primary: primary
		}
	}
}

pub fn (mut self ScreenSet) deinit() {
	for _, mut screen in self.all {
		screen.deinit()
	}
	self.all.clear()
}

// Get the screen for the given key, if it is initialized.
pub fn (self &ScreenSet) get(key ScreenKey) ?&Screen {
	return self.all[key] or { none }
}

// Get the screen for the given key, initializing it if necessary.
// If the screen for the key is not yet initialized, it will be
// created with the given column and row counts.
//
// This is the V translation of ScreenSet.getInit from the Zig source.
// The primary screen is always initialized, so this is mainly useful
// for lazily initializing the alternate screen on first use.
pub fn (mut self ScreenSet) get_init(key ScreenKey, opts ScreenOptions) !&Screen {
	// If already initialized, return it.
	if existing := self.get(key) {
		return existing
	}

	mut init_screen := Screen.init(opts.cols, opts.rows, opts.max_scrollback)
	mut screen := unsafe { &Screen(memdup(&init_screen, int(sizeof(Screen)))) }
	screen.kitty_images.set_limit(mut screen, opts.kitty_image_storage_limit)
	self.all[key] = screen
	return screen
}

// Remove a key from the set. The primary screen cannot be removed.
pub fn (mut self ScreenSet) remove(key ScreenKey) {
	assert key != .primary
	if mut screen := self.all[key] {
		screen.deinit()
		self.all.delete(key)
	}
}

// Switch the active screen to the given key. Requires that the screen is initialized.
pub fn (mut self ScreenSet) switch_to(key ScreenKey) {
	self.active_key = key
	self.active = self.all[key] or { panic('screen must be initialized before switching') }
}
