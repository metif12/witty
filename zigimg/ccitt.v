module zigimg

// Code tables copied mechanically from the unmodified locked CCITT source.
pub struct CcittCode {
pub:
	run_length  u16
	code        u16
	code_length u8
}

pub enum CcittColor as u8 {
	black = 0
	white = 1
}

pub struct CcittDecoder {
pub mut:
	current_color  CcittColor = .white
	should_reverse bool
	width          usize
	num_rows       usize
	white_value    u8
}

pub fn CcittDecoder.init(width usize, num_rows usize, white_value u8) !CcittDecoder {
	assert white_value <= 1
	return CcittDecoder{
		width:       width
		num_rows:    num_rows
		white_value: white_value
	}
}

pub fn (mut decoder CcittDecoder) get_make_up_code(code u16, length u8) ?u16 {
	assert code <= 8191
	for makeup in ccitt_additional_make_up_codes {
		if makeup.code == code && makeup.code_length == length { return makeup.run_length }
	}
	if decoder.current_color == .white {
		for makeup in ccitt_white_make_up_codes {
			if makeup.code == code && makeup.code_length == length { return makeup.run_length }
		}
	} else {
		for makeup in ccitt_black_make_up_codes {
			if makeup.code == code && makeup.code_length == length { return makeup.run_length }
		}
	}
	return none
}

pub fn (mut decoder CcittDecoder) get_terminating_code(code u16, length u8) ?u16 {
	assert code <= 8191
	if decoder.current_color == .white {
		for terminating in ccitt_white_terminating_codes {
			if terminating.code == code && terminating.code_length == length {
				decoder.should_reverse = true
				return terminating.run_length
			}
		}
	} else {
		for terminating in ccitt_black_terminating_codes {
			if terminating.code == code && terminating.code_length == length {
				decoder.should_reverse = true
				return terminating.run_length
			}
		}
	}
	return none
}

pub fn (mut decoder CcittDecoder) get_run_length(code u16, length u8) ?u16 {
	if run := decoder.get_make_up_code(code, length) { return run }
	return decoder.get_terminating_code(code, length)
}

pub fn (mut decoder CcittDecoder) decode(mut reader ReadStream, mut writer WriteStream) ! {
	mut bit_reader := BitReader[BigEndian]{
		reader: unsafe { &reader }
	}
	mut bit_writer := BitWriter[BigEndian]{
		writer: unsafe { &writer }
	}
	mut code_length := u8(0)
	mut code := u16(0)
	mut decoded_bits := u16(0)
	mut bits_read := u16(0)
	for row := usize(0); row < decoder.num_rows; row++ {
		mut pixels_to_decode := decoder.width
		for pixels_to_decode > 0 && code_length < 14 {
			code = (code << 1) & 0x1fff
			code |= bit_reader.read_bits[BigEndian, u8](1, &bits_read)!
			code_length++
			if run := decoder.get_run_length(code, code_length) {
				assert pixels_to_decode >= run
				pixels_to_decode -= run
				assert u32(decoded_bits) + code_length <= 65535
				decoded_bits += code_length
				assert decoder.white_value <= 1
				value := if decoder.current_color == .white {
					decoder.white_value
				} else {
					decoder.white_value ^ 1
				}
				for _ in 0 .. int(run) {
					bit_writer.write_bits[BigEndian, u8](value, 1)!
				}
				code = 0
				code_length = 0
				if decoder.should_reverse {
					decoder.current_color = if decoder.current_color == .white {
						CcittColor.black
					} else {
						CcittColor.white
					}
					decoder.should_reverse = false
				}
			}
		}
		// The source accumulates decoded_bits and color across rows. Its padding
		// read uses u1, so nonzero padding wider than one bit can trap.
		remainder := decoded_bits % 8
		if remainder > 0 {
			padding := bit_reader.read_bits[BigEndian, u8](8 - remainder, &bits_read)!
			assert padding <= 1
		}
		if pixels_to_decode != 0 { return error('InvalidData') }
	}
	// There is deliberately no bit-writer flush: incomplete output bytes vanish.
}

