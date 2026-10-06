module vaxis

import encoding.base64
import strings
import zigimg

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
pub mut:
	id     u32 @[required]
	width  u16 @[required]
	height u16 @[required]
}

pub struct ImageCellDimensions {
pub mut:
	rows u16 @[required]
	cols u16 @[required]
}

pub struct ImageTransmission {
pub:
	image    Image = Image{
		id:     0
		width:  0
		height: 0
	}
	sequence string
}

pub struct ImageSourcePath {
pub:
	path string @[required]
}

pub struct ImageSourceMemory {
pub:
	bytes []u8 @[required]
}

// Image.Source's path/memory union in pinned vaxis.
pub type ImageSource = ImageSourcePath | ImageSourceMemory

// Vaxis.zig transmitImage. The existing V IoWriter adapter returns the exact
// transmission bytes so callers can write them through their terminal writer.
pub fn (mut vx Vaxis) transmit_image(mut image zigimg.Image, format ImageTransmitFormat) !ImageTransmission {
	if !vx.caps.kitty_graphics { return error('NoGraphicsCapability') }
	bytes := match format {
		.png {
			// Preserve the original fixed allocation of imageByteSize, including
			// WriteFailed for PNG output that does not fit that capacity.
			mut buffer := []u8{len: int(image.image_byte_size())}
			image.write_to_memory(mut buffer, zigimg.PngEncoderOptions{})!
		}
		.rgb {
			image.convert(.rgb24)!
			image.raw_bytes()
		}
		.rgba {
			image.convert(.rgba32)!
			image.raw_bytes()
		}
	}

	encoded := base64.encode(bytes)
	if image.width > 65535 || image.height > 65535 {
		panic('integer does not fit in destination type')
	}
	return vx.transmit_pre_encoded_image(encoded, u16(image.width), u16(image.height), format)
}

// Vaxis.zig loadImage: capability check precedes decoding; the path reader
// uses the source's 1 MiB buffer; decoded pixels are released after transmit.
pub fn (mut vx Vaxis) load_image(source ImageSource) !ImageTransmission {
	if !vx.caps.kitty_graphics { return error('NoGraphicsCapability') }
	mut read_buffer := []u8{len: 1024 * 1024}
	mut image := match source {
		ImageSourcePath { zigimg.Image.from_file_path(source.path, mut read_buffer)! }
		ImageSourceMemory { zigimg.Image.from_memory(source.bytes)! }
	}

	defer { image.deinit() }
	return vx.transmit_image(mut image, .png)
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
			pix_per_col := (usize(screen.width_pix) + usize(screen.width) - 1) / usize(screen.width)
			pix_per_row := (usize(screen.height_pix) + usize(screen.height) - 1) / usize(screen.height)
			win_width_pix := pix_per_col * usize(win.width)
			win_height_pix := pix_per_row * usize(win.height)
			fit_x := win_width_pix >= usize(img.width)
			fit_y := win_height_pix >= usize(img.height)
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
					if usize(img.width) - win_width_pix > usize(img.height) - win_height_pix {
						placed.size = ImageCellSize{
							cols: win.width
						}
					} else {
						placed.size = ImageCellSize{
							rows: win.height
						}
					}
				} else {
					if opts.scale != .fit { panic('Assertion failed') }
					if win_width_pix - usize(img.width) < win_height_pix - usize(img.height) {
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
	defer { vx.advance_image_id() }
	if ((usize(payload.len) + 2) / 3) * 4 >= 4096 {
		return error('PathTooLong')
	}
	encoded := base64.encode_str(payload)
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
	defer { vx.advance_image_id() }
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

fn (mut vx Vaxis) advance_image_id() {
	if vx.next_img_id == 0xffffffff { panic('integer overflow') }
	vx.next_img_id++
}
