module vaxis

fn test_vaxis_image_transmission_and_capability_gate() {
	mut vx := Vaxis.new(VaxisOptions{})
	blocked := vx.transmit_pre_encoded_image('YWJj', 2, 3, .png) or {
		assert err.msg() == 'NoGraphicsCapability'
		ImageTransmission{}
	}
	assert blocked.sequence == ''
	assert vx.next_img_id == 1
	vx.caps.kitty_graphics = true
	first := vx.transmit_local_image_path('/tmp/a', 2, 3, .file, .rgb)!
	assert first.image.id == 1
	assert first.sequence == '\x1b_Gf=24,s=2,v=3,i=1,t=f;L3RtcC9h\x1b\\'
	second := vx.transmit_pre_encoded_image('YWJj', 4, 5, .png)!
	assert second.image.id == 2
	assert second.sequence == '\x1b_Gf=100,s=4,v=5,i=2;YWJj\x1b\\'
	assert vx.free_image(2) == '\x1b_Ga=d,d=I,i=2;\x1b\\'
	long_bytes := 'a'.repeat(4097)
	chunked := vx.transmit_pre_encoded_image(long_bytes, 1, 1, .rgba)!
	assert chunked.sequence.starts_with('\x1b_Gf=32,s=1,v=1,i=3,m=1;')
	assert chunked.sequence.ends_with('\x1b_Gm=0;a\x1b\\')
	assert chunked.sequence.count('\x1b_G') == 2
	vx.screen.deinit()
	vx.screen_last.deinit()
}

fn test_vaxis_image_draw_scale_and_cell_size() {
	mut screen := Screen.new(Winsize{
		cols:    10
		rows:    5
		x_pixel: 100
		y_pixel: 50
	})
	win := Window.new(&screen)
	img := Image{
		id:     7
		width:  80
		height: 60
	}
	size := img.cell_size(win)!
	assert size.cols == 8
	assert size.rows == 6
	img.draw(win, ImageDrawOptions{
		scale: .fit
	})!
	cell := screen.read_cell(0, 0) or { panic('missing image cell') }
	placed := cell.image or { panic('missing image placement') }
	assert placed.img_id == 7
	assert placed.options.size != none
	dims := placed.options.size or { panic('missing dimensions') }
	assert (dims.rows or { panic('missing rows') }) == 5
	screen.deinit()
}
