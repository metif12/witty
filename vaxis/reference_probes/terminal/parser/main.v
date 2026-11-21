module main

import os
import encoding.hex
import vaxis
import zigimg

type ParamAlias = u16

fn decode(text string) []u8 { return hex.decode(text) or { panic(err) } }
fn optional_byte(text string) ?u8 { return if text == '-1' { ?u8(none) } else { ?u8(u8(text.int())) } }
fn opt(value ?u8) int { return if byte := value { int(byte) } else { -1 } }
fn unexpected(message string) { eprintln('UNEXPECTED: ${message}') }

fn event_text(event vaxis.TerminalParseEvent) string {
	return match event {
		vaxis.TerminalPrint { 'p:${hex.encode(event.bytes)}' }
		vaxis.TerminalControl { 'c:${u8(event.value)}' }
		vaxis.TerminalEscape { 'e:${hex.encode(event.bytes)}' }
		vaxis.TerminalSs2 { 's2:${event.byte}' }
		vaxis.TerminalSs3 { 's3:${event.byte}' }
		vaxis.TerminalCsi { 'i:${event.final}:${opt(event.private_marker)}:${opt(event.intermediate)}:${hex.encode(event.params)}' }
		vaxis.TerminalOsc { 'o:${hex.encode(event.bytes)}' }
		vaxis.TerminalApc { 'a:${hex.encode(event.bytes)}' }
	}
}
fn parser_case(parts []string, file_path string) string {
	data := decode(parts[1])
	capacity := parts[2].int()
	mut reader := zigimg.ReadStream.init_memory(data)
	mut file := os.File{}
	mut storage := []u8{len: if capacity < 0 { 0 } else { capacity }}
	if capacity >= 0 {
		os.write_file_array(file_path, data) or { panic(err) }
		file = os.open(file_path) or { panic(err) }
		reader = zigimg.ReadStream.init_file_streaming(file, mut storage)
	}
	defer { if capacity >= 0 { file.close() } }
	mut parser := vaxis.TerminalParser{buf: []u8{cap: 128}, pending_byte: optional_byte(parts[3])}
	mut output := []string{}
	for _ in 0 .. parts[4].int() {
		event := parser.parse_reader(mut reader) or {
			output << '!${err.msg()}@${reader.get_pos()}/${reader.buffered_len()}/${opt(parser.pending_byte)}/${hex.encode(parser.buf)}'
			break
		}
		output << '${event_text(event)}@${reader.get_pos()}/${reader.buffered_len()}/${opt(parser.pending_byte)}/${hex.encode(parser.buf)}'
	}
	return output.join(';')
}
fn iterator_case[T](parts []string) string {
	mut iter := vaxis.TerminalCsi{params: decode(parts[2]), final: `m`}.iterator[T]()
	iter.idx = parts[3].u64()
	mut output := []string{}
	for operation in parts[4].split(',') {
		value := if operation[0] == `n` {
			if result := iter.next() { 'v${u64(result)}' } else { '-' }
		} else {
			'h${int(iter.has_at_least(uint(operation[1..].u64())))}'
		}
		output << '${value}/${iter.idx}/${int(iter.next_is_sub)}/${int(iter.is_empty)}'
	}
	return output.join(';')
}
fn format_case(parts []string) string {
	seq := vaxis.TerminalCsi{params: decode(parts[1]), private_marker: optional_byte(parts[2]), intermediate: optional_byte(parts[3]), final: u8(parts[4].int())}
	mut storage := []u8{len: parts[5].int()}
	mut writer := zigimg.WriteStream.init_memory(mut storage)
	writer.write_all(decode(parts[6])) or { panic(err) }
	mut error_name := 'ok'
	seq.format(mut writer) or { error_name = err.msg() }
	mut intermediate := ''
	mut marker := ''
	for byte in [u8(0),0x20,0x3f,0xff] {
		intermediate += int(seq.has_intermediate(byte)).str()
		marker += int(seq.has_private_marker(byte)).str()
	}
	return '${error_name}/${writer.get_pos()}/${hex.encode(writer.buffered())}/${intermediate}/${marker}'
}
fn borrow_case(parts []string) string {
	mut parser := vaxis.TerminalParser{buf: []u8{cap: 128}}
	mut reader := zigimg.ReadStream.init_memory(decode(parts[1]))
	first := parser.parse_reader(mut reader) or { panic(err) }
	before := event_text(first)
	second := parser.parse_reader(mut reader) or { panic(err) }
	return '${before}/${event_text(second)}/${event_text(first)}/${reader.get_pos()}'
}
fn trap[T](text string, lookahead bool) {
	mut iter := vaxis.TerminalCsi{params: text.bytes(), final: `m`}.iterator[T]()
	if lookahead { iter.has_at_least(1) } else { iter.next() }
	unexpected('returned')
}
fn main() {
	if os.args[1].starts_with('trap') {
		match os.args[1][4..].int() {
			0 { trap[u8]('256', false) } 1 { trap[u8]('260', true) }
			2 { trap[u16]('65536', false) } 3 { trap[u16]('65540', true) }
			4 { trap[i16]('32768', false) } 5 { trap[i16]('32770', true) }
			6 { trap[u32]('4294967296', false) } 7 { trap[u32]('4294967300', true) }
			8 { trap[int]('2147483648', false) } 9 { trap[int]('2147483650', true) }
			10 { trap[u64]('18446744073709551616', false) } 11 { trap[u64]('18446744073709551620', true) }
			12 { trap[i64]('9223372036854775808', false) } 13 { trap[i64]('9223372036854775810', true) }
			14 { trap[uint]('18446744073709551616', false) } 15 { trap[int]('9223372036854775810', true) }
			else { panic('invalid trap') }
		}
		return
	}
	for line in (os.read_file(os.args[1]) or { panic(err) }).split_into_lines() {
		if line == '' { continue }
		parts := line.split('|')
		output := match parts[0] {
			'P' { parser_case(parts, os.args[2]) }
			'B' { borrow_case(parts) }
			'A' { format_case(parts) }
			'I' { match parts[1].int() {
				0 { iterator_case[u8](parts) } 1 { iterator_case[u16](parts) } 2 { iterator_case[i16](parts) }
				3 { iterator_case[u32](parts) } 4 { iterator_case[int](parts) } 5 { iterator_case[u64](parts) }
				6 { iterator_case[i64](parts) } 7 { iterator_case[uint](parts) } 8 { iterator_case[int](parts) }
				9 { iterator_case[ParamAlias](parts) }
				else { panic('invalid integer type') }
			} }
			else { panic('invalid case') }
		}
		println(output)
	}
}
