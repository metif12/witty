module input

#include "keymap_shims.h"

#flag darwin -framework Carbon

fn C.witty_keymap_current_source() voidptr

fn C.witty_keymap_unicode_layout(source voidptr) voidptr

fn C.witty_keymap_release(source voidptr)

fn C.witty_keymap_source_id(source voidptr, out &char, cap usize) int

fn C.witty_keymap_translate(layout voidptr, code u16, modifiers u32, dead_key &u32, out &char, cap usize, out_len &usize, composing &int) int

// Keymap is responsible for translating keyboard inputs into localized text.
pub struct Keymap {
mut:
	source         voidptr
	unicode_layout voidptr
}

// KeymapState is the opaque state threaded through consecutive translations.
pub struct KeymapState {
mut:
	dead_key u32
}

// KeymapTranslation is the result of translating a physical key.
pub struct KeymapTranslation {
pub:
	text      string
	composing bool
	mods      Mods
}

pub fn Keymap.init() !Keymap {
	mut keymap := Keymap{}
	keymap.reinit()!
	return keymap
}

pub fn (k &Keymap) deinit() {
	C.witty_keymap_release(k.source)
}

// reload must be called when the selected keyboard layout changes.
pub fn (mut k Keymap) reload() ! {
	C.witty_keymap_release(k.source)
	k.reinit()!
}

// source_id returns Apple's identifier for the current keyboard layout.
pub fn (k &Keymap) source_id(mut buf []u8) !string {
	if buf.len == 0 {
		return error('keyboard source ID buffer is empty')
	}
	if C.witty_keymap_source_id(k.source, unsafe { &char(buf.data) }, usize(buf.len)) != 0 {
		return error('keyboard source ID does not fit in buffer')
	}
	return unsafe { cstring_to_vstring(&char(buf.data)) }
}

// reinit acquires the current input source and its owned Unicode layout.
fn (mut k Keymap) reinit() ! {
	k.source = C.witty_keymap_current_source()
	if k.source == unsafe { nil } {
		return error('failed to get keyboard input source')
	}
	k.unicode_layout = C.witty_keymap_unicode_layout(k.source)
	if k.unicode_layout == unsafe { nil } {
		return error('failed to get keyboard Unicode layout')
	}
}

// translate maps a native macOS virtual key code through the selected input
// source. Ctrl is removed so Carbon does not turn Ctrl+C into byte 0x03.
pub fn (k &Keymap) translate(mut out []u8, mut state KeymapState, code u16, input_mods Mods) !KeymapTranslation {
	mut mods := input_mods
	mods.set_ctrl(false)
	modifier_state := (u32(if mods.super_() { 1 } else { 0 }) | u32(if mods.shift() {
		1 << 1
	} else {
		0
	}) | u32(if mods.caps_lock() {
		1 << 2
	} else {
		0
	}) | u32(if mods.alt() { 1 << 3 } else { 0 }))
	mut out_len := usize(0)
	mut composing := 0
	if C.witty_keymap_translate(k.unicode_layout, code, modifier_state, &state.dead_key, unsafe { &char(out.data) }, usize(out.len), &out_len, &composing) != 0 {
		return error('keyboard translation failed')
	}
	return KeymapTranslation{
		text: out[..out_len].bytestr()
		composing: composing != 0
		mods: mods
	}
}
