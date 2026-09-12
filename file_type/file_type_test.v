module file_type

fn test_detect() {
	assert detect([u8(0xff), 0xd8, 0xff, 0xdb]) == .jpeg
	assert detect([u8(0xff), 0xd8, 0xff, 0xe0, 0x00, 0x10, `J`, `F`, `I`, `F`, 0x00, 0x01]) == .jpeg
	assert detect([u8(0xff), 0xd8, 0xff, 0xee]) == .jpeg
	assert detect([u8(0xff), 0xd8, 0xff, 0xe1, 0x12, 0x34, `E`, `x`, `i`, `f`, 0x00, 0x00]) == .jpeg
	assert detect([u8(0x89), `P`, `N`, `G`, 0x0d, 0x0a, 0x1a, 0x0a]) == .png
	assert detect('GIF87a'.bytes()) == .gif
	assert detect('GIF89a'.bytes()) == .gif
	assert detect('BM'.bytes()) == .bmp
	assert detect('qoif'.bytes()) == .qoi
	assert detect([u8(`R`), `I`, `F`, `F`, 0xaa, 0xbb, 0xcc, 0xdd, `W`, `E`, `B`, `P`]) == .webp
	assert detect([]u8{}) == .unknown
	assert detect([u8(0x89)]) == .unknown
	assert detect([u8(0x00), 0x01, 0x02, 0x03]) == .unknown
}

fn test_guess_from_extension() {
	assert guess_from_extension('.jpg') == .jpeg
	assert guess_from_extension('.jpeg') == .jpeg
	assert guess_from_extension('.jfif') == .jpeg
	assert guess_from_extension('.png') == .png
	assert guess_from_extension('.gif') == .gif
	assert guess_from_extension('.bmp') == .bmp
	assert guess_from_extension('.qoi') == .qoi
	assert guess_from_extension('.webp') == .webp
	assert guess_from_extension('.PNG') == .png
	assert guess_from_extension('.Jpg') == .jpeg
	assert guess_from_extension('.GIF') == .gif
	assert guess_from_extension('.gİf') == .unknown
	assert guess_from_extension('.txt') == .unknown
	assert guess_from_extension('') == .unknown
}
