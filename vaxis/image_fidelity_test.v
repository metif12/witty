module vaxis

fn test_image_fit_uses_pointer_sized_pixel_geometry() {
	mut screen := Screen{
		width:      1
		height:     1
		width_pix:  65535
		height_pix: 65535
		buf:        [Cell{}]
	}
	mut win := Window.new(&screen)
	win.width = 65535
	win.height = 32768
	mut image := Image{
		id:     1
		width:  65535
		height: 65535
	}
	image.id = 99
	opts := ImageDrawOptions{
		scale: .fit
		size:  ImageCellSize{
			cols: 7
		}
	}
	image.draw(win, opts)!
	placement := screen.buf[0].image or { panic('missing placement') }
	assert placement.img_id == 99
	size := placement.options.size or { panic('missing size') }
	assert size.rows == ?u16(32768)
	assert size.cols == none
	original := opts.size or { panic('missing original size') }
	assert original.cols == ?u16(7)
}

fn test_image_transmission_id_advance_and_exact_chunk_boundary() {
	mut vx := Vaxis.new(VaxisOptions{})
	vx.caps.kitty_graphics = true
	vx.next_img_id = 0xfffffffe
	packet := vx.transmit_pre_encoded_image('a'.repeat(4096), 0, 65535, .png)!
	assert packet.image.id == 0xfffffffe
	assert vx.next_img_id == 0xffffffff
	assert packet.sequence.count('\x1b_G') == 1
	assert packet.sequence.contains('m=1;')
	vx.caps.kitty_graphics = false
	vx.transmit_pre_encoded_image('', 1, 1, .rgb) or {
		assert err.msg() == 'NoGraphicsCapability'
		assert vx.next_img_id == 0xffffffff
		return
	}
	assert false
}

fn test_image_path_error_advances_id_and_geometry_errors_preserve_cell() {
	mut vx := Vaxis.new(VaxisOptions{})
	vx.caps.kitty_graphics = true
	vx.transmit_local_image_path('a'.repeat(3072), 1, 1, .file, .png) or {
		assert err.msg() == 'PathTooLong'
	}
	assert vx.next_img_id == 2
	mut screen := Screen{
		height: 1
		buf:    [Cell{
			char_: CellCharacter{
				grapheme: 'before'
			}
		}]
	}
	win := Window.new(&screen)
	image := Image{
		id:     7
		width:  1
		height: 1
	}
	image.draw(win, ImageDrawOptions{ scale: .fit }) or { assert err.msg() == 'DivisionByZero' }
	assert screen.buf[0].char_.grapheme == 'before'
	assert screen.buf[0].image == none
}
