module zigimg

// The source's endian type factory uses the same markers as BitReader.
// Its u13 code fields and u4 remaining-bit count use wider V backing values.
pub struct LzwDecoder[E] {
pub mut:
	code_size            u8
	clear_code           u16
	initial_code_size    u8
	end_information_code u16
	next_code            u16
	previous_code        ?u16
	dictionary           map[u16][]u8 @[required]
	remaining_data       ?u16
	remaining_bits       u8
	early_change         u8
}

pub fn lzw_decoder_init[E](initial_code_size u8, early_change u8) !LzwDecoder[E] {
	if initial_code_size > 15 { panic('integer does not fit in destination type') }
	if initial_code_size >= 13 { panic('shift amount is greater than the type size') }
	root := (u16(1) << initial_code_size) & 0x1fff
	mut decoder := LzwDecoder[E]{
		dictionary:           map[u16][]u8{}
		code_size:            initial_code_size
		initial_code_size:    initial_code_size
		clear_code:           root
		end_information_code: root + 1
		next_code:            root + 2
		early_change:         early_change
	}
	decoder.reset_dictionary()!
	return decoder
}

pub fn LzwDecoder.init[E](initial_code_size u8, early_change u8) !LzwDecoder[E] {
	return lzw_decoder_init[E](initial_code_size, early_change)!
}

pub fn (mut decoder LzwDecoder[E]) deinit[E]() {
	decoder.dictionary.clear()
}

fn (mut decoder LzwDecoder[E]) reset_dictionary[E]() ! {
	decoder.dictionary.clear()
	decoder.code_size = decoder.initial_code_size
	if decoder.initial_code_size > 15 { panic('integer does not fit in destination type') }
	if decoder.initial_code_size >= 13 { panic('shift amount is greater than the type size') }
	decoder.next_code = ((u16(1) << decoder.initial_code_size) & 0x1fff) + 2
	roots_size := usize(1) << decoder.code_size
	for index := usize(0); index < roots_size; index++ {
		decoder.dictionary[u16(index)] = [u8(index)]
	}
	// The pinned reset leaves previous_code and the partial-input fields alone.
}

fn (mut decoder LzwDecoder[E]) advance_code[E](bits_to_read u8) u8 {
	if decoder.next_code == 8191 { panic('integer overflow') }
	decoder.next_code++
	if decoder.code_size == 255 { panic('integer overflow') }
	if decoder.code_size + 1 > 15 { panic('integer does not fit in destination type') }
	if decoder.code_size + 1 >= 13 { panic('shift amount is greater than the type size') }
	max_code := u16((u16(1) << (decoder.code_size + 1)) & 0x1fff)
	if max_code < decoder.early_change { panic('integer overflow') }
	if decoder.next_code == max_code - decoder.early_change && decoder.code_size + 1 < 12 {
		decoder.code_size++
		return bits_to_read + 1
	}
	return bits_to_read
}

