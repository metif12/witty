module zigimg

struct ValueNamedError {
	name string
}

fn (e ValueNamedError) msg() string {
	return e.name
}

fn (e ValueNamedError) code() int {
	panic('error formatting must not read the code')
}

struct ValueErrorRecord {
	problem IError
}

fn test_value_error_names_and_alignment() ! {
	mut buffer := []u8{len: 256}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print_value('', FormatOptions{}, error_with_code('Alpha', 17), 0)!
	writer.write_byte(`|`)!
	writer.print_value('any', FormatOptions{}, ValueNamedError{'Bad Name'}, ~uint(0))!
	writer.write_byte(`|`)!
	writer.print_value('t', FormatOptions{
		width:     uint(10)
		precision: uint(0)
		fill:      `_`
		alignment: .center
	}, ValueNamedError{'échec'}, 0)!
	writer.write_byte(`|`)!
	writer.print_value('any', FormatOptions{}, error(''), 0)!
	assert writer.buffered().bytestr() == 'error.Alpha|error.Bad Name|__échec__|error.'
}

fn test_value_error_arrays_and_record_fields() ! {
	mut buffer := []u8{len: 512}
	mut writer := WriteStream.init_memory(mut buffer)
	values := [IError(error('Alpha')), IError(error('Beta'))]
	writer.print_value('any', FormatOptions{}, values, 1)!
	writer.write_byte(`|`)!
	fixed := [ValueNamedError{'Alpha'}, ValueNamedError{'Beta'}]!
	writer.print_value('any', FormatOptions{}, fixed, 1)!
	writer.write_byte(`|`)!
	writer.print_value('any', FormatOptions{}, [values, []IError{}], 1)!
	writer.write_byte(`|`)!
	writer.print_value('any', FormatOptions{}, ValueErrorRecord{values[0]}, 1)!
	assert writer.buffered().bytestr() == '{ error.Alpha, error.Beta }|{ error.Alpha, error.Beta }|{ { ... }, { ... } }|.{ .problem = error.Alpha }'
}

fn test_value_error_every_capacity_and_invalid_formats() ! {
	expected := 'error.LongerFailureName'.bytes()
	for cap in 0 .. expected.len + 2 {
		mut buffer := []u8{len: cap, init: 0xa5}
		mut writer := WriteStream.init_memory(mut buffer)
		mut status := 'ok'
		writer.print_value('any', FormatOptions{}, error('LongerFailureName'), 0) or {
			status = err.msg()
		}
		assert status == if cap < expected.len {
			'WriteFailed'
		} else {
			'ok'
		}
		assert writer.buffered() == expected[..if cap < expected.len {
			cap
		} else {
			expected.len
		}]
	}
	for format in ['d', 's', 'x', 'b64', '*', '?', 'bogus'] {
		mut buffer := []u8{len: 16, init: 0xa5}
		mut writer := WriteStream.init_memory(mut buffer)
		mut status := 'ok'
		writer.print_value(format, FormatOptions{ width: uint(0), precision: uint(0) }, ValueNamedError{'Alpha'},
			0) or { status = err.msg() }
		assert status == 'unsupported print_value error format'
		assert writer.buffered().len == 0
		assert buffer == []u8{len: 16, init: 0xa5}
	}
}
