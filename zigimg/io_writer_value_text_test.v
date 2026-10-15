module zigimg

type ValueCharacter = u8
type ValueCodepoint = u32

fn test_value_text_character_retains_bytes_and_alignment() {
	mut bytes := []u8{len: 16}
	mut writer := WriteStream.init_memory(mut bytes)
	writer.print_value('c', FormatOptions{
		width:     usize(4)
		alignment: .center
		fill:      `_`
		precision: ~usize(0)
	}, ValueCharacter(255), 0)!
	assert writer.buffered() == [u8(`_`), 255, `_`, `_`]
}

fn test_value_text_unicode_replaces_surrogates_and_ignores_options() {
	mut bytes := []u8{len: 16}
	mut writer := WriteStream.init_memory(mut bytes)
	options := FormatOptions{
		width:     ~usize(0)
		precision: ~usize(0)
		fill:      `_`
	}
	writer.print_value('u', options, ValueCodepoint(0x1f642), 0)!
	writer.print_value('u', options, u16(0xd800), ~usize(0))!
	writer.print_value('u', options, u32(0x1fffff), 1)!
	assert writer.buffered().hex() == 'f09f9982efbfbdefbfbd'
}

fn test_value_text_unsupported_character_carrier_precedes_output() {
	mut bytes := []u8{len: 16}
	mut writer := WriteStream.init_memory(mut bytes)
	writer.write_all('prefix'.bytes())!
	writer.print_value('c', FormatOptions{}, u16(65), 0) or {
		assert err.msg() == 'unsupported print_value character carrier'
		assert writer.buffered().bytestr() == 'prefix'
		return
	}
	assert false
}