pub const ccitt_white_terminating_codes = [
	CcittCode{
		run_length:  0
		code:        0b00110101
		code_length: 8
	},
	CcittCode{
		run_length:  1
		code:        0b000111
		code_length: 6
	},
	CcittCode{
		run_length:  2
		code:        0b0111
		code_length: 4
	},
	CcittCode{
		run_length:  3
		code:        0b1000
		code_length: 4
	},
	CcittCode{
		run_length:  4
		code:        0b1011
		code_length: 4
	},
	CcittCode{
		run_length:  5
		code:        0b1100
		code_length: 4
	},
	CcittCode{
		run_length:  6
		code:        0b1110
		code_length: 4
	},
	CcittCode{
		run_length:  7
		code:        0b1111
		code_length: 4
	},
	CcittCode{
		run_length:  8
		code:        0b10011
		code_length: 5
	},
	CcittCode{
		run_length:  9
		code:        0b10100
		code_length: 5
	},
	CcittCode{
		run_length:  10
		code:        0b00111
		code_length: 5
	},
	CcittCode{
		run_length:  11
		code:        0b01000
		code_length: 5
	},
	CcittCode{
		run_length:  12
		code:        0b001000
		code_length: 6
	},
	CcittCode{
		run_length:  13
		code:        0b000011
		code_length: 6
	},
	CcittCode{
		run_length:  14
		code:        0b110100
		code_length: 6
	},
	CcittCode{
		run_length:  15
		code:        0b110101
		code_length: 6
	},
	CcittCode{
		run_length:  16
		code:        0b101010
		code_length: 6
	},
	CcittCode{
		run_length:  17
		code:        0b101011
		code_length: 6
	},
	CcittCode{
		run_length:  18
		code:        0b0100111
		code_length: 7
	},
	CcittCode{
		run_length:  19
		code:        0b0001100
		code_length: 7
	},
	CcittCode{
		run_length:  20
		code:        0b0001000
		code_length: 7
	},
	CcittCode{
		run_length:  21
		code:        0b0010111
		code_length: 7
	},
	CcittCode{
		run_length:  22
		code:        0b0000011
		code_length: 7
	},
	CcittCode{
		run_length:  23
		code:        0b0000100
		code_length: 7
	},
	CcittCode{
		run_length:  24
		code:        0b0101000
		code_length: 7
	},
	CcittCode{
		run_length:  25
		code:        0b0101011
		code_length: 7
	},
	CcittCode{
		run_length:  26
		code:        0b0010011
		code_length: 7
	},
	CcittCode{
		run_length:  27
		code:        0b0100100
		code_length: 7
	},
	CcittCode{
		run_length:  28
		code:        0b0011000
		code_length: 7
	},
	CcittCode{
		run_length:  29
		code:        0b00000010
		code_length: 8
	},
	CcittCode{
		run_length:  30
		code:        0b00000011
		code_length: 8
	},
	CcittCode{
		run_length:  31
		code:        0b00011010
		code_length: 8
	},
	CcittCode{
		run_length:  32
		code:        0b00011011
		code_length: 8
	},
	CcittCode{
		run_length:  33
		code:        0b00010010
		code_length: 8
	},
	CcittCode{
		run_length:  34
		code:        0b00010011
		code_length: 8
	},
	CcittCode{
		run_length:  35
		code:        0b00010100
		code_length: 8
	},
	CcittCode{
		run_length:  36
		code:        0b00010101
		code_length: 8
	},
	CcittCode{
		run_length:  37
		code:        0b00010110
		code_length: 8
	},
	CcittCode{
		run_length:  38
		code:        0b00010111
		code_length: 8
	},
	CcittCode{
		run_length:  39
		code:        0b00101000
		code_length: 8
	},
	CcittCode{
		run_length:  40
		code:        0b00101001
		code_length: 8
	},
	CcittCode{
		run_length:  41
		code:        0b00101010
		code_length: 8
	},
	CcittCode{
		run_length:  42
		code:        0b00101011
		code_length: 8
	},
	CcittCode{
		run_length:  43
		code:        0b00101100
		code_length: 8
	},
	CcittCode{
		run_length:  44
		code:        0b00101101
		code_length: 8
	},
	CcittCode{
		run_length:  45
		code:        0b00000100
		code_length: 8
	},
	CcittCode{
		run_length:  46
		code:        0b00000101
		code_length: 8
	},
	CcittCode{
		run_length:  47
		code:        0b00001010
		code_length: 8
	},
	CcittCode{
		run_length:  48
		code:        0b00001011
		code_length: 8
	},
	CcittCode{
		run_length:  49
		code:        0b01010010
		code_length: 8
	},
	CcittCode{
		run_length:  50
		code:        0b01010011
		code_length: 8
	},
	CcittCode{
		run_length:  51
		code:        0b01010100
		code_length: 8
	},
	CcittCode{
		run_length:  52
		code:        0b01010101
		code_length: 8
	},
	CcittCode{
		run_length:  53
		code:        0b00100100
		code_length: 8
	},
	CcittCode{
		run_length:  54
		code:        0b00100101
		code_length: 8
	},
	CcittCode{
		run_length:  55
		code:        0b01011000
		code_length: 8
	},
	CcittCode{
		run_length:  56
		code:        0b01011001
		code_length: 8
	},
	CcittCode{
		run_length:  57
		code:        0b01011010
		code_length: 8
	},
	CcittCode{
		run_length:  58
		code:        0b01011011
		code_length: 8
	},
	CcittCode{
		run_length:  59
		code:        0b01001010
		code_length: 8
	},
	CcittCode{
		run_length:  60
		code:        0b01001011
		code_length: 8
	},
	CcittCode{
		run_length:  61
		code:        0b00110010
		code_length: 8
	},
	CcittCode{
		run_length:  62
		code:        0b00110011
		code_length: 8
	},
	CcittCode{
		run_length:  63
		code:        0b00110100
		code_length: 8
	},
]!

