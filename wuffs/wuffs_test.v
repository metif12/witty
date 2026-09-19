module wuffs

const black_png = $embed_file('@VMODROOT/wuffs/testdata/1x1#000000.png').to_bytes()
const white_png = $embed_file('@VMODROOT/wuffs/testdata/1x1#FFFFFF.png').to_bytes()
const black_jpeg = $embed_file('@VMODROOT/wuffs/testdata/1x1#000000.jpg').to_bytes()
const white_jpeg = $embed_file('@VMODROOT/wuffs/testdata/1x1#FFFFFF.jpg').to_bytes()
const too_big_png = $embed_file('@VMODROOT/wuffs/testdata/too_big.png').to_bytes()

fn test_png_decode_black_and_white() {
	black := png_decode(black_png)!
	assert black.width == 1
	assert black.height == 1
	assert black.data == [u8(0), 0, 0, 255]

	white := png_decode(white_png)!
	assert white.width == 1
	assert white.height == 1
	assert white.data == [u8(255), 255, 255, 255]
}

fn test_jpeg_decode_black_and_white() {
	black := jpeg_decode(black_jpeg)!
	assert black.width == 1
	assert black.height == 1
	assert black.data == [u8(0), 0, 0, 255]

	white := jpeg_decode(white_jpeg)!
	assert white.width == 1
	assert white.height == 1
	assert white.data == [u8(255), 255, 255, 255]
}

fn test_decode_rejects_invalid_data() {
	data := [u8(1), 2, 3]
	png_decode(data) or {
		assert err.msg() == 'WuffsError'
		return
	}
	assert false
}

fn test_png_decode_rejects_image_over_storage_limit() {
	png_decode(too_big_png) or {
		assert err.msg() == 'Overflow'
		return
	}
	assert false
}

fn test_swizzle_all_source_formats() {
	assert g_to_rgba([u8(0), 127, 255])! == [u8(0), 0, 0, 255, 127, 127, 127, 255,
		255, 255, 255, 255]
	ga_to_rgba([u8(20), 128]) or {
		// The pinned Wuffs amalgamation does not implement YA_PREMUL as a
		// swizzler source, so Ghostty's wrapper propagates WuffsError here.
		assert err.msg() == 'WuffsError'
	}
	assert rgb_to_rgba([u8(1), 2, 3])! == [u8(1), 2, 3, 255]
	assert bgr_to_rgba([u8(3), 2, 1])! == [u8(1), 2, 3, 255]
	assert bgra_to_rgba([u8(3), 2, 1, 4])! == [u8(1), 2, 3, 4]
}
