module zigimg

// Type parameters represent Zig's comptime Endian argument.
pub struct BigEndian {}

pub struct LittleEndian {}

pub struct BitReader[E] {
pub mut:
	reader &ReadStream @[required]
	bits   u8
	count  u8
}

pub fn (mut stream BitReader[E]) read_bits_no_eof[E, T](num u16) !T {
	value, count := stream.read_bits_tuple[E, T](num)!
	if count < num { return error('EndOfStream') }
	return value
}

pub fn (mut stream BitReader[E]) read_bits[E, T](num u16, out_bits &u16) !T {
	value, count := stream.read_bits_tuple[E, T](num)!
	unsafe {
		*out_bits = count
	}
	return value
}

pub fn (mut stream BitReader[E]) read_bits_tuple[E, T](num u16) !(T, u16) {
	if num <= stream.count { return bit_value_from_bits[T](stream.remove_bits(u8(num))), num }
	mut out_count := u16(stream.count)
	mut out := u64(stream.remove_bits(stream.count))
	full_bytes_left := (num - out_count) / 8
	for _ in 0 .. full_bytes_left {
		byte := stream.reader.take_byte() or {
			if err.msg() == 'EndOfStream' { return bit_value_from_bits[T](out), out_count }
			return err
		}
		$if E.unaliased_typ is BigEndian {
			if sizeof(T) == 1 {
				out = 0
			} else {
				out <<= 8
			}
			out |= byte
		} $else $if E.unaliased_typ is LittleEndian {
			if out_count >= sizeof(T) * 8 { panic('integer does not fit in destination type') }
			out |= u64(byte) << out_count
		} $else {
			$compile_error('BitReader requires BigEndian or LittleEndian')
		}
		out_count += 8
	}
	bits_left := num - out_count
	keep := u8(8 - bits_left)
	if bits_left == 0 { return bit_value_from_bits[T](out), out_count }
	final_byte := stream.reader.take_byte() or {
		if err.msg() == 'EndOfStream' { return bit_value_from_bits[T](out), out_count }
		return err
	}
	$if E.unaliased_typ is BigEndian {
		if bits_left >= sizeof(T) * 8 { panic('integer does not fit in destination type') }
		out <<= bits_left
		out |= final_byte >> keep
		stream.bits = final_byte & bit_mask(keep)
	} $else $if E.unaliased_typ is LittleEndian {
		if out_count >= sizeof(T) * 8 { panic('integer does not fit in destination type') }
		out |= u64(final_byte & bit_mask(u8(bits_left))) << out_count
		stream.bits = final_byte >> bits_left
	}
	stream.count = keep
	return bit_value_from_bits[T](out), num
}

fn (mut stream BitReader[E]) remove_bits[E](num u8) u8 {
	if num > stream.count { panic('integer overflow') }
	if num == 8 {
		stream.count = 0
		return stream.bits
	}
	keep := stream.count - num
	mut bits := u8(0)
	$if E.unaliased_typ is BigEndian {
		if keep >= 8 { panic('integer does not fit in destination type') }
		bits = stream.bits >> keep
		stream.bits &= bit_mask(keep)
	} $else $if E.unaliased_typ is LittleEndian {
		bits = stream.bits & bit_mask(num)
		if num >= 8 { panic('integer does not fit in destination type') }
		stream.bits >>= num
	}
	stream.count = keep
	return bits
}

pub fn (mut stream BitReader[E]) align_to_byte[E]() {
	stream.bits = 0
	stream.count = 0
}

pub struct BitWriter[E] {
pub mut:
	writer &WriteStream @[required]
	bits   u8
	count  u8
}

pub fn (mut stream BitWriter[E]) write_bits[E, T](value T, num u16) ! {
	mut input := bit_value_to_bits[T](value)
	if sizeof(T) < 8 { input &= (u64(1) << (sizeof(T) * 8)) - 1 }
	mut in_count := num
	if stream.count > 0 {
		if stream.count > 8 { panic('integer overflow') }
		bits_free := u8(8 - stream.count)
		if num < bits_free {
			stream.add_bits(u8(input), u8(num))
			return
		}
		if num == bits_free {
			stream.add_bits(u8(input), u8(num))
			return stream.flush_bits()
		}
		$if E.unaliased_typ is BigEndian {
			if in_count - bits_free >= sizeof(T) * 8 {
				panic('integer does not fit in destination type')
			}
			stream.add_bits(u8(input >> (in_count - bits_free)), bits_free)
		} $else $if E.unaliased_typ is LittleEndian {
			stream.add_bits(u8(input), bits_free)
			if bits_free >= sizeof(T) * 8 { panic('integer does not fit in destination type') }
			input >>= bits_free
		} $else {
			$compile_error('BitWriter requires BigEndian or LittleEndian')
		}
		in_count -= bits_free
		stream.flush_bits()!
	}
	full_bytes_left := in_count / 8
	for _ in 0 .. full_bytes_left {
		$if E.unaliased_typ is BigEndian {
			if in_count - 8 >= sizeof(T) * 8 { panic('integer does not fit in destination type') }
			stream.writer.write_byte(u8(input >> (in_count - 8)))!
		} $else $if E.unaliased_typ is LittleEndian {
			stream.writer.write_byte(u8(input))!
			if sizeof(T) == 1 {
				input = 0
			} else {
				input >>= 8
			}
		}
		in_count -= 8
	}
	stream.add_bits(u8(input), u8(in_count))
}

fn (mut stream BitWriter[E]) add_bits[E](bits u8, num u8) {
	if num == 8 {
		stream.bits = bits
	} else {
		$if E.unaliased_typ is BigEndian {
			if num >= 8 { panic('integer does not fit in destination type') }
			stream.bits <<= num
			stream.bits |= bits & bit_mask(num)
		} $else $if E.unaliased_typ is LittleEndian {
			// The source deliberately does not mask the provided value here.
			if stream.count >= 8 { panic('integer does not fit in destination type') }
			stream.bits |= u8(bits << stream.count)
		}
	}
	if u16(stream.count) + num >= 16 { panic('integer overflow') }
	stream.count += num
}

pub fn (mut stream BitWriter[E]) flush_bits[E]() ! {
	if stream.count == 0 { return }
	$if E.unaliased_typ is BigEndian {
		if stream.count > 8 { panic('integer overflow') }
		stream.bits <<= 8 - stream.count
	}
	stream.writer.write_byte(stream.bits)!
	stream.bits = 0
	stream.count = 0
}

fn bit_mask(count u8) u8 {
	if count > 8 { panic('index out of bounds: index ${count}, len 9') }
	return u8((u16(1) << count) - 1)
}

// Zig's bit APIs reinterpret the result/input, including floating point types.
fn bit_value_from_bits[T](value u64) T {
	$if T.unaliased_typ is f32 {
		word := u32(value)
		return T(unsafe { *(&f32(&word)) })
	} $else $if T.unaliased_typ is f64 {
		return T(unsafe { *(&f64(&value)) })
	} $else $if T.unaliased_typ is $int {
		return T(value)
	} $else {
		$compile_error('Bit streams currently support native integer and float scalars')
	}
}

fn bit_value_to_bits[T](value T) u64 {
	$if T.unaliased_typ is f32 {
		return unsafe { *(&u32(&value)) }
	} $else $if T.unaliased_typ is f64 {
		return unsafe { *(&u64(&value)) }
	} $else $if T.unaliased_typ is $int {
		return u64(value)
	} $else {
		$compile_error('Bit streams currently support native integer and float scalars')
	}
}
