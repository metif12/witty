module main

import os
import encoding.hex
import strings
import vaxis
import vaxis.vxfw as fw

fn style(index int) vaxis.Style {
	return match index {
		0 {
			vaxis.Style{}
		}
		1 {
			vaxis.Style{
				fg:     vaxis.ColorIndex{
					index: 17
				}
				bg:     vaxis.ColorIndex{
					index: 231
				}
				bold:   true
				italic: true
			}
		}
		2 {
			vaxis.Style{
				fg:            vaxis.ColorRgb{
					rgb: [u8(1), 128, 255]!
				}
				bg:            vaxis.ColorRgb{
					rgb: [u8(99), 33, 2]!
				}
				ul:            vaxis.ColorIndex{
					index: 88
				}
				ul_style:      .curly
				bold:          true
				dim:           true
				italic:        true
				blink:         true
				reverse:       true
				invisible:     true
				strikethrough: true
			}
		}
		else {
			vaxis.Style{
				fg:      vaxis.ColorIndex{
					index: 99
				}
				bg:      vaxis.ColorIndex{
					index: 3
				}
				reverse: true
			}
		}
	}
}

fn link(index int) vaxis.CellHyperlink {
	return match index {
		0 {
			vaxis.CellHyperlink{}
		}
		1 {
			vaxis.CellHyperlink{
				uri:    'https://a'
				params: 'id=1'
			}
		}
		else {
			vaxis.CellHyperlink{
				uri:    'file:///b'
				params: 'id=2:foo=bar'
			}
		}
	}
}

fn bound(value string) ?u16 {
	if value == '-1' { return none }
	return u16(value.int())
}

fn observe(value &fw.Surface, rich &fw.RichText) string {
	mut out := strings.new_builder(128)
	out.write_string('${value.size.width},${value.size.height},${value.buffer.len},${int(value.widget.eql(rich.widget()))},${int(value.widget.event_handler == none)},${int(value.widget.capture_handler == none)},${int(value.cursor == none)},${value.children.len}|')
	for cell in value.buffer {
		mut style_id := 255
		for i in 0 .. 4 {
			if cell.style == style(i) { style_id = i }
		}
		out.write_string('${hex.encode(cell.char_.grapheme.bytes())}/${cell.char_.width},${style_id},${hex.encode(cell.link.uri.bytes())},${hex.encode(cell.link.params.bytes())},${int(cell.default_)},${int(cell.wrapped)},${int(cell.image != none)},${int(cell.scale.eql(vaxis.CellScale{}))};')
	}
	return out.str()
}

fn draw_text(text string, width ?u16, soft bool) ! {
	rich := fw.RichText{
		text:     [fw.TextSpan{ text: text }]
		softwrap: soft
		overflow: .clip
	}
	_ := rich.draw(fw.DrawContext{
		min:       fw.Size{}
		max:       fw.MaxSize{
			width: width
		}
		cell_size: fw.Size{}
	})!
}

fn trap(mode string) ! {
	fw.DrawContext.init(.unicode)
	match mode {
		'trap_parent' {
			rich := fw.RichText{
				text:        []fw.TextSpan{}
				width_basis: .parent
			}
			_ := rich.widget().draw(fw.DrawContext{
				min:       fw.Size{}
				max:       fw.MaxSize{}
				cell_size: fw.Size{}
			})!
		}
		'trap_cr0' {
			draw_text('\r', none, false)!
		}
		'trap_cr1' {
			draw_text('a\r', none, true)!
		}
		'trap_cr_range' {
			draw_text('ab\r', none, false)!
		}
		'trap_line_width' {
			draw_text('x'.repeat(65536), none, true)!
		}
		'trap_col' {
			draw_text('x'.repeat(65536), u16(1), false)!
		}
		'trap_rows' {
			draw_text('\n'.repeat(65536), none, false)!
		}
		'trap_nonadvancing' {
			draw_text('界', u16(1), true)!
		}
		'trap_area' {
			rich := fw.RichText{
				text: [fw.TextSpan{ text: 'a' }]
			}
			_ := rich.draw(fw.DrawContext{
				min:       fw.Size{
					width:  256
					height: 256
				}
				max:       fw.MaxSize{}
				cell_size: fw.Size{}
			})!
		}
		'trap_char_cast' {
			fw.DrawContext.init(.no_zwj)
			draw_text('👩\u200d'.repeat(128) + '👩', u16(65535), true)!
		}
		'trap_unicode' {
			draw_text('\x80\xcc\x81', u16(10), true)!
		}
		else {
			return error('UnknownTrap')
		}
	}

	eprintln('UNEXPECTED returned')
}

fn main() {
	if os.args[1].starts_with('trap_') {
		trap(os.args[1]) or { eprintln('UNEXPECTED error ${err}') }
		return
	}
	data := os.read_file(os.args[1]) or { panic(err) }
	mut index := 0
	for line in data.split_into_lines() {
		if line == '' { continue
		 }
		p := line.split('|')
		mut spans := []fw.TextSpan{}
		for i := 12; i < p.len; i += 3 {
			spans << fw.TextSpan{
				text:  (hex.decode(p[i]) or { panic(err) }).bytestr()
				style: style(p[i + 1].int())
				link:  link(p[i + 2].int())
			}
		}
		rich := fw.RichText{
			text:        spans
			softwrap:    p[5].int() != 0
			text_align:  unsafe { fw.TextAlign(p[6].int()) }
			overflow:    unsafe { fw.TextOverflow(p[7].int()) }
			width_basis: if p[8] == '0' { .parent } else { .longest_line }
			base_style:  style(p[10].int())
		}
		fw.DrawContext.init(unsafe { vaxis.GWidthMethod(p[9].int()) })
		ctx := fw.DrawContext{
			min:       fw.Size{
				width:  u16(p[1].int())
				height: u16(p[2].int())
			}
			max:       fw.MaxSize{
				width:  bound(p[3])
				height: bound(p[4])
			}
			cell_size: fw.Size{
				width:  10
				height: 20
			}
		}
		surface := if p[11] == '1' { rich.widget().draw(ctx) or { panic(err) } } else { rich.draw(ctx) or {
				panic(err)} }
		if p[0] == 'B' {
			for mut span in spans {
				if span.text.len != 0 {
					unsafe {
						span.text.str[0] = `Z`
					}
				}
				span.style = style(3)
			}
		}
		println('${index}|${observe(surface, &rich)}')
		index++
	}
}
