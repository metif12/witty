module input

// Keymap is the no-op implementation selected outside macOS.
pub struct Keymap {}

// KeymapState is empty because the no-op keymap has no composition state.
pub struct KeymapState {}

// KeymapTranslation is the result of translating a physical key.
pub struct KeymapTranslation {
pub:
	text      string
	composing bool
	mods      Mods
}

pub fn Keymap.init() !Keymap {
	return Keymap{}
}

pub fn (_ &Keymap) deinit() {}

pub fn (mut _ Keymap) reload() ! {}

// translate deliberately ignores every argument and returns the default
// translation, matching Ghostty's KeymapNoop implementation.
pub fn (_ &Keymap) translate(_ []u8, mut _ KeymapState, _ u16, _ Mods) !KeymapTranslation {
	return KeymapTranslation{}
}
