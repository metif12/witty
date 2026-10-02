module inspector

import cimgui
import encoding.utf8.validate

// Source: src/inspector/widgets/key.zig Event.render and its 1024-byte writers.
pub fn (event &KeyEvent) render(context cimgui.Context) {
	_ = context.begin_table('##event', 2, 0)
	defer { context.end_table() }
	if event.binding.len > 0 {
		detail_row(context, 'Triggered Binding')
		if context.begin_bindings_list('##bindings', usize(event.binding.len)) {
			for action in event.binding {
				_ = context.selectable(action.tag().str(), false)
			}
			context.end_list_box()
		}
	}
	detail_row(context, 'Encoding to Pty')
	if event.pty.len == 0 {
		context.text_disabled('(no data)')
	} else {
		event.render_pty(context) or { context.text_disabled('(error rendering pty data)') }
	}
	detail_row(context, 'Action')
	context.text(event.event.action.str())
	detail_row(context, 'Key')
	context.text(event.event.key.str())
	if !event.event.mods.empty() {
		detail_row(context, 'Mods')
		if event.event.mods.shift() { context.text('shift ') }
		if event.event.mods.ctrl() { context.text('ctrl ') }
		if event.event.mods.alt() { context.text('alt ') }
		if event.event.mods.super_() { context.text('super ') }
	}
	if event.event.composing {
		detail_row(context, 'Composing')
		context.text('true')
	}
	detail_row(context, 'UTF-8')
	if event.event.utf8.len == 0 {
		context.text_disabled('(empty)')
	} else {
		event.render_utf8(context) or { context.text_disabled('(error rendering utf-8)') }
	}
}

fn detail_row(context cimgui.Context, label string) {
	context.table_next_row()
	context.table_set_column(0)
	context.text(label)
	context.table_set_column(1)
}

struct FixedDiagnosticWriter {
mut:
	data []u8
	pos  int
}

fn (mut writer FixedDiagnosticWriter) write(text string) ! {
	// Zig fixedBufferStream.writeAll retains the prefix before NoSpaceLeft.
	available := writer.data.len - writer.pos
	count := if text.len < available { text.len } else { available }
	for index in 0 .. count {
		writer.data[writer.pos + index] = text[index]
	}
	writer.pos += count
	if count != text.len { return error('NoSpaceLeft') }
}

fn (event &KeyEvent) render_utf8(context cimgui.Context) ! {
	mut writer := FixedDiagnosticWriter{
		data: []u8{len: 1024}
	}
	if validate.utf8_string(event.event.utf8) {
		for cp in event.event.utf8.runes() {
			writer.write('U+${u32(cp):X} ')!
		}
	} else {
		writer.write('(invalid utf-8)')!
	}
	writer.write('\x00')!
	context.readonly_text('##utf8', mut writer.data[..writer.pos])
}

fn (event &KeyEvent) render_pty(context cimgui.Context) ! {
	mut writer := FixedDiagnosticWriter{
		data: []u8{len: 1024}
	}
	for byte in event.pty {
		if byte == 0x1b {
			writer.write('ESC ')!
			continue
		}
		if byte > 0x20 && byte < 0x7f {
			writer.write(byte.ascii_str())!
			continue
		}
		writer.write('0x${byte:X} ')!
	}
	writer.write('\x00')!
	context.readonly_text('##pty', mut writer.data[..writer.pos])
}

fn (writer &FixedDiagnosticWriter) written_text() string {
	end := if writer.pos > 0 && writer.data[writer.pos - 1] == 0 {
		writer.pos - 1
	} else {
		writer.pos
	}
	return writer.data[..end].bytestr()
}
