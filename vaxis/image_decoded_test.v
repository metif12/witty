module vaxis

import os
import zigimg

fn test_decoded_image_source_conversion_and_transmission() {
	mut vx := Vaxis.new(VaxisOptions{})
	defer { vx.screen.deinit(); vx.screen_last.deinit() }
	mut image := zigimg.Image.from_raw_pixels(2, 1, [u8(10), 20, 30, 40, 50, 60, 70, 80], .rgba32)!
	vx.transmit_image(mut image, .rgb) or { assert err.msg() == 'NoGraphicsCapability' }
	assert image.pixel_format() == .rgba32 && vx.next_img_id == 1
	vx.caps.kitty_graphics = true
	rgb := vx.transmit_image(mut image, .rgb)!
	assert image.pixel_format() == .rgb24
	assert rgb.sequence == '\x1b_Gf=24,s=2,v=1,i=1;AgMFEBMW\x1b\\'
	rgba := vx.transmit_image(mut image, .rgba)!
	assert image.pixel_format() == .rgba32
	assert rgba.sequence == '\x1b_Gf=32,s=2,v=1,i=2;AgMF/xATFv8=\x1b\\'
	png := vx.transmit_image(mut image, .png)!
	// This locked zigimg revision's PNG writer emits its signature only.
	assert png.sequence == '\x1b_Gf=100,s=2,v=1,i=3;iVBORw0KGgo=\x1b\\'
	mut too_small := zigimg.Image.create(1, 1, .rgb24)!
	vx.transmit_image(mut too_small, .png) or { assert err.msg() == 'WriteFailed' }
	assert vx.next_img_id == 4
}

fn test_load_image_path_and_memory_sources_use_registry_and_cleanup() {
	mut vx := Vaxis.new(VaxisOptions{})
	defer { vx.screen.deinit(); vx.screen_last.deinit() }
	vx.load_image(ImageSourcePath{ path: '/missing/should-not-be-opened' }) or {
		assert err.msg() == 'NoGraphicsCapability'
	}
	vx.caps.kitty_graphics = true
	image := zigimg.Image.create(8, 1, .rgba32)!
	mut encoded_buffer := []u8{len: 128}
	encoded := image.write_to_memory(mut encoded_buffer, zigimg.QoiEncoderOptions{})!
	memory := vx.load_image(ImageSourceMemory{bytes: encoded})!
	assert memory.image.width == 8 && memory.image.height == 1
	assert memory.sequence == '\x1b_Gf=100,s=8,v=1,i=1;iVBORw0KGgo=\x1b\\'
	path := os.join_path(os.temp_dir(), 'witty-vaxis-image-${os.getpid()}.qoi')
	os.write_file_array(path, encoded)!
	defer { os.rm(path) or {} }
	file := vx.load_image(ImageSourcePath{path: path})!
	assert file.image.width == memory.image.width && file.image.height == memory.image.height
	assert file.sequence == '\x1b_Gf=100,s=8,v=1,i=2;iVBORw0KGgo=\x1b\\'
}
