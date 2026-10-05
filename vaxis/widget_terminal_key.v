module vaxis

import zigimg

// src/widgets/terminal/key.zig. The source currently supports legacy presses;
// releases are empty, and nonzero Kitty flags on a press remain unreachable.
pub fn terminal_key_encode(mut writer zigimg.WriteStream, key Key, press bool, flags KittyFlags) ! {
	if !press { return }
	if flags.int() != 0 { panic('reached unreachable code') }
	if text := key.text { writer.write_all(text.bytes())!; return }
	mods := key.mods.int() & u8(7)
	if mods == 0 && key.codepoint <= 0x7f { writer.write_byte(u8(key.codepoint))!; return }
	if mods == 4 && key.codepoint >= `a` && key.codepoint <= `z` { writer.write_byte(u8(key.codepoint - 0x60))!; return }
	if mods == 2 && key.codepoint >= 0x20 && key.codepoint < 0x7f {
		writer.write_byte(0x1b)!
		writer.write_byte(u8(key.codepoint))!
		return
	}
	if mods == 6 && key.codepoint >= `a` && key.codepoint <= `z` {
		writer.write_byte(0x1b)!
		writer.write_all((key.codepoint - 0x60).str().bytes())!
	}
	definition := match key.codepoint {
		escape { TerminalKeyDefinition{27, `u`} }
		enter, kp_enter { TerminalKeyDefinition{13, `u`} }
		tab { TerminalKeyDefinition{9, `u`} }
		backspace { TerminalKeyDefinition{127, `u`} }
		insert, kp_insert { TerminalKeyDefinition{2, `~`} }
		delete, kp_delete { TerminalKeyDefinition{3, `~`} }
		left, kp_left { TerminalKeyDefinition{1, `D`} }
		right, kp_right { TerminalKeyDefinition{1, `C`} }
		up, kp_up { TerminalKeyDefinition{1, `A`} }
		down, kp_down { TerminalKeyDefinition{1, `B`} }
		page_up, kp_page_up { TerminalKeyDefinition{5, `~`} }
		page_down, kp_page_down { TerminalKeyDefinition{6, `~`} }
		home, kp_home { TerminalKeyDefinition{1, `H`} }
		end, kp_end { TerminalKeyDefinition{1, `F`} }
		f1 { TerminalKeyDefinition{1, `P`} }
		f2 { TerminalKeyDefinition{1, `Q`} }
		f3 { TerminalKeyDefinition{1, `R`} }
		f4 { TerminalKeyDefinition{1, `S`} }
		f5 { TerminalKeyDefinition{15, `~`} }
		f6 { TerminalKeyDefinition{17, `~`} }
		f7 { TerminalKeyDefinition{18, `~`} }
		f8 { TerminalKeyDefinition{19, `~`} }
		f9 { TerminalKeyDefinition{20, `~`} }
		f10 { TerminalKeyDefinition{21, `~`} }
		f11 { TerminalKeyDefinition{23, `~`} }
		f12 { TerminalKeyDefinition{24, `~`} }
		else { return }
	}
	if mods == 0 {
		if definition.number == 1 {
			writer.write_all(if key.codepoint >= f1 && key.codepoint <= f4 { '\x1bO'.bytes() } else { '\x1b['.bytes() })!
		} else {
			writer.write_all('\x1b['.bytes())!
			writer.write_all(definition.number.str().bytes())!
		}
	} else {
		writer.write_all('\x1b['.bytes())!
		writer.write_all(definition.number.str().bytes())!
		writer.write_byte(`;`)!
		writer.write_all((mods + u8(1)).str().bytes())!
	}
	writer.write_byte(definition.suffix)!
}

struct TerminalKeyDefinition {
	number u32
	suffix u8
}
