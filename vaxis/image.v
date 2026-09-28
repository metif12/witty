module vaxis

import encoding.base64
import strings

pub enum ImageTransmitFormat as u8 {
	rgb
	rgba
	png
}

pub enum ImageTransmitMedium as u8 {
	file
	temp_file
	shared_mem
}

pub struct Image {
pub:
	id     u32
	width  u16
	height u16
}

pub struct ImageCellDimensions {
pub:
	rows u16
	cols u16
}

pub struct ImageTransmission {
pub:
	image    Image
	sequence string
}

pub fn (img Image) draw(win Window, opts ImageDrawOptions) ! {
	mut placed := opts
	match opts.scale {
		.none {}
		.fill {
			placed.size = ImageCellSize{
				rows: win.height
				cols: win.width
			}
		}
		.fit, .contain {
			screen := win.screen
			if screen.width == 0 || screen.height == 0 {
				return error('DivisionByZero')
			}
			pix_per_col := (int(screen.width_pix) + int(screen.width) - 1) / int(screen.width)
			pix_per_row := (int(screen.height_pix) + int(screen.height) - 1) / int(screen.height)
			win_width_pix := pix_per_col * int(win.width)
			win_height_pix := pix_per_row * int(win.height)
			fit_x := win_width_pix >= int(img.width)
			fit_y := win_height_pix >= int(img.height)
			if !(opts.scale == .contain && fit_x && fit_y) {
				if fit_x && !fit_y {
					placed.size = ImageCellSize{
						rows: win.height
					}
				} else if !fit_x && fit_y {
					placed.size = ImageCellSize{
						cols: win.width
					}
				} else if !fit_x && !fit_y {
					if int(img.width) - win_width_pix > int(img.height) - win_height_pix {
						placed.size = ImageCellSize{
							cols: win.width
						}
					} else {
						placed.size = ImageCellSize{
							rows: win.height
						}
					}
				} else {
					assert opts.scale == .fit
					if win_width_pix - int(img.width) < win_height_pix - int(img.height) {
						placed.size = ImageCellSize{
							cols: win.width
						}
					} else {
						placed.size = ImageCellSize{
							rows: win.height
						}
					}
				}
			}
		}
	}
	win.write_cell(0, 0, Cell{
		image: ImagePlacement{
			img_id:  img.id
			options: placed
		}
	})
}

pub fn (img Image) cell_size(win Window) !ImageCellDimensions {
	screen := win.screen
	if screen.width == 0 || screen.height == 0 {
		return error('DivisionByZero')
	}
	pix_per_col := (int(screen.width_pix) + int(screen.width) - 1) / int(screen.width)
	pix_per_row := (int(screen.height_pix) + int(screen.height) - 1) / int(screen.height)
	return ImageCellDimensions{
		cols: if pix_per_col == 0 {
			u16(0)
		} else {
			u16((int(img.width) + pix_per_col - 1) / pix_per_col)
		}
		rows: if pix_per_row == 0 {
			u16(0)
		} else {
			u16((int(img.height) + pix_per_row - 1) / pix_per_row)
		}
	}
}

pub fn (mut vx Vaxis) transmit_local_image_path(payload string, width u16, height u16, medium ImageTransmitMedium, format ImageTransmitFormat) !ImageTransmission {
	if !vx.caps.kitty_graphics {
		return error('NoGraphicsCapability')
	}
	id := vx.next_img_id
	vx.next_img_id++
	encoded := base64.encode_str(payload)
	if encoded.len >= 4096 {
		return error('PathTooLong')
	}
	medium_char := match medium {
		.file { 'f' }
		.temp_file { 't' }
		.shared_mem { 's' }
	}
	sequence := match format {
		.rgb { '\x1b_Gf=24,s=${width},v=${height},i=${id},t=${medium_char};${encoded}\x1b\\' }
		.rgba { '\x1b_Gf=32,s=${width},v=${height},i=${id},t=${medium_char};${encoded}\x1b\\' }
		.png { '\x1b_Gf=100,i=${id},t=${medium_char};${encoded}\x1b\\' }
	}
	return ImageTransmission{
		image:    Image{
			id:     id
			width:  width
			height: height
		}
		sequence: sequence
	}
}

pub fn (mut vx Vaxis) transmit_pre_encoded_image(bytes string, width u16, height u16, format ImageTransmitFormat) !ImageTransmission {
	if !vx.caps.kitty_graphics {
		return error('NoGraphicsCapability')
	}
	id := vx.next_img_id
	vx.next_img_id++
	fmt := match format {
		.rgb { 24 }
		.rgba { 32 }
		.png { 100 }
	}
	mut out := strings.new_builder(bytes.len + 128)
	if bytes.len < 4096 {
		out.write_string('\x1b_Gf=${fmt},s=${width},v=${height},i=${id};${bytes}\x1b\\')
	} else {
		out.write_string('\x1b_Gf=${fmt},s=${width},v=${height},i=${id},m=1;${bytes[..4096]}\x1b\\')
		mut n := 4096
		for n < bytes.len {
			end_at := min_int(n + 4096, bytes.len)
			m := if end_at == bytes.len { 0 } else { 1 }
			out.write_string('\x1b_Gm=${m};${bytes[n..end_at]}\x1b\\')
			n += 4096
		}
	}
	return ImageTransmission{
		image:    Image{
			id:     id
			width:  width
			height: height
		}
		sequence: out.str()
	}
}

pub fn (vx &Vaxis) free_image(id u32) string {
	_ = vx
	return '\x1b_Ga=d,d=I,i=${id};\x1b\\'
}
