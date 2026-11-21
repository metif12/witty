module zigimg

import os

fn test_aligned_writer_padding_and_default_options() {
	mut bytes := []u8{len: 32, init: 165}
	mut writer := WriteStream.init_memory(mut bytes)
	writer.align_buffer('a'.bytes(), 4, .left, `.`)!
	writer.align_buffer('bc'.bytes(), 5, .center, `-`)!
	writer.align_buffer('d'.bytes(), 3, .right, `_`)!
	assert writer.buffered() == 'a...-bc--__d'.bytes()
	options := FormatOptions{}
	assert options.width == none && options.precision == none
	assert options.alignment == .right && options.fill == ` `
	writer.align_buffer_options('ef'.bytes(), options)!
	assert writer.buffered() == 'a...-bc--__def'.bytes()
	mut specified := FormatOptions{
		width:     uint(5)
		precision: ~uint(0)
		alignment: .center
		fill:      `+`
	}
	writer.align_buffer_options('g'.bytes(), specified)!
	specified.width = none
	specified.fill = `x`
	writer.align_buffer_options('hi'.bytes(), specified)!
	assert writer.buffered() == 'a...-bc--__def++g++hi'.bytes()
}

fn test_aligned_writer_failure_keeps_padding_and_partial_payload() {
	mut bytes := []u8{len: 4, init: 165}
	mut writer := WriteStream.init_memory(mut bytes)
	mut status := 'ok'
	writer.align_buffer('abc'.bytes(), 6, .center, `.`) or { status = err.msg() }
	assert status == 'WriteFailed' && writer.buffered() == '.abc'.bytes()
	assert writer.get_pos() == 4
}

fn test_aligned_writer_file_output_uses_complete_padding_writes() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-writer-align-${os.getpid()}.owned')
		mut file := os.create(path)!
		defer { os.rm(path) or {} }
		mut bytes := []u8{len: 3, init: 165}
		mut writer := WriteStream.init_file(file, mut bytes)
		writer.align_buffer('ab'.bytes(), 7, .center, `.`)!
		writer.align_buffer_options('c'.bytes(), FormatOptions{ width: uint(3), fill: `_` })!
		writer.flush()!
		file.close()
		assert os.read_bytes(path)! == '..ab...__c'.bytes()
	}
}
