module main

import os
import zigimg
import encoding.hex

#flag -I @DIR
#flag -I @DIR/..
#include "fixture_shims.h"

fn C.witty_writer_seek_setup(&char) int
fn C.witty_writer_seek_replace(int) int
fn C.witty_writer_seek_restore(&char, uint) int
fn C.witty_writer_seek_close() int
fn C.witty_writer_seek_cleanup() int
fn C.witty_writer_seek_valid() int
fn C.witty_writer_seek_refs() int
fn C.witty_writer_seek_view(&u8, uint) int
fn C.witty_writer_seek_drain(&u8, uint) int

__global (
	observed_path    string
	observed_writer  = &zigimg.WriteStream(unsafe { nil })
	observed_buffer  []u8
	observed_file    bool
	observed_status  string
	observed_payload []u8
	observed_vectors [][]u8
	observed_header  []u8
)

fn state(writer zigimg.WriteStream, buffer []u8) string {
	mut contents := []u8{len: 4096}
	n := if observed_file {
		C.witty_writer_seek_view(contents.data, uint(contents.len))
	} else {
		int(0)
	}
	if n < 0 { panic('Writer observer failed') }
	valid := if observed_file { C.witty_writer_seek_valid() } else { 0 }
	refs := if observed_file { C.witty_writer_seek_refs() } else { 0 }
	unused := writer.unused_capacity_slice()
	offset := if buffer.len == 0 { uint(0) } else { uint(unused.data) - uint(buffer.data) }
	mut headers := [
		'${uint(observed_header.data) - uint(observed_payload.data)},${observed_header.len}',
	]
	for bytes in observed_vectors {
		headers << '${uint(bytes.data) - uint(observed_payload.data)},${bytes.len}'
	}
	inputs := observed_payload.hex() + '#' + headers.join(';')
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

fn vectors(mut payload []u8, profile int) [][]u8 {
	mut out := [][]u8{}
	match profile {
		0 {}
		1 {
			out << unsafe { payload[0..0] }
		}
		2 {
			out << unsafe { payload[0..1] }
		}
		3 {
			out << unsafe { payload[0..3] }
		}
		4 {
			out << unsafe { payload[0..2] }
			out << unsafe { payload[4..4] }
			out << unsafe { payload[6..9] }
		}
		5 {
			out << unsafe { payload[0..1] }
			out << unsafe { payload[0..1] }
			out << unsafe { payload[0..1] }
		}
		6 {
			out << unsafe { payload[2..6] }
			out << unsafe { payload[0..3] }
			out << unsafe { payload[3..8] }
			out << unsafe { payload[2..2] }
		}
		7 {
			out << unsafe { payload[0..1] }
			out << unsafe { payload[3..5] }
			out << unsafe { payload[6..9] }
			out << unsafe { payload[9..10] }
			out << unsafe { payload[12..14] }
			out << unsafe { payload[15..18] }
			out << unsafe { payload[18..19] }
			out << unsafe { payload[21..23] }
			out << unsafe { payload[24..27] }
			out << unsafe { payload[27..28] }
			out << unsafe { payload[30..32] }
			out << unsafe { payload[33..36] }
			out << unsafe { payload[36..37] }
			out << unsafe { payload[39..41] }
			out << unsafe { payload[42..45] }
		}
		8 {
			out << unsafe { payload[0..1] }
			out << unsafe { payload[3..5] }
			out << unsafe { payload[6..9] }
			out << unsafe { payload[9..10] }
			out << unsafe { payload[12..14] }
			out << unsafe { payload[15..18] }
			out << unsafe { payload[18..19] }
			out << unsafe { payload[21..23] }
			out << unsafe { payload[24..27] }
			out << unsafe { payload[27..28] }
			out << unsafe { payload[30..32] }
			out << unsafe { payload[33..36] }
			out << unsafe { payload[36..37] }
			out << unsafe { payload[39..41] }
			out << unsafe { payload[42..45] }
			out << unsafe { payload[45..46] }
		}
		9 {
			out << unsafe { payload[0..1] }
			out << unsafe { payload[3..5] }
			out << unsafe { payload[6..9] }
			out << unsafe { payload[9..10] }
			out << unsafe { payload[12..14] }
			out << unsafe { payload[15..18] }
			out << unsafe { payload[18..19] }
			out << unsafe { payload[21..23] }
			out << unsafe { payload[24..27] }
			out << unsafe { payload[27..28] }
			out << unsafe { payload[30..32] }
			out << unsafe { payload[33..36] }
			out << unsafe { payload[36..37] }
			out << unsafe { payload[39..41] }
			out << unsafe { payload[42..45] }
			out << unsafe { payload[45..46] }
			out << unsafe { payload[48..50] }
		}
		10 {
			out << unsafe { payload[0..1] }
			out << unsafe { payload[3..5] }
			out << unsafe { payload[6..9] }
			out << unsafe { payload[9..10] }
			out << unsafe { payload[12..14] }
			out << unsafe { payload[15..18] }
			out << unsafe { payload[18..19] }
			out << unsafe { payload[21..23] }
			out << unsafe { payload[24..27] }
			out << unsafe { payload[27..28] }
			out << unsafe { payload[30..32] }
			out << unsafe { payload[33..36] }
			out << unsafe { payload[36..37] }
			out << unsafe { payload[39..41] }
			out << unsafe { payload[42..45] }
			out << unsafe { payload[45..46] }
			out << unsafe { payload[48..50] }
			out << unsafe { payload[51..54] }
			out << unsafe { payload[54..55] }
			out << unsafe { payload[57..59] }
			out << unsafe { payload[60..63] }
			out << unsafe { payload[63..64] }
			out << unsafe { payload[66..68] }
			out << unsafe { payload[69..72] }
			out << unsafe { payload[72..73] }
			out << unsafe { payload[75..77] }
			out << unsafe { payload[78..81] }
			out << unsafe { payload[81..82] }
			out << unsafe { payload[84..86] }
			out << unsafe { payload[87..90] }
			out << unsafe { payload[90..91] }
			out << unsafe { payload[93..95] }
		}
		11 {
			out << unsafe { payload[0..1] }
			out << unsafe { payload[3..5] }
			out << unsafe { payload[6..9] }
			out << unsafe { payload[9..10] }
			out << unsafe { payload[12..14] }
			out << unsafe { payload[15..18] }
			out << unsafe { payload[18..19] }
			out << unsafe { payload[21..23] }
			out << unsafe { payload[24..27] }
			out << unsafe { payload[27..28] }
			out << unsafe { payload[30..32] }
			out << unsafe { payload[33..36] }
			out << unsafe { payload[36..37] }
			out << unsafe { payload[39..41] }
			out << unsafe { payload[42..45] }
			out << unsafe { payload[45..46] }
			out << unsafe { payload[48..50] }
			out << unsafe { payload[51..54] }
			out << unsafe { payload[54..55] }
			out << unsafe { payload[57..59] }
			out << unsafe { payload[60..63] }
			out << unsafe { payload[63..64] }
			out << unsafe { payload[66..68] }
			out << unsafe { payload[69..72] }
			out << unsafe { payload[72..73] }
			out << unsafe { payload[75..77] }
			out << unsafe { payload[78..81] }
			out << unsafe { payload[81..82] }
			out << unsafe { payload[84..86] }
			out << unsafe { payload[87..90] }
			out << unsafe { payload[90..91] }
			out << unsafe { payload[93..95] }
			out << unsafe { payload[96..99] }
		}
		12 {
			out << unsafe { payload[0..0] }
			out << unsafe { payload[1..4] }
			out << unsafe { payload[2..2] }
			out << unsafe { payload[3..6] }
			out << unsafe { payload[4..4] }
			out << unsafe { payload[5..8] }
			out << unsafe { payload[6..6] }
			out << unsafe { payload[7..10] }
			out << unsafe { payload[8..8] }
			out << unsafe { payload[9..12] }
			out << unsafe { payload[10..10] }
			out << unsafe { payload[11..14] }
			out << unsafe { payload[12..12] }
			out << unsafe { payload[13..16] }
			out << unsafe { payload[14..14] }
			out << unsafe { payload[15..18] }
		}
		13 {
			out << unsafe { payload[0..0] }
			out << unsafe { payload[1..4] }
			out << unsafe { payload[2..2] }
			out << unsafe { payload[3..6] }
			out << unsafe { payload[4..4] }
			out << unsafe { payload[5..8] }
			out << unsafe { payload[6..6] }
			out << unsafe { payload[7..10] }
			out << unsafe { payload[8..8] }
			out << unsafe { payload[9..12] }
			out << unsafe { payload[10..10] }
			out << unsafe { payload[11..14] }
			out << unsafe { payload[12..12] }
			out << unsafe { payload[13..16] }
			out << unsafe { payload[14..14] }
			out << unsafe { payload[15..18] }
			out << unsafe { payload[16..16] }
		}
		14 {
			out << unsafe { payload[0..0] }
			out << unsafe { payload[1..4] }
			out << unsafe { payload[2..2] }
			out << unsafe { payload[3..6] }
			out << unsafe { payload[4..4] }
			out << unsafe { payload[5..8] }
			out << unsafe { payload[6..6] }
			out << unsafe { payload[7..10] }
			out << unsafe { payload[8..8] }
			out << unsafe { payload[9..12] }
			out << unsafe { payload[10..10] }
			out << unsafe { payload[11..14] }
			out << unsafe { payload[12..12] }
			out << unsafe { payload[13..16] }
			out << unsafe { payload[14..14] }
			out << unsafe { payload[15..18] }
			out << unsafe { payload[16..16] }
			out << unsafe { payload[17..20] }
			out << unsafe { payload[18..18] }
			out << unsafe { payload[19..22] }
			out << unsafe { payload[20..20] }
			out << unsafe { payload[21..24] }
			out << unsafe { payload[22..22] }
			out << unsafe { payload[23..26] }
			out << unsafe { payload[24..24] }
			out << unsafe { payload[25..28] }
			out << unsafe { payload[26..26] }
			out << unsafe { payload[27..30] }
			out << unsafe { payload[28..28] }
			out << unsafe { payload[29..32] }
			out << unsafe { payload[30..30] }
			out << unsafe { payload[31..34] }
			out << unsafe { payload[32..32] }
		}
		15 {
			out << unsafe { payload[0..0] }
			out << unsafe { payload[1..1] }
			out << unsafe { payload[2..2] }
		}
		16 {
			out << unsafe { payload[4..5] }
			out << unsafe { payload[0..1] }
		}
		17 {
			out << unsafe { payload[4..5] }
			out << unsafe { payload[0..2] }
		}
		18 {
			out << unsafe { payload[4..4] }
			out << unsafe { payload[0..1] }
		}
		19 {
			out << unsafe { payload[0..32] }
			out << unsafe { payload[32..96] }
			out << unsafe { payload[16..144] }
		}
		20 {
			out << unsafe { payload[0..0] }
			out << unsafe { payload[0..0] }
			out << unsafe { payload[0..0] }
		}
		21 {
			out << unsafe { payload[0..255] }
		}
		else {
			panic('Invalid vector profile')
		}
	}

	return out
}

// kind|capacity|start|prefix-length|profile|repeat|binding|finish|api|mask|header-offset|header-length|limit
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
	mut payload := []u8{len: 256, init: u8(index * 23 + f[9].int())}
	data := vectors(mut payload, f[4].int())
	header := unsafe { payload[f[10].int()..f[10].int() + f[11].int()] }
	observed_header = unsafe { header }
	observed_payload = unsafe { payload }
	observed_vectors = unsafe { data }
	observed_status = 'setup'
	writer.seek_to(start) or {}
	writer.write_all([]u8{len: f[3].int(), init: u8(index * 31 + 7)}) or {
		panic('Prefix failed: ${err}')
	}
	if kind > 0 {
		if f[6] == '1' && C.witty_writer_seek_replace(1) != 0 { panic('Writer replacement failed') }
		if f[6] == '2' && C.witty_writer_seek_close() != 0 { panic('Writer close failed') }
	}
	mut out := 'setup|' + state(writer, buffer) + '~'
	mut adapter := writer.writer()
	api := f[8].int()
	out += 'ready|' + state(writer, buffer) + '~'
	observed_status = 'write'
	mut status := 'skip'
	mut count := uint(0)
	if api == 0 {
		count = adapter.write_splat_header(header, data, uint(f[5].u64())) or {
			status = err.msg()
			uint(0)
		}
	} else {
		count = adapter.write_splat_header_limit(header, data, uint(f[5].u64()),
			zigimg.Limit.limited(uint(f[12].u64()))) or {
			status = err.msg()
			uint(0)
		}
	}
	if status == 'skip' { status = 'write=${count}' }
	out += status + '|' + state(writer, buffer) + '~'
	change(mut buffer, 1, u8(f[9].int()))
	out += 'caller|' + state(writer, buffer) + '~'
	status = 'skip'
	if f[7] == '1' {
		status = 'ok'
		writer.flush() or { status = err.msg() }
	}
	out += status + '|' + state(writer, buffer) + '~'
	mut drain := int(-3)
	mut wire := []u8{}
	if kind > 0 && f[6] == '1' {
		for {
			mut bytes := []u8{len: 4096}
			drain = C.witty_writer_seek_drain(bytes.data, uint(bytes.len))
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