pub fn (mut decoder LzwDecoder[E]) decode[E](mut reader ReadStream, mut writer WriteStream) ! {
	mut bit_reader := BitReader[E]{
		reader: unsafe { &reader }
	}
	if decoder.code_size == 255 { panic('integer overflow') }
	mut bits_to_read := decoder.code_size + 1
	mut read_size := u16(0)
	mut read_code := u16(0)
	if remaining_data := decoder.remaining_data {
		rest := lzw_read_bits(mut bit_reader, decoder.remaining_bits, &read_size)!
		if read_size > 0 {
			$if E.unaliased_typ is LittleEndian {
				if bits_to_read < decoder.remaining_bits { panic('integer overflow') }
				shift := bits_to_read - decoder.remaining_bits
				if shift > 15 { panic('integer does not fit in destination type') }
				if shift >= 13 { panic('shift amount is greater than the type size') }
				read_code = (remaining_data | (rest << shift)) & 0x1fff
			} $else $if E.unaliased_typ is BigEndian {
				if decoder.remaining_bits > 15 { panic('integer does not fit in destination type') }
				if decoder.remaining_bits >= 13 {
					panic('shift amount is greater than the type size')
				}
				read_code = ((remaining_data << decoder.remaining_bits) | rest) & 0x1fff
			} $else {
				$compile_error('LzwDecoder requires BigEndian or LittleEndian')
			}
		}
		decoder.remaining_data = none
	} else {
		read_code = lzw_read_bits(mut bit_reader, bits_to_read, &read_size)!
	}
	for read_size > 0 {
		if read_code in decoder.dictionary {
			value := decoder.dictionary[read_code]
			writer.write(value)!
			if previous_code := decoder.previous_code {
				if previous_code in decoder.dictionary {
					mut new_value := decoder.dictionary[previous_code].clone()
					if value.len == 0 { panic('index out of bounds: index 0, len 0') }
					new_value << value[0]
					decoder.dictionary[decoder.next_code] = new_value
					bits_to_read = decoder.advance_code(bits_to_read)
				}
			}
		} else if read_code == decoder.clear_code {
			decoder.reset_dictionary()!
			bits_to_read = decoder.code_size + 1
			decoder.previous_code = read_code
		} else if read_code == decoder.end_information_code {
			return
		} else if previous_code := decoder.previous_code {
			if previous_code in decoder.dictionary {
				previous_value := decoder.dictionary[previous_code]
				mut new_value := previous_value.clone()
				if previous_value.len == 0 { panic('index out of bounds: index 0, len 0') }
				new_value << previous_value[0]
				// In this source branch the dictionary is updated before writing,
				// but its next code and size advance only after a successful write.
				decoder.dictionary[decoder.next_code] = new_value
				writer.write(new_value)!
				bits_to_read = decoder.advance_code(bits_to_read)
			}
		}
		decoder.previous_code = read_code
		read_code = lzw_read_bits(mut bit_reader, bits_to_read, &read_size)!
		if read_size != bits_to_read {
			decoder.remaining_data = read_code
			if u16(bits_to_read) - read_size > 15 {
				panic('integer does not fit in destination type')
			}
			decoder.remaining_bits = u8(u16(bits_to_read) - read_size)
			return
		}
	}
}

// io.BitReader reads LZW codes into u13. Keep its truncation at every shift,
// including partial/oversized reads, before using the wider V carrier.
fn lzw_read_bits[E](mut bits BitReader[E], num u16, out_bits &u16) !u16 {
	if num <= bits.count {
		value := u16(bits.remove_bits(u8(num)))
		unsafe { *out_bits = num }
		return value
	}
	mut count := u16(bits.count)
	mut value := u16(bits.remove_bits(bits.count))
	full_bytes := (num - count) / 8
	for _ in 0 .. full_bytes {
		byte := bits.reader.take_byte() or {
			if err.msg() == 'EndOfStream' {
				unsafe { *out_bits = count }
				return value
			}
			return err
		}
		$if E.unaliased_typ is BigEndian {
			value = ((value << 8) | byte) & 0x1fff
		} $else $if E.unaliased_typ is LittleEndian {
			if count > 15 { panic('integer does not fit in destination type') }
			if count >= 13 { panic('shift amount is greater than the type size') }
			value = (value | (u16(byte) << count)) & 0x1fff
		} $else {
			$compile_error('LzwDecoder requires BigEndian or LittleEndian')
		}
		count += 8
	}
	left := num - count
	if left == 0 {
		unsafe { *out_bits = count }
		return value
	}
	byte := bits.reader.take_byte() or {
		if err.msg() == 'EndOfStream' {
			unsafe { *out_bits = count }
			return value
		}
		return err
	}
	keep := u8(8 - left)
	$if E.unaliased_typ is BigEndian {
		value = ((value << left) | (byte >> keep)) & 0x1fff
		bits.bits = byte & bit_mask(keep)
	} $else $if E.unaliased_typ is LittleEndian {
		if count > 15 { panic('integer does not fit in destination type') }
		if count >= 13 { panic('shift amount is greater than the type size') }
		value = (value | (u16(byte & bit_mask(u8(left))) << count)) & 0x1fff
		bits.bits = byte >> left
	}
	bits.count = keep
	unsafe { *out_bits = num }
	return value
}