pub const ccitt_black_terminating_codes = [
	CcittCode{
		run_length:  0
		code:        0b0000110111
		code_length: 10
	},
	CcittCode{
		run_length:  1
		code:        0b010
		code_length: 3
	},
	CcittCode{
		run_length:  2
		code:        0b11
		code_length: 2
	},
	CcittCode{
		run_length:  3
		code:        0b10
		code_length: 2
	},
	CcittCode{
		run_length:  4
		code:        0b011
		code_length: 3
	},
	CcittCode{
		run_length:  5
		code:        0b0011
		code_length: 4
	},
	CcittCode{
		run_length:  6
		code:        0b0010
		code_length: 4
	},
	CcittCode{
		run_length:  7
		code:        0b00011
		code_length: 5
	},
	CcittCode{
		run_length:  8
		code:        0b000101
		code_length: 6
	},
	CcittCode{
		run_length:  9
		code:        0b000100
		code_length: 6
	},
	CcittCode{
		run_length:  10
		code:        0b0000100
		code_length: 7
	},
	CcittCode{
		run_length:  11
		code:        0b0000101
		code_length: 7
	},
	CcittCode{
		run_length:  12
		code:        0b0000111
		code_length: 7
	},
	CcittCode{
		run_length:  13
		code:        0b00000100
		code_length: 8
	},
	CcittCode{
		run_length:  14
		code:        0b00000111
		code_length: 8
	},
	CcittCode{
		run_length:  15
		code:        0b000011000
		code_length: 9
	},
	CcittCode{
		run_length:  16
		code:        0b0000010111
		code_length: 10
	},
	CcittCode{
		run_length:  17
		code:        0b0000011000
		code_length: 10
	},
	CcittCode{
		run_length:  18
		code:        0b0000001000
		code_length: 10
	},
	CcittCode{
		run_length:  19
		code:        0b00001100111
		code_length: 11
	},
	CcittCode{
		run_length:  20
		code:        0b00001101000
		code_length: 11
	},
	CcittCode{
		run_length:  21
		code:        0b00001101100
		code_length: 11
	},
	CcittCode{
		run_length:  22
		code:        0b00000110111
		code_length: 11
	},
	CcittCode{
		run_length:  23
		code:        0b00000101000
		code_length: 11
	},
	CcittCode{
		run_length:  24
		code:        0b00000010111
		code_length: 11
	},
	CcittCode{
		run_length:  25
		code:        0b00000011000
		code_length: 11
	},
	CcittCode{
		run_length:  26
		code:        0b000011001010
		code_length: 12
	},
	CcittCode{
		run_length:  27
		code:        0b000011001011
		code_length: 12
	},
	CcittCode{
		run_length:  28
		code:        0b000011001100
		code_length: 12
	},
	CcittCode{
		run_length:  29
		code:        0b000011001101
		code_length: 12
	},
	CcittCode{
		run_length:  30
		code:        0b000001101000
		code_length: 12
	},
	CcittCode{
		run_length:  31
		code:        0b000001101001
		code_length: 12
	},
	CcittCode{
		run_length:  32
		code:        0b000001101010
		code_length: 12
	},
	CcittCode{
		run_length:  33
		code:        0b000001101011
		code_length: 12
	},
	CcittCode{
		run_length:  34
		code:        0b000011010010
		code_length: 12
	},
	CcittCode{
		run_length:  35
		code:        0b000011010011
		code_length: 12
	},
	CcittCode{
		run_length:  36
		code:        0b000011010100
		code_length: 12
	},
	CcittCode{
		run_length:  37
		code:        0b000011010101
		code_length: 12
	},
	CcittCode{
		run_length:  38
		code:        0b000011010110
		code_length: 12
	},
	CcittCode{
		run_length:  39
		code:        0b000011010111
		code_length: 12
	},
	CcittCode{
		run_length:  40
		code:        0b000001101100
		code_length: 12
	},
	CcittCode{
		run_length:  41
		code:        0b000001101101
		code_length: 12
	},
	CcittCode{
		run_length:  42
		code:        0b000011011010
		code_length: 12
	},
	CcittCode{
		run_length:  43
		code:        0b000011011011
		code_length: 12
	},
	CcittCode{
		run_length:  44
		code:        0b000001010100
		code_length: 12
	},
	CcittCode{
		run_length:  45
		code:        0b000001010101
		code_length: 12
	},
	CcittCode{
		run_length:  46
		code:        0b000001010110
		code_length: 12
	},
	CcittCode{
		run_length:  47
		code:        0b000001010111
		code_length: 12
	},
	CcittCode{
		run_length:  48
		code:        0b000001100100
		code_length: 12
	},
	CcittCode{
		run_length:  49
		code:        0b000001100101
		code_length: 12
	},
	CcittCode{
		run_length:  50
		code:        0b000001010010
		code_length: 12
	},
	CcittCode{
		run_length:  51
		code:        0b000001010011
		code_length: 12
	},
	CcittCode{
		run_length:  52
		code:        0b000000100100
		code_length: 12
	},
	CcittCode{
		run_length:  53
		code:        0b000000110111
		code_length: 12
	},
	CcittCode{
		run_length:  54
		code:        0b000000111000
		code_length: 12
	},
	CcittCode{
		run_length:  55
		code:        0b000000100111
		code_length: 12
	},
	CcittCode{
		run_length:  56
		code:        0b000000101000
		code_length: 12
	},
	CcittCode{
		run_length:  57
		code:        0b000001011000
		code_length: 12
	},
	CcittCode{
		run_length:  58
		code:        0b000001011001
		code_length: 12
	},
	CcittCode{
		run_length:  59
		code:        0b000000101011
		code_length: 12
	},
	CcittCode{
		run_length:  60
		code:        0b000000101100
		code_length: 12
	},
	CcittCode{
		run_length:  61
		code:        0b000001011010
		code_length: 12
	},
	CcittCode{
		run_length:  62
		code:        0b000001100110
		code_length: 12
	},
	CcittCode{
		run_length:  63
		code:        0b000001100111
		code_length: 12
	},
]!

