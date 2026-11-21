module zigimg

type ValueInteger = i16
type ValueBytes = []u8
type ValueBool = bool

fn test_value_dispatch_preserves_signed_padding_and_aliases() {
	mut bytes := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut bytes)
	writer.print_value('X', FormatOptions{ width: uint(6), fill: `0` }, ValueInteger(42), 0)!
	writer.write_byte(`|`)!
	writer.print_value('any', FormatOptions{}, ValueBool(true), 0)!
	writer.write_byte(`|`)!
	writer.print_value('x', FormatOptions{}, ValueBytes([u8(0), 255]), 0)!
	assert writer.buffered().bytestr() == '000+2A|true|00ff'
}

fn test_value_byte_lists_preserve_depth_and_element_padding() {
	mut bytes := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut bytes)
	writer.print_value('any', FormatOptions{ width: uint(3), fill: `_` }, [u8(1), 255], 1)!
	writer.write_byte(`|`)!
	writer.print_value('any', FormatOptions{ width: uint(99) }, []u8{}, 0)!
	assert writer.buffered().bytestr() == '{ __1, 255 }|{ ... }'
}

fn test_value_list_failure_retains_opening_and_partial_element() {
	mut bytes := []u8{len: 4}
	mut writer := WriteStream.init_memory(mut bytes)
	mut status := 'ok'
	writer.print_value('any', FormatOptions{}, [u8(255)], 1) or { status = err.msg() }
	assert status == 'WriteFailed'
	assert writer.buffered().bytestr() == '{ 25'
}
