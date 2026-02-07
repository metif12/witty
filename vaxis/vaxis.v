module vaxis

// Stub module for the vaxis TUI library.
// XTODO: vaxis is a Zig TUI library with no V equivalent.
// This module provides type stubs so the code compiles.

// Color represents an RGB color.
pub struct Color {
pub:
	rgb [3]u8
}

// Scheme for color scheme detection.
pub enum Scheme {
	light
	dark
}

// Style represents text styling attributes.
pub struct Style {
pub:
	fg       Color
	bg       Color
	bold     bool
	italic   bool
	ul_style UnderlineStyle = .none_
}

// UnderlineStyle for text decoration.
pub enum UnderlineStyle {
	none_
	single
	double_
	dashed
	curly
	dotted
}

// Key represents a keyboard input.
pub struct Key {
pub:
	codepoint u32
	mods      Modifiers
}

// Predefined key constants.
pub const escape = u32(0x1b)
pub const enter = u32(0x0d)
pub const kp_enter = u32(0x010d)
pub const f1 = u32(0x0101)
pub const home = u32(0x0106)
pub const kp_home = u32(0x0206)
pub const end = u32(0x0107)
pub const kp_end = u32(0x0207)
pub const down = u32(0x0108)
pub const kp_down = u32(0x0208)
pub const up = u32(0x0109)
pub const kp_up = u32(0x0209)
pub const page_down = u32(0x010a)
pub const kp_page_up = u32(0x020b)
pub const kp_add = u32(0x020c)
pub const kp_subtract = u32(0x020d)

// Modifiers for key input.
pub struct Modifiers {
pub:
	ctrl  bool
	shift bool
}

// matches returns true if the key matches the given codepoint and modifiers.
pub fn (k Key) matches(cp u32, mods Modifiers) bool {
	return k.codepoint == cp && k.mods.ctrl == mods.ctrl && k.mods.shift == mods.shift
}

// matches_any returns true if the key matches any of the given codepoints with modifiers.
pub fn (k Key) matches_any(cps []u32, mods Modifiers) bool {
	for cp in cps {
		if k.matches(cp, mods) {
			return true
		}
	}
	return false
}

// Mouse represents a mouse event.
pub struct Mouse {
pub:
	button MouseButton
	type_  MouseType
	row    int
	col    int
}

pub enum MouseButton {
	none_
	left
	right
	wheel_up
	wheel_down
}

pub enum MouseType {
	press
	release
	motion
}

// Winsize represents window dimensions.
pub struct Winsize {
pub:
	rows u16
	cols u16
}

// Window represents a terminal window region for drawing.
pub struct Window {
pub:
	width  u16
	height u16
	x_off  u16
	y_off  u16
}

// Tty is a stub for terminal I/O.
pub struct Tty {}

// Vaxis is a stub for the vaxis TUI engine.
pub struct Vaxis {}

// TextInput is a stub for text input widget.
pub struct TextInput {
mut:
	text string
}

pub fn TextInput.new() TextInput {
	return TextInput{}
}

pub fn (mut t TextInput) deinit() {}

pub fn (t TextInput) real_length() int {
	return t.text.len
}

pub fn (t TextInput) get_text() string {
	return t.text
}

pub fn (mut t TextInput) clear_retaining_capacity() {
	t.text = ''
}
