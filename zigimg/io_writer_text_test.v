module zigimg

fn test_text_writer_raw_bytes_and_ignored_precision() {
	mut bytes := []u8{len: 16}
	mut writer := WriteStream.init_memory(mut bytes)
	writer.print_ascii_char(255, FormatOptions{ width: usize(3), fill: `.` })!
	writer.print_ascii([u8(0), 128], FormatOptions{
		precision: usize(0)
		width:     usize(4)
		alignment: .left
		fill:      `_`
	})!
	assert writer.buffered() == [u8(`.`), `.`, 255, 0, 128, `_`, `_`]
}

fn test_text_writer_unicode_replacement_and_utf8_boundaries() {
	mut bytes := []u8{len: 64}
	mut writer := WriteStream.init_memory(mut bytes)
	for c in [u32(0), 0x7f, 0x80, 0x7ff, 0x800, 0xd800, 0xdfff, 0xffff, 0x10000, 0x10ffff, 0x110000,
		0x1fffff] {
		writer.print_unicode_codepoint(c)!
	}
	assert writer.buffered().hex() == '007fc280dfbfe0a080efbfbdefbfbdefbfbff0908080f48fbfbfefbfbdefbfbd'
}

fn test_text_writer_hex_and_base64_padding() {
	mut bytes := []u8{len: 64}
	mut writer := WriteStream.init_memory(mut bytes)
	writer.print_hex([u8(0), 171, 255], .lower)!
	writer.print_hex([u8(0), 171, 255], .upper)!
	for input in ['', 'f', 'fo', 'foo', 'foob', 'fooba', 'foobar'] {
		writer.print_base64(input.bytes())!
	}
	assert writer.buffered().bytestr() == '00abff00ABFFZg==Zm8=Zm9vZm9vYg==Zm9vYmE=Zm9vYmFy'
}

fn test_text_writer_partial_failures_keep_original_write_boundaries() {
	mut bytes := []u8{len: 3, init: 165}
	mut writer := WriteStream.init_memory(mut bytes)
	mut status := 'ok'
	writer.print_base64('foobar'.bytes()) or { status = err.msg() }
	assert status == 'WriteFailed' && writer.buffered().bytestr() == 'Zm9'
	writer.seek_to(0)!
	status = 'ok'
	writer.print_hex([u8(171), 205], .upper) or { status = err.msg() }
	assert status == 'WriteFailed' && writer.buffered().bytestr() == 'ABC'
	writer.seek_to(0)!
	status = 'ok'
	writer.print_unicode_codepoint(0x10000) or { status = err.msg() }
	assert status == 'WriteFailed' && writer.buffered().hex() == 'f09080'
}
