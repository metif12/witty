module zigimg

fn image_detection_code(bytes []u8, managed bool) u64 {
	format := if managed {
		Image.detect_format_from_memory(bytes) or { return image_detection_error(err.msg()) }
	} else {
		ImageUnmanaged.detect_format_from_memory(bytes) or {
			return image_detection_error(err.msg())
		}
	}
	return u64(format)
}

fn image_detection_error(message string) u64 {
	return match message {
		'Unseekable' { u64(100) }
		'EndOfStream' { u64(101) }
		'Unsupported' { u64(102) }
		'InvalidData' { u64(103) }
		else { panic(message) }
	}
}

fn image_detection_mix(mut hash []u64, value u64) {
	hash[0] = (hash[0] ^ value) * u64(1099511628211)
}

fn test_image_detection_preserves_order_short_errors_and_permissive_signatures() {
	// Small signatures are blocked by the preceding farbfeld eight-byte peek.
	for bytes in ['GIF89a'.bytes(), [u8(0xff), 0xd8], 'P7\n'.bytes(),
		'II'.bytes(), 'qoif'.bytes()] {
		assert image_detection_code(bytes, false) == 101
		assert image_detection_code(bytes, true) == 101
	}
	assert image_detection_code([]u8{}, false) == 100
	assert image_detection_code('B'.bytes(), false) == 101
	assert image_detection_code('BM'.bytes(), false) == u64(Format.bmp)
	signatures := [
		'BM'.bytes(),
		'farbfeld'.bytes(),
		'GIF89a'.bytes(),
		'FORM\0\0\0\0ILBM'.bytes(),
		[u8(0xff), 0xd8],
		'P7\n'.bytes(),
		'P1'.bytes(),
		[u8(0x0a), 5],
		'P2'.bytes(),
		png_magic_header[..],
		'P3'.bytes(),
		'qoif'.bytes(),
		[u8(0x59), 0xa6, 0x6a, 0x95],
		[u8(1), 0xda],
		'II'.bytes(),
		'MM'.bytes(),
		'P4'.bytes(),
		'P5'.bytes(),
		'P6'.bytes(),
	]
	formats := [Format.bmp, .farbfeld, .gif, .iff, .jpeg, .pam, .pbm, .pcx, .pgm, .png, .ppm, .qoi,
		.ras, .sgi, .tiff, .tiff, .pbm, .pgm, .ppm]
	for i, signature in signatures {
		mut bytes := []u8{len: 32, init: 0x9e}
		copy(mut bytes, signature)
		bytes[31] = `\n`
		assert image_detection_code(bytes, false) == u64(formats[i])
		assert image_detection_code(bytes, true) == u64(formats[i])
	}
	assert image_detection_code('garbage\n'.bytes(), false) == 102
	assert image_detection_code('garbage!'.bytes(), false) == 101
	assert image_detection_code([]u8{len: 19}, false) == u64(Format.tga)
	// TGA checks precede TIFF and accept its footer even on an invalid header.
	mut hybrid := []u8{len: 32, init: 0x9e}
	hybrid[0] = `I`
	hybrid[1] = `I`
	for i, byte in tga_signature.bytes() {
		hybrid[14 + i] = byte
	}
	hybrid[30] = `.`
	hybrid[31] = 0
	assert image_detection_code(hybrid, false) == u64(Format.tga)
	hybrid[0] = `B`
	hybrid[1] = `M`
	assert image_detection_code(hybrid, false) == u64(Format.bmp)
}

fn test_jpeg_tiff_detectors_preserve_peek_positions_and_error_policy() {
	for bytes in [[]u8{}, [u8(0xff)], [u8(0xff), 0xd8], 'II'.bytes(),
		'MM'.bytes(), 'IM'.bytes()] {
		mut jpeg := ReadStream.init_memory(bytes)
		if bytes.len < 2 {
			mut failed := false
			_ = jpeg_format_detect(mut jpeg) or {
				failed = true
				assert err.msg() == 'EndOfStream'
				false
			}
			assert failed
		} else {
			assert jpeg_format_detect(mut jpeg)! == (bytes == [u8(0xff), 0xd8])
		}
		assert jpeg.get_pos() == 0
		mut tiff := ReadStream.init_memory(bytes)
		assert tiff_format_detect(mut tiff)! == (bytes in ['II'.bytes(),
			'MM'.bytes()])
		assert tiff.get_pos() == 0
	}
}

fn test_image_detection_matches_locked_prefix_matrix() {
	mut hash := [u64(14695981039346656037)]
	mut cases := 0
	mut buffer := []u8{len: 32, init: 0x9e}
	buffer[31] = `\n`
	for prefix in 0 .. 65536 {
		buffer[0] = u8(prefix >> 8)
		buffer[1] = u8(prefix)
		for size in [0, 1, 2, 3, 7, 8, 12, 19, 32] {
			code := image_detection_code(unsafe { buffer[..size] }, false)
			image_detection_mix(mut hash, u64(prefix))
			image_detection_mix(mut hash, u64(size))
			image_detection_mix(mut hash, code)
			cases++
		}
	}
	eprintln('image detection matrix: ${cases} cases, ${hash[0]:016x}')
	assert cases == 589824
	assert hash[0] == u64(0xac90c12c037cfaf4)
}
