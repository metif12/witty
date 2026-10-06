module main

import os
import encoding.hex
import vaxis

fn decode(text string) []u8 {
	return hex.decode(text) or { panic('fixture hex') }
}

fn optional(cp ?u32) i64 {
	return if value := cp { i64(value) } else { -1 }
}

fn key(k vaxis.Key) string {
	return '${k.codepoint},${k.mods.int()},${optional(k.shifted_codepoint)},${optional(k.base_layout_codepoint)},${if text := k.text {
		hex.encode(text.bytes())
	} else {
		'-'
	}}'
}

fn event(e vaxis.InputEvent) string {
	return match e {
		vaxis.Key {
			'k:${key(e)}'
		}
		vaxis.KeyRelease {
			'r:${key(e.key)}'
		}
		vaxis.Mouse {
			'm:${u8(e.button)},${u8(e.type_)},${e.col},${e.row},${e.xoffset},${e.yoffset},${u8(e.mods.shift()) | (u8(e.mods.alt()) << 1) | (u8(e.mods.ctrl()) << 2)}'
		}
		vaxis.MouseLeave {
			'leave'
		}
		vaxis.FocusIn {
			'in'
		}
		vaxis.FocusOut {
			'out'
		}
		vaxis.PasteStart {
			'start'
		}
		vaxis.PasteEnd {
			'end'
		}
		vaxis.Paste {
			'p:${hex.encode(e.text.bytes())}'
		}
		vaxis.ColorScheme {
			's:${u8(e.scheme)}'
		}
		vaxis.Winsize {
			'w:${e.rows},${e.cols},${e.x_pixel},${e.y_pixel}'
		}
		vaxis.ColorReport {
			'c:${match e.kind {
				vaxis.ColorReportFg { 'f' }
				vaxis.ColorReportBg { 'b' }
				vaxis.ColorReportCursor { 'c' }
				vaxis.ColorReportIndex { 'i${e.kind.index}' }
			}},${e.value[0]},${e.value[1]},${e.value[2]}'
		}
		vaxis.CapabilityEvent {
			'cap:${u8(e.capability)}'
		}
	}
}

fn result(r vaxis.ParserResult) string {
	return '${r.n}:${if e := r.event {
		event(e)
	} else {
		'-'
	}}'
}

fn scratch(p &vaxis.Parser) string {
	return hex.encode(unsafe { (&p.buf[0]).vbytes(128) })
}

fn parse_case(parts []string) string {
	mut p := vaxis.Parser{
		buf: [128]u8{init: 17}
	}
	r := p.parse(decode(parts[1]), parts[2] == '1') or { return '!${err.msg()}/${scratch(p)}' }
	return '${result(r)}/${scratch(p)}'
}

fn borrow_case(parts []string) string {
	mut p := vaxis.Parser{
		buf: [128]u8{init: 17}
	}
	mut bytes := decode(parts[1])
	first := p.parse(bytes, false) or { panic('fixture first') }
	before := result(first)
	bytes[0] = `Q`
	p.buf[0] = `Z`
	mutated := result(first)
	next := p.parse(decode(parts[2]), false) or { panic('fixture next') }
	return '${before}/${mutated}/${result(next)}/${result(first)}/${scratch(p)}'
}

fn main() {
	if os.args[1] == 'trap' {
		mut p := vaxis.Parser{
			buf: [128]u8{init: 17}
		}
		p.parse(decode(os.args[2]), os.args[3] == '1') or {
			println('UNEXPECTED error ${err.msg()}')
			return
		}
		println('UNEXPECTED return')
		return
	}
	for line in (os.read_file(os.args[1]) or { panic(err) }).split_into_lines() {
		if line == '' { continue
		 }
		parts := line.split('|')
		println(if parts[0] == 'P' { parse_case(parts) } else { borrow_case(parts) })
	}
}
