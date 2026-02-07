module input

import gg

// KeyEvent represents a keyboard event.
pub struct KeyEvent {
pub mut:
	key    gg.KeyCode
	action KeyAction
	mods   gg.Modifier
	utf8   string
}

pub fn (e KeyEvent) binding_hash() u64 {
	mut h := u64(0)
	h = h * 31 + u64(e.key)
	h = h * 31 + u64(e.mods)
	return h
}

pub enum KeyAction {
	press
	repeat
	release
}

// Mods wraps gg.Modifier with helper methods.
pub struct Mods {
pub mut:
	shift   bool
	control bool
	alt     bool
	super_  bool
}

pub fn Mods.from_modifier(m gg.Modifier) Mods {
	return Mods{
		shift: (int(m) & int(gg.Modifier.shift)) != 0
		control: (int(m) & int(gg.Modifier.ctrl)) != 0
		alt: (int(m) & int(gg.Modifier.alt)) != 0
		super_: (int(m) & int(gg.Modifier.super)) != 0
	}
}

pub fn (a Mods) equal(b Mods) bool {
	return a.shift == b.shift && a.control == b.control && a.alt == b.alt && a.super_ == b.super_
}

pub fn (m Mods) binding() Mods {
	return m
}

pub fn (m Mods) empty() bool {
	return !m.shift && !m.control && !m.alt && !m.super_
}

pub enum MouseButton {
	left
	right
	middle
	button_4
	button_5
}

pub const mouse_button_max = 10

pub enum MouseButtonState {
	press
	release
}

pub enum MousePressureStage {
	none_
	light
	deep
}

pub enum OptionAsAlt {
	left
	right
	both
}

// Binding actions and sets.
pub struct Binding {
pub:
	action BindingAction
}

pub struct BindingAction {
pub:
	kind BindingActionKind
}

pub enum BindingActionKind {
	none_
	ignore
	csi
	esc
	text
	copy_to_clipboard
	paste_from_clipboard
	increase_font_size
	decrease_font_size
	reset_font_size
	set_font_size
	scroll_page_up
	scroll_page_down
	scroll_to_top
	scroll_to_bottom
	new_window
	new_tab
	close_surface
	close_window
	close_tab
	toggle_fullscreen
	inspector_toggle
	deactivate_key_table
	open_url
	write_screen_file
}

pub fn (a BindingAction) is_closing() bool {
	return a.kind in [.close_surface, .close_window, .close_tab]
}

pub struct BindingFlags {
pub:
	consumed    bool
	global      bool
	all         bool
	performable bool
}

pub struct BindingSet {}

pub fn (s BindingSet) get_event(event KeyEvent) ?BindingSetEntry {
	return none
}

pub struct BindingSetEntry {
pub:
	kind BindingSetEntryKind
}

pub enum BindingSetEntryKind {
	leader
	leaf
	leaf_chained
}

// Link matching.
pub struct Link {
pub:
	action    LinkAction
	highlight LinkHighlight
}

pub enum LinkAction {
	open
	open_osc8
}

pub enum LinkHighlight {
	always
	hover
	always_mods
	hover_mods
}

// Key encoding functions.

// encode takes a key event and terminal mode state and returns
// the byte sequence to send to the pty.
pub fn encode(event KeyEvent, opts EncodeOpts) ?[]u8 {
	if event.utf8.len > 0 {
		return event.utf8.bytes()
	}
	return none
}

pub struct EncodeOpts {
pub:
	bracketed_paste bool
	kitty_keyboard  bool
	modify_other    bool
}

// Paste encoding.
pub fn paste_encode(data string, bracketed bool) string {
	if bracketed {
		return '\x1b[200~${data}\x1b[201~'
	}
	return data
}

pub fn paste_is_unsafe(data string, bracketed bool) bool {
	if data.contains('\n') && !bracketed {
		return true
	}
	return false
}
