module zigimg

fn test_integer_writer_signs_padding_and_ignored_precision() {
	mut bytes := []u8{len: 64}
	mut writer := WriteStream.init_memory(mut bytes)
	writer.print_int_any[i64](-12, 10, .lower, FormatOptions{ width: usize(5), fill: `0` })!
	writer.print_int[int](12, 10, .lower, FormatOptions{
		width:     usize(5)
		fill:      `0`
		precision: usize(0)
	})!
	writer.print_int[u32](12, 10, .lower, FormatOptions{ width: usize(5), fill: `0` })!
	writer.print_int[int](0, 10, .lower, FormatOptions{ width: usize(1) })!
	writer.print_int[int](12, 10, .lower, FormatOptions{})!
	assert writer.buffered().bytestr() == '00-1200+1200012+012'
}

fn test_integer_writer_native_extrema_and_letter_case() {
	mut bytes := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut bytes)
	writer.print_int_any[i64](-9223372036854775807 - 1, 10, .lower, FormatOptions{})!
	writer.print_int[u64](18446744073709551615, 16, .upper, FormatOptions{})!
	writer.print_int_any[u8](255, 16, .lower, FormatOptions{})!
	writer.print_int_any[i8](-128, 2, .lower, FormatOptions{})!
	writer.print_int_any[u8](255, 255, .lower, FormatOptions{})!
	assert writer.buffered().bytestr() == '-9223372036854775808FFFFFFFFFFFFFFFFff-1000000010'
}

fn test_integer_writer_failure_preserves_alignment_order() {
	mut bytes := []u8{len: 4, init: 165}
	mut writer := WriteStream.init_memory(mut bytes)
	mut status := 'ok'
	writer.print_int_any[int](-12, 10, .lower, FormatOptions{
		width:     usize(6)
		alignment: .center
		fill:      `.`
	}) or { status = err.msg() }
	assert status == 'WriteFailed' && writer.buffered().bytestr() == '.-12'
	writer.seek_to(0)!
	status = 'ok'
	writer.print_int[u64](65535, 16, .upper, FormatOptions{
		width:     usize(6)
		alignment: .left
		fill:      `_`
	}) or { status = err.msg() }
	assert status == 'WriteFailed' && writer.buffered().bytestr() == 'FFFF'
}
