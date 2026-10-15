module zigimg

pub const float_format_min_buffer_size = 53

// The represented u64 specialization of std.fmt.float.FloatDecimal.
pub struct FloatDecimal64 {
pub mut:
	mantissa u64  @[required]
	exponent int  @[required]
	sign     bool @[required]
}

fn float_format_add(a usize, b usize) usize {
	if b > ~usize(0) - a { panic('integer overflow') }
	return a + b
}

fn float_format_iadd(a int, b int) int {
	sum := i64(a) + i64(b)
	if sum < -2147483648 || sum > 2147483647 { panic('integer overflow') }
	return int(sum)
}

fn float_format_neg(a int) int {
	if a == -2147483648 { panic('integer overflow') }
	return -a
}

fn float_format_length(n u64) usize {
	if n >= 100000000000000000 { panic('reached unreachable code') }
	mut value := n
	mut length := usize(1)
	for value >= 10 {
		value /= 10
		length++
	}
	return length
}

fn float_format_tail(mut buffer []u8, start usize) []u8 {
	if start > usize(buffer.len) {
		panic('index out of bounds: index ${u64(start).str()}, len ${buffer.len}')
	}
	return unsafe { buffer[int(start)..] }
}

fn float_format_prefix(mut buffer []u8, count usize) []u8 {
	if count > usize(buffer.len) {
		panic('index out of bounds: index ${u64(count).str()}, len ${buffer.len}')
	}
	return unsafe { buffer[..int(count)] }
}

fn float_format_put(mut buffer []u8, index usize, byte u8) {
	if index >= usize(buffer.len) {
		panic('index out of bounds: index ${u64(index).str()}, len ${buffer.len}')
	}
	buffer[int(index)] = byte
}

fn float_format_zeros(mut buffer []u8, index usize, count usize) {
	mut tail := float_format_tail(mut buffer, index)
	mut span := float_format_prefix(mut tail, count)
	for i in 0 .. span.len {
		span[i] = `0`
	}
}

// Keep Source's right-to-left pairs and writes beyond the eventual returned view.
fn float_format_digits(mut buffer []u8, value &u64, count usize) {
	mut remaining := unsafe { *value }
	mut i := usize(0)
	for i + 2 < count {
		c := remaining % 100
		remaining /= 100
		float_format_put(mut buffer, count - i - 1, u8(`0` + c % 10))
		float_format_put(mut buffer, count - i - 2, u8(`0` + c / 10))
		i += 2
	}
	for i < count {
		c := remaining % 10
		remaining /= 10
		float_format_put(mut buffer, count - i - 1, u8(`0` + c))
		i++
	}
	unsafe {
		*value = remaining
	}
}

fn float_format_round(value FloatDecimal64, scientific bool, precision usize) FloatDecimal64 {
	mut output := value.mantissa
	mut exponent := value.exponent
	length := float_format_length(output)
	mut round_digit := usize(0)
	if scientific {
		round_digit = float_format_add(1, precision)
	} else if exponent > 0 {
		round_digit = float_format_add(float_format_add(length - 1, precision), usize(exponent))
	} else {
		minimum := usize(float_format_neg(exponent))
		count := float_format_add(precision, length)
		if count > minimum { round_digit = count - minimum }
	}
	if round_digit < length {
		for _ in int(round_digit + 1) .. int(length) {
			output /= 10
			exponent = float_format_iadd(exponent, 1)
		}
		if output % 10 >= 5 {
			output = output / 10 + 1
			exponent = float_format_iadd(exponent, 1)
			mut power := output
			mut power_of_ten := true
			for power != 0 {
				if power % 10 != 0 {
					power_of_ten = false
					break
				}
				power /= 10
			}
			if power_of_ten {
				output /= 10
				exponent = float_format_iadd(exponent, 1)
			}
		}
	}
	return FloatDecimal64{
		mantissa: output
		exponent: exponent
		sign:     value.sign
	}
}

fn float_format_special(mut buffer []u8, value FloatDecimal64) []u8 {
	if value.sign { buffer[0] = `-` }
	offset := if value.sign { 1 } else { 0 }
	word := if value.mantissa != 0 { 'nan' } else { 'inf' }
	for i in 0 .. 3 {
		buffer[offset + i] = word[i]
	}
	return float_format_prefix(mut buffer, usize(3 + offset))
}