pub const ccitt_white_make_up_codes = [
	CcittCode{
		run_length:  64
		code:        0b11011
		code_length: 5
	},
	CcittCode{
		run_length:  128
		code:        0b10010
		code_length: 5
	},
	CcittCode{
		run_length:  192
		code:        0b010111
		code_length: 6
	},
	CcittCode{
		run_length:  256
		code:        0b0110111
		code_length: 7
	},
	CcittCode{
		run_length:  320
		code:        0b00110110
		code_length: 8
	},
	CcittCode{
		run_length:  384
		code:        0b00110111
		code_length: 8
	},
	CcittCode{
		run_length:  448
		code:        0b01100100
		code_length: 8
	},
	CcittCode{
		run_length:  512
		code:        0b01100101
		code_length: 8
	},
	CcittCode{
		run_length:  576
		code:        0b01101000
		code_length: 8
	},
	CcittCode{
		run_length:  640
		code:        0b01100111
		code_length: 8
	},
	CcittCode{
		run_length:  704
		code:        0b011001100
		code_length: 9
	},
	CcittCode{
		run_length:  768
		code:        0b011001101
		code_length: 9
	},
	CcittCode{
		run_length:  832
		code:        0b011010010
		code_length: 9
	},
	CcittCode{
		run_length:  896
		code:        0b011010011
		code_length: 9
	},
	CcittCode{
		run_length:  960
		code:        0b011010100
		code_length: 9
	},
	CcittCode{
		run_length:  1024
		code:        0b011010101
		code_length: 9
	},
	CcittCode{
		run_length:  1088
		code:        0b011010110
		code_length: 9
	},
	CcittCode{
		run_length:  1152
		code:        0b011010111
		code_length: 9
	},
	CcittCode{
		run_length:  1216
		code:        0b011011000
		code_length: 9
	},
	CcittCode{
		run_length:  1280
		code:        0b011011001
		code_length: 9
	},
	CcittCode{
		run_length:  1344
		code:        0b011011010
		code_length: 9
	},
	CcittCode{
		run_length:  1408
		code:        0b011011011
		code_length: 9
	},
	CcittCode{
		run_length:  1472
		code:        0b010011000
		code_length: 9
	},
	CcittCode{
		run_length:  1536
		code:        0b010011001
		code_length: 9
	},
	CcittCode{
		run_length:  1600
		code:        0b010011010
		code_length: 9
	},
	CcittCode{
		run_length:  1664
		code:        0b011000
		code_length: 6
	},
	CcittCode{
		run_length:  1728
		code:        0b010011011
		code_length: 9
	},
]!

