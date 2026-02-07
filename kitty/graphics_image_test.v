module kitty

// Tests for Kitty graphics protocol image loading.

// This specifically tests we ALLOW invalid RGB data because Kitty
// documents that this should work.
fn test_image_load_with_invalid_rgb_data() {
	// <ESC>_Gi=31,s=1,v=1,a=q,t=d,f=24;AAAA<ESC>\
	cmd := Command{
		control: Control(Transmission{
			format: .rgb
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
			format: .rgb
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
			format: .rgb
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

// XTODO: The following tests from the Zig source require embedded test data files
// and platform-specific functionality (file I/O, temp dirs, shared memory, zlib,
// PNG decoding) that are not yet available:
//
// - image load: rgb, zlib compressed, direct
// - image load: rgb, not compressed, direct
// - image load: rgb, zlib compressed, direct, chunked
// - image load: rgb, zlib compressed, direct, chunked with zero initial chunk
// - image load: temporary file without correct path
// - image load: rgb, not compressed, temporary file
// - image load: rgb, not compressed, regular file
// - image load: png, not compressed, regular file