pub fn format_float_scientific(mut buffer []u8, value FloatDecimal64, precision ?usize) ![]u8 {
	if buffer.len < float_format_min_buffer_size { panic('reached unreachable code') }
	if value.exponent == 2147483647 { return float_format_special(mut buffer, value) }
	f := if digits := precision { float_format_round(value, true, digits) } else { value }
	mut output := f.mantissa
	length := float_format_length(output)
	if digits := precision {
		if usize(buffer.len) < float_format_add(8, digits) { return error('BufferTooSmall') }
	}
	mut index := usize(0)
	if f.sign {
		float_format_put(mut buffer, 0, `-`)
		index = 1
	}
	mut tail := float_format_tail(mut buffer, index + 2)
	float_format_digits(mut tail, &output, length - 1)
	float_format_put(mut buffer, index, u8(`0` + output % 10))
	float_format_put(mut buffer, index + 1, `.`)
	index += 2
	dp_index := index
	index = if length > 1 { index + length - 1 } else { index - 1 }
	if digits := precision {
		if length == 1 { index++ }
		if digits > length - 1 {
			count := digits - (length - 1)
			float_format_zeros(mut buffer, index, count)
			index += count
		} else {
			index = dp_index + digits - if digits == 0 { usize(1) } else { usize(0) }
		}
	}
	float_format_put(mut buffer, index, `e`)
	index++
	mut exponent := float_format_iadd(float_format_iadd(f.exponent, int(length)), -1)
	if exponent < 0 {
		float_format_put(mut buffer, index, `-`)
		index++
		exponent = float_format_neg(exponent)
	}
	mut unsigned := u64(exponent)
	exponent_length := float_format_length(unsigned)
	tail = float_format_tail(mut buffer, index)
	float_format_digits(mut tail, &unsigned, exponent_length)
	index += exponent_length
	return float_format_prefix(mut buffer, index)
}

pub fn format_float_decimal(mut buffer []u8, value FloatDecimal64, precision ?usize) ![]u8 {
	if buffer.len < float_format_min_buffer_size { panic('reached unreachable code') }
	if value.exponent == 2147483647 { return float_format_special(mut buffer, value) }
	f := if digits := precision { float_format_round(value, false, digits) } else { value }
	mut output := f.mantissa
	length := float_format_length(output)
	digits := precision or { usize(0) }
	absolute := usize(if f.exponent < 0 { -i64(f.exponent) } else { i64(f.exponent) })
	required := if f.exponent >= 0 {
		float_format_add(float_format_add(float_format_add(2, absolute), length), digits)
	} else {
		count := float_format_add(absolute, length)
		float_format_add(2, if count > digits { count } else { digits })
	}
	if usize(buffer.len) < required { return error('BufferTooSmall') }
	mut index := usize(0)
	if f.sign {
		float_format_put(mut buffer, index, `-`)
		index++
	}
	dp_offset := float_format_iadd(f.exponent, int(length))
	if dp_offset <= 0 {
		float_format_put(mut buffer, index, `0`)
		float_format_put(mut buffer, index + 1, `.`)
		index += 2
		dp_index := index
		count := usize(float_format_neg(dp_offset))
		float_format_zeros(mut buffer, index, count)
		index += count
		mut tail := float_format_tail(mut buffer, index)
		float_format_digits(mut tail, &output, length)
		index += length
		if prec := precision {
			written := index - dp_index
			if prec > written { float_format_zeros(mut buffer, index, prec - written) }
			index = dp_index + prec - if prec == 0 { usize(1) } else { usize(0) }
		}
	} else {
		offset := usize(dp_offset)
		if offset >= length {
			mut tail := float_format_tail(mut buffer, index)
			float_format_digits(mut tail, &output, length)
			index += length
			float_format_zeros(mut buffer, index, offset - length)
			index += offset - length
			if prec := precision {
				if prec != 0 {
					float_format_put(mut buffer, index, `.`)
					index++
					float_format_zeros(mut buffer, index, prec)
					index += prec
				}
			}
		} else {
			mut tail := float_format_tail(mut buffer, index + offset + 1)
			float_format_digits(mut tail, &output, length - offset)
			float_format_put(mut buffer, index + offset, `.`)
			dp_index := index + offset + 1
			tail = float_format_tail(mut buffer, index)
			float_format_digits(mut tail, &output, offset)
			index += length + 1
			if prec := precision {
				written := length - offset
				if prec > written { float_format_zeros(mut buffer, index, prec - written) }
				index = dp_index + prec - if prec == 0 { usize(1) } else { usize(0) }
			}
		}
	}
	return float_format_prefix(mut buffer, index)
}
