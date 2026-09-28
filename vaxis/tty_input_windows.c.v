module vaxis

import log

#include <windows.h>

pub union C.VaxisInputRecordEvent {
	KeyEvent              C.KEY_EVENT_RECORD
	MouseEvent            C.MOUSE_EVENT_RECORD
	WindowBufferSizeEvent C.WINDOW_BUFFER_SIZE_RECORD
	FocusEvent            C.FOCUS_EVENT_RECORD
}

@[typedef]
pub struct C.INPUT_RECORD {
	EventType u16
	Event     C.VaxisInputRecordEvent
}

pub union C.VaxisInputChar {
	UnicodeChar u16
	AsciiChar   u8
}

@[typedef]
pub struct C.KEY_EVENT_RECORD {
	bKeyDown          i32
	wRepeatCount      u16
	wVirtualKeyCode   u16
	wVirtualScanCode  u16
	uChar             C.VaxisInputChar
	dwControlKeyState u32
}

@[typedef]
pub struct C.MOUSE_EVENT_RECORD {
	dwMousePosition   C.COORD
	dwButtonState     u32
	dwControlKeyState u32
	dwEventFlags      u32
}

@[typedef]
pub struct C.WINDOW_BUFFER_SIZE_RECORD {
	dwSize C.COORD
}

@[typedef]
pub struct C.FOCUS_EVENT_RECORD {
	bSetFocus i32
}

fn C.ReadConsoleInputW(handle voidptr, record &C.INPUT_RECORD, count u32, received &u32) bool

// The state local to WindowsTty.nextEvent. It is reset after each returned
// event, exactly as in the pinned loop.
struct WindowsInputState {
mut:
	ansi_buf   []u8
	utf16_high u16
	utf16_half bool
}

fn windows_key_modifiers(control u32) Modifiers {
	return Modifiers.init(control & 0x0010 != 0, control & 0x0003 != 0, control & 0x000c != 0,
		false, false, false, control & 0x0080 != 0, control & 0x0020 != 0)
}

fn windows_mouse_modifiers(control u32) MouseModifiers {
	return MouseModifiers.new(control & 0x0010 != 0, control & 0x0003 != 0, control & 0x000c != 0)
}

fn windows_key_base_layout(vk u16) ?u32 {
	return match vk {
		0x08 { backspace }
		0x09 { tab }
		0x0d { enter }
		0x13 { pause }
		0x14 { caps_lock }
		0x1b { escape }
		0x20 { space }
		0x21 { page_up }
		0x22 { page_down }
		0x23 { end }
		0x24 { home }
		0x25 { left }
		0x26 { up }
		0x27 { right }
		0x28 { down }
		0x2c { print_screen }
		0x2d { insert }
		0x2e { delete }
		0x30...0x39 { u32(vk) }
		0x41...0x5a { u32(vk) + 0x20 }
		0x5b { left_meta }
		0x5c { right_meta }
		0x60...0x69 { kp_0 + u32(vk) - 0x60 }
		0x6a { kp_multiply }
		0x6b { kp_add }
		0x6c { kp_separator }
		0x6d { kp_subtract }
		0x6e { kp_decimal }
		0x6f { kp_divide }
		0x70...0x75 { f1 + u32(vk) - 0x70 }
		0x76 { f8 } // Pinned vaxis maps both VK_F7 and VK_F8 to F8.
		0x77...0x86 { f8 + u32(vk) - 0x77 }
		0x90 { num_lock }
		0x91 { scroll_lock }
		0xa0, 0x10 { left_shift }
		0xa1 { right_shift }
		0xa2, 0x11 { left_control }
		0xa3 { right_control }
		0xa4, 0x12 { left_alt }
		0xa5 { right_alt }
		0xad { mute_volume }
		0xae { lower_volume }
		0xaf { raise_volume }
		0xb0 { media_track_next }
		0xb1 { media_track_previous }
		0xb2 { media_stop }
		0xb3 { media_play_pause }
		0xba { u32(`;`) }
		0xbb { u32(`+`) }
		0xbc { u32(`,`) }
		0xbd { u32(`-`) }
		0xbe { u32(`.`) }
		0xbf { u32(`/`) }
		0xc0 { u32(`\x60`) }
		0xdb { u32(`[`) }
		0xdc, 0xe2 { u32(`\\`) }
		0xdd { u32(`]`) }
		0xde { u32(`'`) }
		else { none }
	}
}

