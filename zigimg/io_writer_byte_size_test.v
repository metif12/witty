module zigimg

fn test_byte_size_uses_pinned_integer_logarithm_thresholds() {
	mut bytes := []u8{len: 256}
	mut writer := WriteStream.init_memory(mut bytes)
	for value in [u64(0), 42, 511, 512, 1000, 262144, ~u64(0)] {
		writer.print_byte_size(value, .decimal, FormatOptions{})!
		writer.write_byte(`|`)!
	}
	assert writer.buffered().bytestr() == '0B|42B|511B|0.512kB|1kB|0.262144MB|0.01844674407370955ZB|'
}

fn test_byte_size_preserves_binary_scaling_precision_and_alignment() {
	mut bytes := []u8{len: 256}
	mut writer := WriteStream.init_memory(mut bytes)
	writer.print_byte_size(63 * 1000 * 1000, .binary, FormatOptions{ precision: usize(2) })!
	writer.write_byte(`|`)!
	writer.print_byte_size(63 * 1024 * 1024, .decimal, FormatOptions{
		precision: usize(2)
		width:     usize(9)
		alignment: .center
		fill:      `=`
	})!
	writer.write_byte(`|`)!
	writer.print_byte_size(42, .binary, FormatOptions{ precision: ~usize(0) })!
	writer.write_byte(`|`)!
	writer.print_byte_size(~u64(0), .binary, FormatOptions{})!
	assert writer.buffered().bytestr() == '60.08MiB|=66.06MB=|42B|16EiB'
}

fn test_byte_size_retains_partial_parent_alignment_failure() {
	mut bytes := []u8{len: 4, init: 165}
	mut writer := WriteStream.init_memory(mut bytes)
	mut status := 'ok'
	writer.print_byte_size(1024, .binary, FormatOptions{ width: usize(8), fill: `_` }) or {
		status = err.msg()
	}
	assert status == 'WriteFailed'
	assert writer.buffered().bytestr() == '____'
}
