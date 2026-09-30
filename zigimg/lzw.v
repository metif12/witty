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
	dictionary           map[u16][]u8
	remaining_data       ?u16
	remaining_bits       u8
	early_change         u8
}

pub fn lzw_decoder_init[E](initial_code_size u8, early_change u8) !LzwDecoder[E] {
	// Larger initial dictionaries eventually overflow the source's u13 index.
	assert initial_code_size <= 12
	root := u16(1) << initial_code_size
	mut decoder := LzwDecoder[E]{
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
	decoder.next_code = (u16(1) << decoder.initial_code_size) + 2
	for index := u16(0); index < u16(1) << decoder.code_size; index++ {
		decoder.dictionary[index] = [u8(index)]
	}
	// The pinned reset leaves previous_code and the partial-input fields alone.
}

fn (mut decoder LzwDecoder[E]) advance_code[E](bits_to_read u8) u8 {
	assert decoder.next_code < 8191
	decoder.next_code++
	assert decoder.code_size + 1 < 16
	max_code := u16((u16(1) << (decoder.code_size + 1)) & 0x1fff)
	assert max_code >= decoder.early_change
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
	assert decoder.code_size < 255
	mut bits_to_read := decoder.code_size + 1
	mut read_size := u16(0)
	mut read_code := u16(0)
	if remaining_data := decoder.remaining_data {
		rest := u16(bit_reader.read_bits[E, u16](decoder.remaining_bits, &read_size)!)
		if read_size > 0 {
			$if E is LittleEndian {
				assert bits_to_read >= decoder.remaining_bits
				shift := bits_to_read - decoder.remaining_bits
				assert shift < 16
				read_code = (remaining_data | (rest << shift)) & 0x1fff
			} $else $if E is BigEndian {
				assert decoder.remaining_bits < 16
				read_code = ((remaining_data << decoder.remaining_bits) | rest) & 0x1fff
			} $else {
				$compile_error('LzwDecoder requires BigEndian or LittleEndian')
			}
		}
		decoder.remaining_data = none
	} else {
		read_code = bit_reader.read_bits[E, u16](bits_to_read, &read_size)!
		assert read_code <= 0x1fff
	}
	for read_size > 0 {
		if read_code in decoder.dictionary {
			value := decoder.dictionary[read_code]
			writer.write(value)!
			if previous_code := decoder.previous_code {
				if previous_code in decoder.dictionary {
					mut new_value := decoder.dictionary[previous_code].clone()
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
				new_value << previous_value[0]
				// In this source branch the dictionary is updated before writing,
				// but its next code and size advance only after a successful write.
				decoder.dictionary[decoder.next_code] = new_value
				writer.write(new_value)!
				bits_to_read = decoder.advance_code(bits_to_read)
			}
		}
		decoder.previous_code = read_code
		read_code = bit_reader.read_bits[E, u16](bits_to_read, &read_size)!
		assert read_code <= 0x1fff
		if read_size != bits_to_read {
			decoder.remaining_data = read_code
			decoder.remaining_bits = u8(u16(bits_to_read) - read_size)
			assert decoder.remaining_bits < 16
			return
		}
	}
}
