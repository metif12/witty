module zigimg

fn test_bit_reader_and_writer_match_pinned_byte_order() {
	check_bit_order[BigEndian]([u8(0xcd), 0x0b])!
	check_bit_order[LittleEndian]([u8(0x1d), 0x95])!
}

fn check_bit_order[E](expected []u8) ! {
	mut bytes := []u8{len: 2}
	mut writer := WriteStream.init_memory(mut bytes)
	mut bits := BitWriter[E]{
		writer: unsafe { &writer }
	}
	for i, num in [u16(1), u16(2), u16(3), u16(4), u16(5), u16(1)] {
		value := if i == 5 { u16(1) } else { u16(i + 1) }
		bits.write_bits[E, u16](value, num)!
	}
	assert bytes == expected
	assert bits.count == 0
	mut reader := ReadStream.init_memory(bytes)
	mut read_bits := BitReader[E]{
		reader: unsafe { &reader }
	}
	for i, num in [u16(1), u16(2), u16(3), u16(4), u16(5), u16(1)] {
		value, count := read_bits.read_bits_tuple[E, u16](num)!
		assert u16(value) == if i == 5 {
			u16(1)
		} else {
			u16(i + 1)
		}
		assert count == num
	}
	value, count := read_bits.read_bits_tuple[E, u8](0)!
	assert value == 0 && count == 0
	read_bits.read_bits_no_eof[E, u8](1) or {
		assert err.msg() == 'EndOfStream'
		return
	}
	assert false
}

fn test_bit_read_partial_eof_alignment_and_signed_bits() {
	mut reader := ReadStream.init_memory([u8(0xab)])
	mut bits := BitReader[BigEndian]{
		reader: unsafe { &reader }
	}
	assert bits.read_bits_no_eof[BigEndian, u8](3)! == 5
	assert bits.bits == 0x0b && bits.count == 5
	value, count := bits.read_bits_tuple[BigEndian, u16](10)!
	assert value == 0x0b && count == 5
	assert bits.count == 0
	reader.seek_to(0)!
	assert bits.read_bits_no_eof[BigEndian, u8](1)! == 1
	bits.align_to_byte()
	assert bits.bits == 0 && bits.count == 0
	reader.seek_to(0)!
	assert bits.read_bits_no_eof[BigEndian, i8](8)! == i8(-85)
	reader.seek_to(0)!
	mut count_out := u16(99)
	assert bits.read_bits[BigEndian, u16](16, &count_out)! == 0xab
	assert count_out == 8

	mut le_reader := ReadStream.init_memory([u8(0xab), 0xcd])
	mut le := BitReader[LittleEndian]{
		reader: unsafe { &le_reader }
	}
	assert le.read_bits_no_eof[LittleEndian, u8](3)! == 3
	partial, partial_count := le.read_bits_tuple[LittleEndian, u32](20)!
	assert partial == 0x19b5 && partial_count == 13
}

fn test_bit_writer_preserves_padding_unused_input_bits_and_failure_state() {
	mut bytes := []u8{len: 2}
	mut writer := WriteStream.init_memory(mut bytes)
	mut be := BitWriter[BigEndian]{
		writer: unsafe { &writer }
	}
	be.write_bits[BigEndian, u16](0b110011010000101, 15)!
	be.flush_bits()!
	assert bytes == [u8(0xcd), 0x0a]
	writer.seek_to(0)!
	mut le := BitWriter[LittleEndian]{
		writer: unsafe { &writer }
	}
	le.write_bits[LittleEndian, u16](0b110011010000101, 15)!
	le.flush_bits()!
	assert bytes == [u8(0x85), 0x66]
	writer.seek_to(0)!
	le.write_bits[LittleEndian, u8](0xff, 1)!
	le.write_bits[LittleEndian, u8](0, 7)!
	assert bytes[0] == 0xff // Source's little-endian addBits does not mask input.
	mut empty := []u8{}
	mut fixed := WriteStream.init_memory(mut empty)
	mut failing := BitWriter[BigEndian]{
		writer: unsafe { &fixed }
	}
	failing.write_bits[BigEndian, u8](5, 3)!
	failing.flush_bits() or {
		assert err.msg() == 'WriteFailed'
		assert failing.bits == 0xa0 && failing.count == 3
		return
	}
	assert false
}

fn test_bit_stream_full_64_bit_values_and_cross_byte_boundaries() {
	mut bytes := []u8{len: 9}
	mut writer := WriteStream.init_memory(mut bytes)
	mut bits := BitWriter[BigEndian]{
		writer: unsafe { &writer }
	}
	bits.write_bits[BigEndian, u8](1, 1)!
	bits.write_bits[BigEndian, u64](0xfedcba9876543210, 64)!
	bits.flush_bits()!
	assert bytes == [u8(0xff), 0x6e, 0x5d, 0x4c, 0x3b, 0x2a, 0x19, 0x08, 0x00]
	mut reader := ReadStream.init_memory(bytes)
	mut read_bits := BitReader[BigEndian]{
		reader: unsafe { &reader }
	}
	assert read_bits.read_bits_no_eof[BigEndian, u8](1)! == 1
	assert read_bits.read_bits_no_eof[BigEndian, u64](64)! == 0xfedcba9876543210
}

fn test_bit_stream_reinterprets_floating_point_values() {
	mut bytes := []u8{len: 8}
	mut writer := WriteStream.init_memory(mut bytes)
	mut be := BitWriter[BigEndian]{
		writer: unsafe { &writer }
	}
	be.write_bits[BigEndian, f32](-2.5, 32)!
	assert writer.buffered() == [u8(0xc0), 0x20, 0, 0]
	mut reader := ReadStream.init_memory(writer.buffered())
	mut read_be := BitReader[BigEndian]{
		reader: unsafe { &reader }
	}
	assert read_be.read_bits_no_eof[BigEndian, f32](32)! == -2.5
	writer.seek_to(0)!
	mut le := BitWriter[LittleEndian]{
		writer: unsafe { &writer }
	}
	le.write_bits[LittleEndian, f64](1.0, 64)!
	assert writer.buffered() == [u8(0), 0, 0, 0, 0, 0, 0xf0, 0x3f]
	reader = ReadStream.init_memory(bytes)
	mut read_le := BitReader[LittleEndian]{
		reader: unsafe { &reader }
	}
	assert read_le.read_bits_no_eof[LittleEndian, f64](64)! == 1.0
}
