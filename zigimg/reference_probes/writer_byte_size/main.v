module main

import os
import zigimg

#flag -I @DIR
#flag -I @DIR/..
#include "fixture_shims.h"

fn C.witty_writer_seek_setup(&char) int
fn C.witty_writer_seek_replace(int) int
fn C.witty_writer_seek_restore(&char, usize) int
fn C.witty_writer_seek_close() int
fn C.witty_writer_seek_cleanup() int
fn C.witty_writer_seek_valid() int
fn C.witty_writer_seek_refs() int
fn C.witty_writer_seek_view(&u8, usize) isize
fn C.witty_writer_seek_drain(&u8, usize) isize

__global (
	observed_path    string
	observed_writer  = &zigimg.WriteStream(unsafe { nil })
	observed_buffer  []u8
	observed_file    bool
	observed_status  string
	observed_payload []u8
	observed_vectors [][]u8
	observed_options zigimg.FormatOptions
	observed_tag     int
)

fn state(writer zigimg.WriteStream, buffer []u8) string {
	mut contents := []u8{len: 4096}
	n := if observed_file {
		C.witty_writer_seek_view(contents.data, usize(contents.len))
	} else {
		isize(0)
	}
	if n < 0 { panic('Writer observer failed') }
	valid := if observed_file { C.witty_writer_seek_valid() } else { 0 }
	refs := if observed_file { C.witty_writer_seek_refs() } else { 0 }
	unused := writer.unused_capacity_slice()
	offset := if buffer.len == 0 { usize(0) } else { usize(unused.data) - usize(buffer.data) }
	mut headers := []string{}
	for bytes in observed_vectors {
		headers << '${usize(bytes.data) - usize(observed_payload.data)},${bytes.len}'
	}
	precision := if value := observed_options.precision { '${value}' } else { '-' }
	width := if value := observed_options.width { '${value}' } else { '-' }
	inputs := observed_payload.hex() + '#' + headers.join(';') +
		'#${precision}:${width}:${int(observed_options.alignment)}:${observed_options.fill}:${observed_tag}'
	return '${writer.get_pos()}:${writer.unused_capacity_len()}:${writer.buffered().len}:${offset}:${valid}:${refs}|${buffer.hex()}|${writer.buffered().hex()}|${unused.hex()}|${inputs}|${contents[..int(n)].hex()}'
}

fn observe() {
	if observed_path == '' { return }
	retained := observed_status + '|' + state(*observed_writer, observed_buffer)
	os.write_file(observed_path, retained) or { eprintln('OBSERVER ERROR: ${err}') }
	if observed_file { C.witty_writer_seek_cleanup() }
}

fn change(mut bytes []u8, mode int, mask u8) {
	if mode == 0 || bytes.len == 0 { return }
	index := if mode == 1 { 0 } else { bytes.len - 1 }
	bytes[index] ^= mask
}

fn operate(mut writer zigimg.WriteStream, value u64, units int, op int, options zigimg.FormatOptions) string {
	_ = op
	writer.print_byte_size(value, unsafe { zigimg.ByteSizeUnits(units) }, options) or {
		return err.msg()
	}
	return 'ok'
}

// kind|capacity|start|prefix-length|binding|finish|api|fill|alignment|width|width-present|precision|value|units
fn record(line string, path string) string {
	f := line.split('|')
	kind, cap, start := f[0].int(), f[1].int(), f[2].u64()
	mut buffer := []u8{len: cap, init: u8(index * 17 + 165)}
	mut writer := zigimg.WriteStream.init_memory(mut buffer)
	if kind > 0 {
		fd := C.witty_writer_seek_setup(path.str)
		restored := path + '.restored'
		if fd < 0 || C.witty_writer_seek_restore(restored.str, 32) != 0 {
			panic('Writer setup failed')
		}
		writer = if kind == 1 { zigimg.WriteStream.init_file(os.File{ fd: fd }, mut buffer) } else { zigimg.WriteStream.init_file_streaming(os.File{
				fd: fd
			}, mut buffer) }
	}
	defer {
		if kind > 0 && C.witty_writer_seek_cleanup() != 0 { panic('Writer cleanup failed') }
	}
	observed_writer = unsafe { &writer }
	observed_buffer = unsafe { buffer }
	observed_file = kind > 0
	raw := f[12].u64()
	mut payload := []u8{len: 8, init: u8(raw >> (index * 8))}
	data := unsafe { payload[..] }
	observed_tag = f[13].int()
	precision := if f[11] == '-' { ?usize(none) } else { ?usize(usize(f[11].u64())) }
	width := if f[10] == '1' { ?usize(usize(f[9].u64())) } else { ?usize(none) }
	options := zigimg.FormatOptions{
		precision: precision
		width:     width
		alignment: unsafe { zigimg.Alignment(f[8].int()) }
		fill:      u8(f[7].int())
	}
	observed_options = options
	observed_payload = unsafe { payload }
	observed_vectors = [][]u8{}
	observed_vectors << unsafe { data }
	observed_status = 'setup'
	writer.seek_to(start) or {}
	writer.write_all([]u8{len: f[3].int(), init: u8(index * 31 + 7)}) or {
		panic('Prefix failed: ${err}')
	}
	if kind > 0 {
		if f[4] == '1' && C.witty_writer_seek_replace(1) != 0 { panic('Writer replacement failed') }
		if f[4] == '2' && C.witty_writer_seek_close() != 0 { panic('Writer close failed') }
	}
	mut out := 'setup|' + state(writer, buffer) + '~'
	mut adapter := writer.writer()
	api := f[6].int()
	out += 'ready|' + state(writer, buffer) + '~'
	observed_status = 'write'
	mut status := 'skip'
	status = operate(mut adapter, raw, f[13].int(), api, options)
	if status == 'skip' { status = 'ok' }
	out += status + '|' + state(writer, buffer) + '~'
	change(mut buffer, 1, u8(f[7].int()))
	out += 'caller|' + state(writer, buffer) + '~'
	status = 'skip'
	if f[5] == '1' {
		status = 'ok'
		writer.flush() or { status = err.msg() }
	}
	out += status + '|' + state(writer, buffer) + '~'
	mut drain := isize(-3)
	mut wire := []u8{}
	if kind > 0 && f[4] == '1' {
		for {
			mut bytes := []u8{len: 4096}
			drain = C.witty_writer_seek_drain(bytes.data, usize(bytes.len))
			if drain <= 0 { break
			 }
			wire << bytes[..int(drain)]
		}
	}
	return out + '${drain}:${wire.hex()}'
}

fn main() {
	if os.args[1] == '--trap' {
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		result := record(os.args[3], os.args[2] + '.owned')
		observed_path = ''
		println(result)
		return
	}
	for i, line in (os.read_lines(os.args[1]) or { panic(err) }) {
		println(record(line, os.args[1] + '.${i}.owned'))
	}
}
