module zigimg

fn test_decimal_record_scientific_precision_and_rounding() {
	mut bytes := []u8{len: 64, init: 165}
	value := FloatDecimal64{
		mantissa: 123456
		exponent: -3
		sign:     false
	}
	assert format_float_scientific(mut bytes, value, none)!.bytestr() == '1.23456e2'
	assert format_float_scientific(mut bytes, value, usize(2))!.bytestr() == '1.23e2'
	assert format_float_scientific(mut bytes, FloatDecimal64{ mantissa: 125, exponent: 0, sign: true },
		usize(1))!.bytestr() == '-1.3e2'
	assert format_float_scientific(mut bytes, FloatDecimal64{
		mantissa: 999
		exponent: 0
		sign:     false
	}, usize(0))!.bytestr() == '1e3'
}

fn test_decimal_record_fixed_precision_specials_and_borrowing() {
	mut bytes := []u8{len: 64, init: 165}
	value := FloatDecimal64{
		mantissa: 123456
		exponent: -3
		sign:     false
	}
	assert format_float_decimal(mut bytes, value, usize(2))!.bytestr() == '123.46'
	mut view := format_float_decimal(mut bytes, FloatDecimal64{
		mantissa: 12
		exponent: -4
		sign:     true
	}, usize(6))!
	assert view.bytestr() == '-0.001200'
	bytes[1] = `9`
	assert view[1] == `9`
	view[0] = `+`
	assert bytes[0] == `+`
	assert format_float_decimal(mut bytes, FloatDecimal64{
		mantissa: 0
		exponent: 2147483647
		sign:     true
	}, ~usize(0))!.bytestr() == '-inf'
	assert format_float_scientific(mut bytes, FloatDecimal64{
		mantissa: ~u64(0)
		exponent: 2147483647
		sign:     false
	}, ~usize(0))!.bytestr() == 'nan'
}

fn test_decimal_record_buffer_failure_is_unchanged_and_scratch_is_retained() {
	mut bytes := []u8{len: 53, init: 165}
	value := FloatDecimal64{
		mantissa: 1234
		exponent: 0
		sign:     false
	}
	mut status := 'ok'
	format_float_scientific(mut bytes, value, usize(46)) or { status = err.msg() }
	assert status == 'BufferTooSmall' && bytes == []u8{len: 53, init: 165}
	assert format_float_scientific(mut bytes, value, usize(0))!.bytestr() == '1e3'
	assert format_float_decimal(mut bytes, FloatDecimal64{ mantissa: 1, exponent: -2, sign: false },
		usize(0))!.bytestr() == '0'
	assert bytes[1] == `.` && bytes[2] == `0` && bytes[3] == `1`
	assert format_float_decimal(mut bytes, FloatDecimal64{ mantissa: 9, exponent: -1, sign: false },
		usize(0))!.bytestr() == '1'
}
