module zigimg

// V strings carry byte slices here; bytes() would allocate and change addresses.
fn io_value_string(mut stream WriteStream, format string, options FormatOptions, value string, max_depth uint) ! {
	if format == '*' {
		stream.write_all('u8@'.bytes())!
		return io_address_integer(mut stream, uint(value.str))
	}
	bytes := unsafe { value.str.vbytes(value.len) }
	return io_value_bytes(mut stream, format, options, bytes, max_depth)
}
