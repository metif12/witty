module kitty

import os

// Tests for Kitty graphics protocol image loading.

// Directory holding the binary test fixtures shared with the Ghostty
// test suite (copied from ghostty's src/terminal/kitty/testdata).
const testdata_dir = os.join_path(os.dir(@FILE), 'testdata')

fn testdata_path(name string) string {
	return os.join_path(testdata_dir, name)
}

// This specifically tests we ALLOW invalid RGB data because Kitty
// documents that this should work.
fn test_image_load_with_invalid_rgb_data() {
	// <ESC>_Gi=31,s=1,v=1,a=q,t=d,f=24;AAAA<ESC>\
	cmd := Command{
		control: Control(Transmission{
			format_: .rgb
			width: 1
			height: 1
			image_id: 31
		})
		data: 'AAAA'.bytes()
	}
	mut loading := LoadingImage.init_from_cmd(&cmd) or {
		assert false, 'expected init to succeed: ${err}'
		return
	}
	loading.destroy()
}

fn test_image_load_with_image_too_wide() {
	cmd := Command{
		control: Control(Transmission{
			format_: .rgb
			width: u32(max_dimension + 1)
			height: 1
			image_id: 31
		})
		data: 'AAAA'.bytes()
	}
	mut loading := LoadingImage.init_from_cmd(&cmd) or {
		assert false, 'expected init to succeed: ${err}'
		return
	}
	defer {
		loading.destroy()
	}
	loading.complete() or {
		// Expected: dimensions too large
		return
	}
	assert false, 'expected error for too wide image'
}

fn test_image_load_with_image_too_tall() {
	cmd := Command{
		control: Control(Transmission{
			format_: .rgb
			height: u32(max_dimension + 1)
			width: 1
			image_id: 31
		})
		data: 'AAAA'.bytes()
	}
	mut loading := LoadingImage.init_from_cmd(&cmd) or {
		assert false, 'expected init to succeed: ${err}'
		return
	}
	defer {
		loading.destroy()
	}
	loading.complete() or {
		// Expected: dimensions too large
		return
	}
	assert false, 'expected error for too tall image'
}

fn test_image_load_rgb_zlib_compressed_direct() {
	data := os.read_bytes(testdata_path('image-rgb-zlib_deflate-128x96-2147483647-raw.data')) or {
		assert false, 'failed to read testdata: ${err}'
		return
	}
	cmd := Command{
		control: Control(Transmission{
			format_: .rgb
			medium: .direct
			compression: .zlib_deflate
			height: 96
			width: 128
			image_id: 31
		})
		data: data
	}
	mut loading := LoadingImage.init_from_cmd(&cmd) or {
		assert false, 'expected init to succeed: ${err}'
		return
	}
	defer {
		loading.destroy()
	}
	mut img := loading.complete() or {
		assert false, 'expected complete to succeed: ${err}'
		return
	}
	defer {
		img.deinit()
	}
	// should be decompressed
	assert img.compression == .none_
}

fn test_image_load_rgb_not_compressed_direct() {
	data := os.read_bytes(testdata_path('image-rgb-none-20x15-2147483647-raw.data')) or {
		assert false, 'failed to read testdata: ${err}'
		return
	}
	cmd := Command{
		control: Control(Transmission{
			format_: .rgb
			medium: .direct
			compression: .none_
			width: 20
			height: 15
			image_id: 31
		})
		data: data
	}
	mut loading := LoadingImage.init_from_cmd(&cmd) or {
		assert false, 'expected init to succeed: ${err}'
		return
	}
	defer {
		loading.destroy()
	}
	mut img := loading.complete() or {
		assert false, 'expected complete to succeed: ${err}'
		return
	}
	defer {
		img.deinit()
	}
	// should be decompressed
	assert img.compression == .none_
}

fn test_image_load_rgb_zlib_compressed_direct_chunked() {
	data := os.read_bytes(testdata_path('image-rgb-zlib_deflate-128x96-2147483647-raw.data')) or {
		assert false, 'failed to read testdata: ${err}'
		return
	}

	// Setup our initial chunk
	cmd := Command{
		control: Control(Transmission{
			format_: .rgb
			medium: .direct
			compression: .zlib_deflate
			height: 96
			width: 128
			image_id: 31
			more_chunks: true
		})
		data: data[0..1024].clone()
	}
	mut loading := LoadingImage.init_from_cmd(&cmd) or {
		assert false, 'expected init to succeed: ${err}'
		return
	}
	defer {
		loading.destroy()
	}

	// Read our remaining chunks in 1024-byte pieces.
	mut i := 1024
	for i < data.len {
		end := if i + 1024 < data.len { i + 1024 } else { data.len }
		loading.add_data(data[i..end]) or {
			assert false, 'expected add_data to succeed: ${err}'
			return
		}
		i = end
	}

	// Complete
	mut img := loading.complete() or {
		assert false, 'expected complete to succeed: ${err}'
		return
	}
	defer {
		img.deinit()
	}
	assert img.compression == .none_
}

