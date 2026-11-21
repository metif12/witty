module zigimg

fn test_binary_float_decimal_records_and_signed_specials() {
	assert float_to_decimal[f64](1.5) == FloatDecimal64{
		mantissa: 15
		exponent: -1
		sign:     false
	}
	assert float_to_decimal[f32](f32(0.1)) == FloatDecimal64{
		mantissa: 1
		exponent: -1
		sign:     false
	}
	minimum := u64(1)
	assert float_to_decimal[f64](unsafe { *(&f64(&minimum)) }) == FloatDecimal64{
		mantissa: 5
		exponent: -324
		sign:     false
	}
	negative_zero := u64(1) << 63
	assert float_to_decimal[f64](unsafe { *(&f64(&negative_zero)) }) == FloatDecimal64{
		mantissa: 0
		exponent: 0
		sign:     true
	}
	negative_nan := u32(0xff800001)
	assert float_to_decimal[f32](unsafe { *(&f32(&negative_nan)) }) == FloatDecimal64{
		mantissa: 1
		exponent: 2147483647
		sign:     true
	}
}

fn test_binary_float_rendering_defaults_precision_and_borrowing() {
	mut bytes := []u8{len: 347, init: 165}
	assert float_format_buffer_size[f32](.decimal) == 55
	assert float_format_buffer_size[f64](.decimal) == 347
	assert float_format_buffer_size[f64](.scientific) == 53
	mut view := render_float[f32](mut bytes, f32(0.1), FloatRenderOptions{})!
	assert view.bytestr() == '1e-1'
	bytes[0] = `9`
	assert view.bytestr() == '9e-1'
	assert render_float[f64](mut bytes, 123.125, FloatRenderOptions{
		mode:      .decimal
		precision: uint(2)
	})!.bytestr() == '123.13'
	assert render_float[f64](mut bytes, -0.0, FloatRenderOptions{
		mode:      .decimal
		precision: uint(2)
	})!.bytestr() == '-0.00'
}

fn test_float_writer_ignores_case_and_preserves_fallback_and_partial_output() {
	mut bytes := []u8{len: 64}
	mut writer := WriteStream.init_memory(mut bytes)
	writer.print_float[f32](f32(1.5), NumberFormat{ mode: .scientific, letter_case: .upper })!
	writer.write_byte(`|`)!
	writer.print_float[f64](1.5, NumberFormat{ precision: uint(346), width: uint(9), fill: `_` })!
	assert writer.buffered() == '1.5e0|__(float)'.bytes()
	mut short := []u8{len: 4}
	mut failing := WriteStream.init_memory(mut short)
	mut status := 'ok'
	failing.print_float[f64](1.5, NumberFormat{ width: uint(8), fill: `_` }) or {
		status = err.msg()
	}
	assert status == 'WriteFailed' && failing.buffered() == '____'.bytes()
}