pub const ccitt_black_make_up_codes = [
	CcittCode{
		run_length:  64
		code:        0b0000001111
		code_length: 10
	},
	CcittCode{
		run_length:  128
		code:        0b000011001000
		code_length: 12
	},
	CcittCode{
		run_length:  192
		code:        0b000011001001
		code_length: 12
	},
	CcittCode{
		run_length:  256
		code:        0b000001011011
		code_length: 12
	},
	CcittCode{
		run_length:  320
		code:        0b000000110011
		code_length: 12
	},
	CcittCode{
		run_length:  384
		code:        0b000000110100
		code_length: 12
	},
	CcittCode{
		run_length:  448
		code:        0b000000110101
		code_length: 12
	},
	CcittCode{
		run_length:  512
		code:        0b0000001101100
		code_length: 13
	},
	CcittCode{
		run_length:  576
		code:        0b0000001101101
		code_length: 13
	},
	CcittCode{
		run_length:  640
		code:        0b0000001001010
		code_length: 13
	},
	CcittCode{
		run_length:  704
		code:        0b0000001001011
		code_length: 13
	},
	CcittCode{
		run_length:  768
		code:        0b0000001001100
		code_length: 13
	},
	CcittCode{
		run_length:  832
		code:        0b0000001001101
		code_length: 13
	},
	CcittCode{
		run_length:  896
		code:        0b0000001110010
		code_length: 13
	},
	CcittCode{
		run_length:  960
		code:        0b0000001110011
		code_length: 13
	},
	CcittCode{
		run_length:  1024
		code:        0b0000001110100
		code_length: 13
	},
	CcittCode{
		run_length:  1088
		code:        0b0000001110101
		code_length: 13
	},
	CcittCode{
		run_length:  1152
		code:        0b0000001110110
		code_length: 13
	},
	CcittCode{
		run_length:  1216
		code:        0b0000001110111
		code_length: 13
	},
	CcittCode{
		run_length:  1280
		code:        0b0000001010010
		code_length: 13
	},
	CcittCode{
		run_length:  1344
		code:        0b0000001010011
		code_length: 13
	},
	CcittCode{
		run_length:  1408
		code:        0b0000001010100
		code_length: 13
	},
	CcittCode{
		run_length:  1472
		code:        0b0000001010101
		code_length: 13
	},
	CcittCode{
		run_length:  1536
		code:        0b0000001011010
		code_length: 13
	},
	CcittCode{
		run_length:  1600
		code:        0b0000001011011
		code_length: 13
	},
	CcittCode{
		run_length:  1664
		code:        0b0000001100100
		code_length: 13
	},
	CcittCode{
		run_length:  1728
		code:        0b0000001100101
		code_length: 13
	},
]!

pub const ccitt_additional_make_up_codes = [
	CcittCode{
		run_length:  1792
		code:        0b00000001000
		code_length: 11
	},
	CcittCode{
		run_length:  1856
		code:        0b00000001100
		code_length: 11
	},
	CcittCode{
		run_length:  1920
		code:        0b00000001101
		code_length: 11
	},
	CcittCode{
		run_length:  1984
		code:        0b000000010010
		code_length: 12
	},
	CcittCode{
		run_length:  2048
		code:        0b000000010011
		code_length: 12
	},
	CcittCode{
		run_length:  2112
		code:        0b000000010100
		code_length: 12
	},
	CcittCode{
		run_length:  2176
		code:        0b000000010101
		code_length: 12
	},
	CcittCode{
		run_length:  2240
		code:        0b000000010110
		code_length: 12
	},
	CcittCode{
		run_length:  2304
		code:        0b000000010111
		code_length: 12
	},
	CcittCode{
		run_length:  2368
		code:        0b000000011100
		code_length: 12
	},
	CcittCode{
		run_length:  2432
		code:        0b000000011101
		code_length: 12
	},
	CcittCode{
		run_length:  2496
		code:        0b000000011110
		code_length: 12
	},
	CcittCode{
		run_length:  2560
		code:        0b000000011111
		code_length: 12
	},
]!