fn test_image_load_rgb_zlib_compressed_direct_chunked_zero_initial() {
	data := os.read_bytes(testdata_path('image-rgb-zlib_deflate-128x96-2147483647-raw.data')) or {
		assert false, 'failed to read testdata: ${err}'
		return
	}

	// Setup our initial chunk with no data.
	cmd := Command{
		control: Control(Transmission{
			format_: .rgb
			medium: .direct
			compression: .zlib_deflate
			height: 96
			width: 128
			image_id: 31
			more_chunks: true
		})
	}
	mut loading := LoadingImage.init_from_cmd(&cmd) or {
		assert false, 'expected init to succeed: ${err}'
		return
	}
	defer {
		loading.destroy()
	}

	// Read all chunks in 1024-byte pieces.
	mut i := 0
	for i < data.len {
		end := if i + 1024 < data.len { i + 1024 } else { data.len }
		loading.add_data(data[i..end]) or {
			assert false, 'expected add_data to succeed: ${err}'
			return
		}
		i = end
	}

	// Complete
	mut img := loading.complete() or {
		assert false, 'expected complete to succeed: ${err}'
		return
	}
	defer {
		img.deinit()
	}
	assert img.compression == .none_
}

fn test_image_load_temporary_file_without_correct_path() {
	data := os.read_bytes(testdata_path('image-rgb-none-20x15-2147483647-raw.data')) or {
		assert false, 'failed to read testdata: ${err}'
		return
	}

	// Write to a temp file whose name does NOT contain the required
	// "tty-graphics-protocol" marker.
	tmp := os.join_path(os.temp_dir(), 'image-witty-test-${os.getpid()}.data')
	os.write_file(tmp, data.bytestr()) or {
		assert false, 'failed to write temp file: ${err}'
		return
	}
	path := os.real_path(tmp)
	defer {
		os.rm(path) or {}
	}

	cmd := Command{
		control: Control(Transmission{
			format_: .rgb
			medium: .temporary_file
			compression: .none_
			width: 20
			height: 15
			image_id: 31
		})
		data: path.bytes()
	}
	LoadingImage.init_from_cmd(&cmd) or {
		// Expected: temporary file not named correctly.
		// Temporary file should still be there.
		assert os.exists(path)
		return
	}
	assert false, 'expected error for temp file with incorrect name'
}

fn test_image_load_rgb_not_compressed_temporary_file() {
	data := os.read_bytes(testdata_path('image-rgb-none-20x15-2147483647-raw.data')) or {
		assert false, 'failed to read testdata: ${err}'
		return
	}

	// Write to a temp file whose name contains "tty-graphics-protocol".
	tmp := os.join_path(os.temp_dir(), 'tty-graphics-protocol-witty-${os.getpid()}.data')
	os.write_file(tmp, data.bytestr()) or {
		assert false, 'failed to write temp file: ${err}'
		return
	}
	path := os.real_path(tmp)

	cmd := Command{
		control: Control(Transmission{
			format_: .rgb
			medium: .temporary_file
			compression: .none_
			width: 20
			height: 15
			image_id: 31
		})
		data: path.bytes()
	}
	mut loading := LoadingImage.init_from_cmd(&cmd) or {
		os.rm(path) or {}
		assert false, 'expected init to succeed: ${err}'
		return
	}
	defer {
		loading.destroy()
	}
	mut img := loading.complete() or {
		assert false, 'expected complete to succeed: ${err}'
		return
	}
	defer {
		img.deinit()
	}
	assert img.compression == .none_

	// Temporary file should be gone (deleted after read).
	assert !os.exists(path)
}

fn test_image_load_rgb_not_compressed_regular_file() {
	data := os.read_bytes(testdata_path('image-rgb-none-20x15-2147483647-raw.data')) or {
		assert false, 'failed to read testdata: ${err}'
		return
	}

	tmp := os.join_path(os.temp_dir(), 'image-witty-regular-${os.getpid()}.data')
	os.write_file(tmp, data.bytestr()) or {
		assert false, 'failed to write temp file: ${err}'
		return
	}
	path := os.real_path(tmp)
	defer {
		os.rm(path) or {}
	}

	cmd := Command{
		control: Control(Transmission{
			format_: .rgb
			medium: .file
			compression: .none_
			width: 20
			height: 15
			image_id: 31
		})
		data: path.bytes()
	}
	mut loading := LoadingImage.init_from_cmd(&cmd) or {
		assert false, 'expected init to succeed: ${err}'
		return
	}
	defer {
		loading.destroy()
	}
	mut img := loading.complete() or {
		assert false, 'expected complete to succeed: ${err}'
		return
	}
	defer {
		img.deinit()
	}
	assert img.compression == .none_
	// Regular file (medium .file) is not deleted after read.
	assert os.exists(path)
}

fn test_image_load_png_not_compressed_regular_file() {
	data := os.read_bytes(testdata_path('image-png-none-50x76-2147483647-raw.data')) or {
		assert false, 'failed to read testdata: ${err}'
		return
	}

	tmp := os.join_path(os.temp_dir(), 'tty-graphics-protocol-witty-png-${os.getpid()}.data')
	os.write_file(tmp, data.bytestr()) or {
		assert false, 'failed to write temp file: ${err}'
		return
	}
	path := os.real_path(tmp)
	defer {
		os.rm(path) or {}
	}

	cmd := Command{
		control: Control(Transmission{
			format_: .png
			medium: .file
			compression: .none_
			width: 0
			height: 0
			image_id: 31
		})
		data: path.bytes()
	}
	mut loading := LoadingImage.init_from_cmd(&cmd) or {
		assert false, 'expected init to succeed: ${err}'
		return
	}
	defer {
		loading.destroy()
	}
	mut img := loading.complete() or {
		assert false, 'expected complete to succeed: ${err}'
		return
	}
	defer {
		img.deinit()
	}
	assert img.compression == .none_
	assert img.format == .rgba
	assert os.exists(path)
}
