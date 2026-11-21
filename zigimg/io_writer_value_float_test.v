module zigimg

type ValueFloat32 = f32
type ValueFloat64 = f64

fn test_value_float_dispatch_preserves_native_width_and_hex_case() {
	mut bytes := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut bytes)
	writer.print_value('d', FormatOptions{}, ValueFloat32(1.5), 0)!
	writer.write_byte(`|`)!
	writer.print_value('E', FormatOptions{}, ValueFloat64(1.5), ~uint(0))!
	writer.write_byte(`|`)!
	writer.print_value('X', FormatOptions{}, ValueFloat32(1.5), 0)!
	assert writer.buffered().bytestr() == '1.5|1.5e0|0x1.8p0'
}

fn test_value_float_dispatch_preserves_fallback_before_padding() {
	mut bytes := []u8{len: 32}
	mut writer := WriteStream.init_memory(mut bytes)
	writer.print_value('d', FormatOptions{ precision: uint(346), width: uint(9), fill: `_` },
		f64(1.5), 1)!
	assert writer.buffered().bytestr() == '__(float)'
}

fn test_value_float_dispatch_rejects_unsupported_format_before_output() {
	mut bytes := []u8{len: 16}
	mut writer := WriteStream.init_memory(mut bytes)
	writer.write_all('prefix'.bytes())!
	writer.print_value('b', FormatOptions{}, f32(1.5), 0) or {
		assert err.msg() == 'unsupported print_value float format'
		assert writer.buffered().bytestr() == 'prefix'
		return
	}
	assert false
}
