module inspector

import input
import encoding.utf8.validate

const max_key_events = 50

// KeyEvent is one keyboard event captured by the terminal inspector. It owns
// the cloned UTF-8, binding, and PTY data stored in its fields.
pub struct KeyEvent {
pub mut:
	event          input.KeyEvent
	binding        []input.Action
	pty            []u8
	imgui_selected bool
}

pub fn KeyEvent.init(event input.KeyEvent) KeyEvent {
	return KeyEvent{
		event: input.KeyEvent{
			...event
			utf8: event.utf8.clone()
		}
	}
}

pub fn (mut event KeyEvent) deinit() {
	event.event.utf8 = ''
	event.binding.clear()
	event.pty.clear()
}

// label is the text used for an event in the inspector's key stream.
pub fn (event &KeyEvent) label() string {
	mut result := match event.event.action {
		.press { 'Press: ' }
		.release { 'Release: ' }
		.repeat { 'Repeat: ' }
	}
	if event.event.mods.shift {
		result += 'Shift+'
	}
	if event.event.mods.ctrl {
		result += 'Ctrl+'
	}
	if event.event.mods.alt {
		result += 'Alt+'
	}
	if event.event.mods.super_ {
		result += 'Super+'
	}
	result += if event.event.key == .unidentified && event.event.utf8.len > 0 {
		event.event.utf8
	} else {
		event.event.key.str()
	}
	if event.event.composing {
		result += ' (composing)'
	}
	return result
}

// utf8_codepoints formats the event text exactly as the key detail widget.
pub fn (event &KeyEvent) utf8_codepoints() string {
	if !validate.utf8_string(event.event.utf8) {
		return '(invalid utf-8)'
	}
	mut result := ''
	for codepoint in event.event.utf8.runes() {
		result += 'U+${u32(codepoint):X} '
	}
	return result
}

// pty_text formats encoded PTY bytes exactly as the key detail widget: ESC is
// named, printable ASCII is literal, and other bytes are hexadecimal.
pub fn (event &KeyEvent) pty_text() string {
	mut result := ''
	for byte in event.pty {
		if byte == 0x1b {
			result += 'ESC '
		} else if byte > 0x20 && byte < 0x7f {
			result += byte.ascii_str()
		} else {
			result += '0x${byte:X} '
		}
	}
	return result
}

// Inspector owns the inspection streams associated with one terminal surface.
pub struct Inspector {
pub mut:
	key_events []KeyEvent
}

pub fn Inspector.init() !Inspector {
	return Inspector{
		key_events: []KeyEvent{cap: 2}
	}
}

pub fn (mut self Inspector) deinit() {
	self.clear_key_events()
}

pub fn (mut self Inspector) clear_key_events() {
	for mut event in self.key_events {
		event.deinit()
	}
	self.key_events.clear()
}

// record_key_event appends to Ghostty's bounded 50-event stream, evicting and
// deinitializing the oldest event after the limit is reached.
pub fn (mut self Inspector) record_key_event(event KeyEvent) bool {
	if self.key_events.len == max_key_events {
		mut oldest := self.key_events[0]
		oldest.deinit()
		self.key_events.delete(0)
	}
	self.key_events << event
	return true
}
