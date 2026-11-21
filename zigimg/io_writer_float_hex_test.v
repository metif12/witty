module zigimg

fn test_hex_float_special_values_and_exact_digits() {
	mut bytes := []u8{len: 256}
	mut writer := WriteStream.init_memory(mut bytes)
	writer.print_float_hex[f64](0.0, .lower, none)!
	writer.write_byte(`|`)!
	minus_zero := u64(1) << 63
	writer.print_float_hex[f64](unsafe { *(&f64(&minus_zero)) }, .upper, uint(0))!
	writer.write_byte(`|`)!
	writer.print_float_hex[f32](f32(1.5), .upper, none)!
	writer.write_byte(`|`)!
	minimum := u64(1)
	writer.print_float_hex[f64](unsafe { *(&f64(&minimum)) }, .lower, none)!
	writer.write_byte(`|`)!
	negative_nan := u32(0xff800001)
	writer.print_float_hex[f32](unsafe { *(&f32(&negative_nan)) }, .upper, ~uint(0))!
	writer.write_byte(`|`)!
	infinity := u64(0x7ff0000000000000)
	writer.print_float_hex[f64](unsafe { *(&f64(&infinity)) }, .lower, uint(12))!
	assert writer.buffered() == '0x0.0p0|-0x0p0|0x1.8p0|0x0.0000000000001p-1022|-NAN|inf'.bytes()
}

fn test_hex_float_rounding_ties_and_alignment() {
	mut bytes := []u8{len: 256}
	mut writer := WriteStream.init_memory(mut bytes)
	for n in [f64(1.03125), 1.09375, 1.96875] {
		writer.print_float_hex[f64](n, .lower, uint(1))!
		writer.write_byte(`|`)!
	}
	options := FormatOptions{
		width:     uint(14)
		alignment: .center
		fill:      `_`
		precision: uint(3)
	}.to_number(.hex, .upper)
	writer.print_float_hex_options[f32](f32(-1.625), options)!
	assert writer.buffered() == '0x1.0p0|0x1.2p0|0x1.0p1|__-0x1.A00p0__'.bytes()
}

fn test_hex_float_direct_failure_retains_prefix_and_options_render_first() {
	mut bytes := []u8{len: 5, init: 165}
	mut writer := WriteStream.init_memory(mut bytes)
	mut status := 'ok'
	writer.print_float_hex[f64](-1.5, .lower, none) or { status = err.msg() }
	assert status == 'WriteFailed' && writer.buffered() == '-0x1.'.bytes()
	mut other := []u8{len: 5, init: 165}
	mut aligned := WriteStream.init_memory(mut other)
	status = 'ok'
	aligned.print_float_hex_options[f64](1.5, NumberFormat{ mode: .hex, width: uint(10), fill: `_` }) or {
		status = err.msg()
	}
	assert status == 'WriteFailed' && aligned.buffered() == '___0x'.bytes()
}