fn (mut tty Tty) windows_key_event(record C.KEY_EVENT_RECORD, mut state WindowsInputState) ?InputEvent {
	utf16 := unsafe { record.uChar.UnicodeChar }
	if state.utf16_half {
		state.utf16_half = false
		if utf16 >= 0xdc00 && utf16 <= 0xdfff {
			codepoint := u32(0x10000) + ((u32(state.utf16_high) - 0xd800) << 10) +
				(u32(utf16) - 0xdc00)
			key := Key{
				codepoint:             codepoint
				base_layout_codepoint: codepoint
				mods:                  windows_key_modifiers(record.dwControlKeyState)
				text:                  rune(codepoint).str()
			}
			return if record.bKeyDown == 0 { InputEvent(KeyRelease{
					key: key
				}) } else { InputEvent(key) }
		}
	}

	mut base := u32(0)
	if record.wVirtualKeyCode == 0 {
		ascii := unsafe { record.uChar.AsciiChar }
		if state.ansi_buf.len == 0 && ascii != 27 {
			base = u32(utf16)
		} else {
			state.ansi_buf << ascii
			if state.ansi_buf.len <= 2 {
				return none
			}
			parsed := parse_input(state.ansi_buf) or { return none }
			state.ansi_buf.clear()
			return parsed.event
		}
	} else {
		base = windows_key_base_layout(record.wVirtualKeyCode) or {
			log.warn('unknown wVirtualKeyCode: 0x${record.wVirtualKeyCode.hex()}')
			return none
		}
	}
	if base >= 0xd800 && base <= 0xdbff {
		state.utf16_high = u16(base)
		state.utf16_half = true
		return none
	}
	if base >= 0xdc00 && base <= 0xdfff {
		return none
	}

	mut codepoint := base
	mut text := ?string(none)
	if utf16 > 0x1f {
		codepoint = u32(utf16)
		text = rune(codepoint).str()
	}
	key := Key{
		codepoint:             codepoint
		base_layout_codepoint: base
		mods:                  windows_key_modifiers(record.dwControlKeyState)
		text:                  text
	}
	return if record.bKeyDown == 0 { InputEvent(KeyRelease{
			key: key
		}) } else { InputEvent(key) }
}

fn (mut tty Tty) windows_mouse_event(record C.MOUSE_EVENT_RECORD) ?InputEvent {
	wheel := i16(u16(record.dwButtonState >> 16))
	buttons := u16(record.dwButtonState)
	changed := tty.last_mouse_button_press ^ buttons
	tty.last_mouse_button_press = buttons
	mut event_type := MouseType.press
	mut button := MouseButton.none_
	match changed {
		0 {
			if record.dwEventFlags & 0x0004 != 0 {
				button = if wheel > 0 { .wheel_up } else { .wheel_down }
			} else if buttons > 0 && record.dwEventFlags & 0x0001 != 0 {
				event_type = .drag
				if buttons & 0x0001 != 0 {
					button = .left
				} else if buttons & 0x0002 != 0 {
					button = .right
				} else if buttons & 0x0004 != 0 {
					button = .middle
				} else if buttons & 0x0008 != 0 {
					button = .button_8
				} else if buttons & 0x0010 != 0 {
					button = .button_9
				}
			} else if record.dwEventFlags & 0x0001 != 0 {
				event_type = .motion
			}
		}
		0x0001 {
			button = .left
		}
		0x0002 {
			button = .right
		}
		0x0004 {
			button = .middle
		}
		0x0008 {
			button = .button_8
		}
		0x0010 {
			button = .button_9
		}
		else {
			log.warn('unknown mouse event button state: ${record.dwButtonState}')
			return none
		}
	}

	if changed != 0 && buttons & changed == 0 {
		event_type = .release
	}
	return InputEvent(Mouse{
		col:    u16(record.dwMousePosition.X)
		row:    u16(record.dwMousePosition.Y)
		mods:   windows_mouse_modifiers(record.dwControlKeyState)
		type_:  event_type
		button: button
	})
}

fn (mut tty Tty) next_console_input() !InputEvent {
	mut state := WindowsInputState{}
	for {
		mut count := u32(0)
		mut record := C.INPUT_RECORD{}
		if !C.ReadConsoleInputW(tty.stdin_handle, &record, 1, &count) {
			return error('ReadConsoleInputW failed')
		}
		if count == 0 {
			continue
		}
		match record.EventType {
			0x0001 {
				if event := tty.windows_key_event(unsafe { record.Event.KeyEvent }, mut state) {
					return event
				}
			}
			0x0002 {
				if event := tty.windows_mouse_event(unsafe { record.Event.MouseEvent }) {
					return event
				}
			}
			0x0004 {
				return InputEvent(tty.get_winsize()!)
			}
			0x0010 {
				focus := unsafe { record.Event.FocusEvent }
				return if focus.bSetFocus == 0 {
					InputEvent(FocusOut{})
				} else {
					InputEvent(FocusIn{})
				}
			}
			else {}
		}
	}
	panic('unreachable')
}
