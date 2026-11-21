module zigimg

fn test_duration_writer_units_fraction_truncation_and_zero() {
	values := [u64(0), 1, 999, 1000, 1001, 1100, 1010, 1999, 1000000, 1000001, 1234567, 1000000000,
		1000000001, 1234567890, 60000000000, 604800000000000, 31536000000000000]
	wanted := ['0ns', '1ns', '999ns', '1us', '1.001us', '1.1us', '1.01us', '1.999us', '1ms', '1ms',
		'1.234ms', '1s', '1s', '1.234s', '1m', '1w', '1y']
	for i, value in values {
		mut bytes := []u8{len: 24}
		mut writer := WriteStream.init_memory(mut bytes)
		writer.print_duration_unsigned(value)!
		assert writer.buffered().bytestr() == wanted[i]
	}
}

fn test_duration_writer_extrema_and_combined_units() {
	mut bytes := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut bytes)
	writer.print_duration_signed(-9223372036854775807 - 1)!
	writer.print_duration_unsigned(18446744073709551615)!
	writer.print_duration_unsigned(31536000000000000 + 604800000000000 + 86400000000000 +
		3600000000000 + 60000000000 + 1234567890)!
	assert writer.buffered().bytestr() == '-292y24w3d23h47m16.854s584y49w23h34m33.709s1y1w1d1h1m1.234s'
}

fn test_duration_writer_options_and_partial_failures() {
	mut bytes := []u8{len: 16}
	mut writer := WriteStream.init_memory(mut bytes)
	writer.print_duration[i64](-1000, FormatOptions{
		width:     uint(8)
		alignment: .center
		fill:      `.`
		precision: uint(0)
	})!
	assert writer.buffered().bytestr() == '..-1us..'
	mut short := []u8{len: 3, init: 165}
	mut direct := WriteStream.init_memory(mut short)
	mut status := 'ok'
	direct.print_duration_signed(-1234567) or { status = err.msg() }
	assert status == 'WriteFailed' && direct.buffered().bytestr() == '-1.'
	direct.seek_to(0)!
	status = 'ok'
	direct.print_duration[int](-1234567, FormatOptions{ width: uint(10), fill: `_` }) or {
		status = err.msg()
	}
	assert status == 'WriteFailed' && direct.buffered().bytestr() == '__-'
}

fn test_duration_writer_long_direct_output_and_temporary_buffer_boundary() {
	prefix := u64(101) * 31536000000000000 + u64(11) * 604800000000000 + 86400000000000 +
		11 * u64(3600000000000) + 11 * u64(60000000000)
	mut bytes := []u8{len: 32}
	mut writer := WriteStream.init_memory(mut bytes)
	writer.print_duration_signed(-i64(prefix + 123456789))!
	assert writer.buffered().bytestr() == '-101y11w1d11h11m123.456ms'
	mut bounded := []u8{len: 24}
	mut generic := WriteStream.init_memory(mut bounded)
	generic.print_duration[i64](-i64(prefix + 123450000), FormatOptions{})!
	assert generic.buffered().bytestr() == '-101y11w1d11h11m123.45ms'
}
