// Tests for file_type module

module main

// Test detecting PNG header bytes
fn test_detect_png() {
	// PNG magic bytes: 89 50 4E 47 0D 0A 1A 0A
	png_header := [u8(0x89), 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00]
	result := detect(png_header)
	assert result == .png
}

// Test detecting JPEG header bytes (JFIF variant)
fn test_detect_jpeg() {
	// JPEG magic bytes: FF D8 FF DB
	jpeg_header := [u8(0xFF), 0xD8, 0xFF, 0xDB, 0x00, 0x00]
	result := detect(jpeg_header)
	assert result == .jpeg
}

// Test detecting JPEG with JFIF signature
fn test_detect_jpeg_jfif() {
	// JPEG JFIF: FF D8 FF E0 00 10 4A 46 49 46 00 01
	jpeg_header := [u8(0xFF), 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00,
		0x01]
	result := detect(jpeg_header)
	assert result == .jpeg
}

// Test detecting GIF header bytes (GIF89a)
fn test_detect_gif() {
	// GIF89a
	gif_header := [u8(0x47), 0x49, 0x46, 0x38, 0x39, 0x61, 0x00, 0x00]
	result := detect(gif_header)
	assert result == .gif
}

// Test detecting BMP header bytes
fn test_detect_bmp() {
	// BMP: BM
	bmp_header := [u8(0x42), 0x4D, 0x00, 0x00, 0x00, 0x00]
	result := detect(bmp_header)
	assert result == .bmp
}

// Test detecting QOI header bytes
fn test_detect_qoi() {
	// QOI: qoif
	qoi_header := [u8(0x71), 0x6F, 0x69, 0x66, 0x00, 0x00]
	result := detect(qoi_header)
	assert result == .qoi
}

// Test detecting WebP header bytes
fn test_detect_webp() {
	// WebP: RIFF....WEBP (with wildcard bytes at positions 4-7)
	webp_header := [u8(0x52), 0x49, 0x46, 0x46, 0xAA, 0xBB, 0xCC, 0xDD, 0x57, 0x45, 0x42,
		0x50]
	result := detect(webp_header)
	assert result == .webp
}

// Test that unknown data returns .unknown
fn test_detect_unknown() {
	unknown_data := [u8(0x00), 0x01, 0x02, 0x03, 0x04, 0x05]
	result := detect(unknown_data)
	assert result == .unknown
}

// Test that empty data returns .unknown
fn test_detect_empty() {
	empty_data := []u8{}
	result := detect(empty_data)
	assert result == .unknown
}

// Test that data too short for any signature returns .unknown
fn test_detect_too_short() {
	short_data := [u8(0x89)]
	result := detect(short_data)
	assert result == .unknown
}

// Test extension guessing for known extensions
fn test_guess_from_extension_png() {
	assert guess_from_extension('.png') == .png
}

fn test_guess_from_extension_jpg() {
	assert guess_from_extension('.jpg') == .jpeg
}

fn test_guess_from_extension_jpeg() {
	assert guess_from_extension('.jpeg') == .jpeg
}

fn test_guess_from_extension_jfif() {
	assert guess_from_extension('.jfif') == .jpeg
}

fn test_guess_from_extension_gif() {
	assert guess_from_extension('.gif') == .gif
}

fn test_guess_from_extension_bmp() {
	assert guess_from_extension('.bmp') == .bmp
}

fn test_guess_from_extension_qoi() {
	assert guess_from_extension('.qoi') == .qoi
}

fn test_guess_from_extension_webp() {
	assert guess_from_extension('.webp') == .webp
}

// Test case insensitive extension matching
fn test_guess_from_extension_case_insensitive() {
	assert guess_from_extension('.PNG') == .png
	assert guess_from_extension('.Jpg') == .jpeg
	assert guess_from_extension('.GIF') == .gif
	assert guess_from_extension('.gİf') == .unknown
}

// Test unknown extension
fn test_guess_from_extension_unknown() {
	assert guess_from_extension('.txt') == .unknown
	assert guess_from_extension('.zip') == .unknown
	assert guess_from_extension('') == .unknown
}
