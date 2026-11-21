module main

import encoding.hex
import os
import strconv
import strings
import vaxis
import vaxis.vxfw

fn trap(mode string) {
	if mode == 'trap_iter_underflow' {
		mut iter := vaxis.grapheme_iterator('\xff\xcc\x81')
		iter.next()
	} else if mode == 'trap_context_underflow' {
		context := vxfw.DrawContext{
			min:       vxfw.Size{}
			max:       vxfw.MaxSize{}
			cell_size: vxfw.Size{}
		}
		mut iter := context.grapheme_iterator('\xff\xcc\x81')
		iter.next()
	} else if mode.starts_with('trap_width_underflow_') {
		method := if mode.ends_with('unicode') {
			vaxis.GWidthMethod.unicode
		} else {
			vaxis.GWidthMethod.no_zwj
		}
		vaxis.gwidth('\xff\xcc\x81', method)
	} else if mode.starts_with('trap_width_ascii_') || mode.starts_with('trap_width_wide_') {
		wide := mode.starts_with('trap_width_wide_')
		text := if wide { '界'.repeat(32768) } else { 'a'.repeat(65536) }
		method := if mode.ends_with('unicode') {
			vaxis.GWidthMethod.unicode
		} else if mode.ends_with('wcwidth') {
			vaxis.GWidthMethod.wcwidth
		} else {
			vaxis.GWidthMethod.no_zwj
		}
		vaxis.gwidth(text, method)
	} else if mode == 'trap_width_split' {
		vaxis.gwidth('a'.repeat(32768) + '\u200d' + 'a'.repeat(32768), .no_zwj)
	} else if mode == 'trap_span_add' {
		vaxis.Grapheme{
			start: ~uint(0)
			len:   1
		}.bytes('')
	} else if mode == 'trap_span_bound' {
		vaxis.Grapheme{
			start: 1
			len:   2
		}.bytes('ab')
	} else if mode == 'trap_span_start' {
		vaxis.Grapheme{
			start: ~uint(0)
			len:   0
		}.bytes('ab')
	} else {
		panic('InvalidTrap')
	}
	println('UNEXPECTED')
}

fn mutate(mut text []u8, spec string) {
	for change in spec.split(',') {
		if change.len == 0 { continue
		 }
		fields := change.split(':')
		index := strconv.atoi(fields[0]) or { panic(err) }
		text[index] = u8(strconv.parse_uint(fields[1], 16, 8) or { panic(err) })
	}
}

fn view(mut out strings.Builder, bytes ?string, text string) {
	if value := bytes {
		start := unsafe { uint(value.str) - uint(text.str) }
		out.write_string('${start},${value.len}:${hex.encode(value.bytes())}')
	} else {
		out.write_string('none')
	}
	out.write_string(';')
}

fn span_bytes(span ?vaxis.Grapheme, text string) ?string {
	value := span or { return none }
	return value.bytes(text)
}

fn mutable_row(number int, original string, initial string, later string) {
	mut backing := original.bytes()
	text := if backing.len > 0 { unsafe { tos(backing.data, backing.len) } } else { '' }
	mut iter := vaxis.GraphemeIterator.init(text)
	mut factory := vaxis.grapheme_iterator(text)
	context := vxfw.DrawContext{
		min:       vxfw.Size{}
		max:       vxfw.MaxSize{}
		cell_size: vxfw.Size{}
	}
	mut framework := context.grapheme_iterator(text)
	mutate(mut backing, initial)
	first := span_bytes(iter.next(), text)
	second := span_bytes(factory.next(), text)
	third := framework.next()
	mutate(mut backing, later)
	mut out := strings.new_builder(256)
	out.write_string('${number}|M|')
	view(mut out, first, text)
	view(mut out, second, text)
	view(mut out, third, text)
	for _ in 0 .. text.len + 3 {
		out.write_string('|')
		view(mut out, span_bytes(iter.next(), text), text)
		view(mut out, span_bytes(factory.next(), text), text)
		view(mut out, framework.next(), text)
	}
	println(out.str())
}

fn main() {
	if os.args[1].starts_with('trap_') {
		trap(os.args[1])
		return
	}
	content := os.read_file(os.args[1]) or { panic(err) }
	mut number := 0
	for line in content.split_into_lines() {
		if line.len == 0 { continue
		 }
		parts := line.split('|')
		unit := (hex.decode(parts[1]) or { panic(err) }).bytestr()
		repeat := strconv.atoi(parts[2]) or { panic(err) }
		text := unit.repeat(repeat)
		if parts[0] == 'M' {
			mutable_row(number, text, parts[3], parts[4])
			number++
			continue
		}
		mut out := strings.new_builder(128)
		out.write_string('${number}|${vaxis.gwidth(text, .unicode)},${vaxis.gwidth(text, .wcwidth)},${vaxis.gwidth(text,
			.no_zwj)}|')
		mut iter := vaxis.GraphemeIterator.init(text)
		mut other := vaxis.grapheme_iterator(text)
		context := vxfw.DrawContext{
			min:       vxfw.Size{}
			max:       vxfw.MaxSize{}
			cell_size: vxfw.Size{}
		}
		mut framework := context.grapheme_iterator(text)
		for method in [vaxis.GWidthMethod.unicode, .wcwidth, .no_zwj] {
			vxfw.DrawContext.init(method)
			if context.string_width(text) != uint(vaxis.gwidth(text, method)) {
				panic('ContextWidthMismatch')
			}
		}
		mut count := 0
		mut first := uint(0)
		mut last := uint(0)
		for {
			span := iter.next() or { break }
			alt := other.next() or { panic('FactoryMismatch') }
			if span.start != alt.start || span.len != alt.len { panic('FactoryMismatch') }
			if count == 0 { first = span.len }
			last = span.len
			count++
			bytes := span.bytes(text)
			fw := framework.next() or { panic('ContextIteratorMismatch') }
			if fw != bytes || unsafe { fw.str != bytes.str } { panic('ContextIteratorMismatch') }
			borrowed := unsafe { uint(bytes.str) == uint(text.str) + span.start }
			if parts[0] == 'S' {
				out.write_string('${span.start},${span.len},${int(borrowed)}:${hex.encode(bytes.bytes())};')
			} else if !borrowed {
				panic('NotBorrowed')
			}
		}
		mut exhausted := true
		for _ in 0 .. 3 {
			if iter.next() != none || other.next() != none || framework.next() != none {
				exhausted = false
			}
		}
		if parts[0] == 'B' {
			span := vaxis.Grapheme{
				start: uint(strconv.parse_uint(parts[3], 10, 64) or { panic(err) })
				len:   uint(strconv.parse_uint(parts[4], 10, 64) or { panic(err) })
			}
			bytes := span.bytes(text)
			borrowed := unsafe { uint(bytes.str) == uint(text.str) + span.start }
			out.write_string('${span.start},${span.len},${int(borrowed)}:${hex.encode(bytes.bytes())}')
		}
		if vaxis.first_grapheme_byte_length(text) != int(first) { panic('FirstLengthMismatch') }
		out.write_string('|${count},${first},${last},${int(exhausted)}')
		println(out.str())
		number++
	}
}
